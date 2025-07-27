module func_offload
import func_offload_params::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // CSR based
    input logic [5:0]               csr_aruser,
    input logic [5:0]               csr_awuser,

    input logic [63:0] offload_func_call_cnt,   
    input logic [63:0] offload_func_call_base,   
    output logic [63:0] offload_func_complete_cnt,      

    // ACTUAL AXI SIGNALS
    axi_ports.ar_req r_ch,
    axi_ports.aw_req w_ch

);


    logic                       rreq_valid;
    logic [63:0]                rreq_addr;
    logic [63:0]                local_rreq_addr;
    logic [511:0]               rreq_data;
    logic                       rreq_complete;
    logic                       wreq_valid;
    logic [63:0]                wreq_addr;
    logic [511:0]               wreq_data;
    logic                       wreq_complete;

    logic                       fsm_func_call_valid;
    logic                       fsm_func_call_ready;
    logic                       fsm_func_call_complete;

    logic                       prev_req_resp;
    logic                       read_offset_req;
    logic                       read_entry_req;


    logic  [63:0]               node_i;
    logic  [63:0]               entry_i;
    logic  [31:0]               shift_i;
    logic  [31:0]               order_i;
    logic  [63:0]               index_i;


    logic [63:0]                xasret_node;
    logic [31:0]                xasret_offset;


    logic [7:0]                 read_offset_node_shift;
    logic [63:0]                read_entry_val;

// ASSUMPTIONS
// struct xa_state_ xas is 64-byte aligned
// all xa_node structs are 64-byte aligned 


func_offload_mem func_offload_mem(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),

    .csr_aruser(csr_aruser),
    .csr_awuser(csr_awuser),

    .rreq_valid(rreq_valid),
    .rreq_addr(rreq_addr),
    .rreq_data(rreq_data), 
    .rreq_complete(rreq_complete),

    .wreq_valid(wreq_valid),
    .wreq_addr(wreq_addr),
    .wreq_data(wreq_data), 
    .wreq_complete(wreq_complete),
    
// ACTUAL AXI SIGNALS
    .r_ch(r_ch),
    .w_ch(w_ch)
);

descend_fsm descend_fsm(
    .clk(axi4_mm_clk),
    .rst_n(axi4_mm_rst_n), 

    .func_call_valid(fsm_func_call_valid),
    .func_call_ready(fsm_func_call_ready),

    .func_call_complete(fsm_func_call_complete),

    .node_i(node_i),
    .entry_i(entry_i),
    .shift_i(shift_i),
    .order_i(order_i),
    .index_i(index_i),

    .xasret_node(xasret_node),
    .xasret_offset(xasret_offset),

    .prev_req_resp(prev_req_resp),
    .rreq_addr(local_rreq_addr),

    .read_offset_req(read_offset_req),
    .read_offset_node_shift(read_offset_node_shift),
    
    .read_entry_req(read_entry_req),
    .read_entry_val(read_entry_val)

);


logic [63:0] old_offload_func_call_cnt;
func_offload_mem_req_type curr_req_type, next_req_type;
logic [511:0] xa_state_input_reg;
logic input_arg_req;
logic wreq_valid_reg;

always_ff @( posedge axi4_mm_clk ) begin
    if ( ~axi4_mm_rst_n ) begin
        old_offload_func_call_cnt <= 1'b0;
        curr_req_type <= func_in_args;
        xa_state_input_reg <= '0;
        offload_func_complete_cnt <= '0;
        input_arg_req <= 1'b0;
    end else begin
        curr_req_type <= next_req_type;

        if (curr_req_type == func_in_args && rreq_complete) begin
            old_offload_func_call_cnt <= offload_func_call_cnt;
            if (input_arg_req == 1'b0) xa_state_input_reg <= rreq_data;
            input_arg_req <= input_arg_req + 1'b1;
        end

        wreq_valid_reg <= wreq_valid;
        if (curr_req_type == func_out_val && wreq_complete) begin
            offload_func_complete_cnt <= offload_func_complete_cnt + 1'b1;
        end
    end
end


always_comb begin
    rreq_valid = 1'b0;
    rreq_addr = '0;

    wreq_valid = 1'b0;
    wreq_addr = '0;
    wreq_data = '0;
    next_req_type = func_in_args;
        
    if (fsm_func_call_ready && (old_offload_func_call_cnt != offload_func_call_cnt || input_arg_req == 1'b1)) begin
        rreq_valid = 1'b1;
        rreq_addr = offload_func_call_base + input_arg_req * 64;    // read all input arguments, (56 bytes (xa_state) + 8 (padding for HW)) + (8 (node) + 8 (entry) + 4 (shift) + 4 (order))
        next_req_type = func_in_args;
    end
    else if (read_offset_req) begin
        rreq_valid = 1'b1;
        rreq_addr = local_rreq_addr;
        next_req_type = func_read_offset;
    end
    else if (read_entry_req) begin
        rreq_valid = 1'b1;
        rreq_addr = {local_rreq_addr[63:6], 6'b0};
        next_req_type = func_read_entry;
    end

    if (fsm_func_call_complete || (wreq_valid_reg & ~wreq_complete) ) begin
        next_req_type = func_out_val;
        wreq_valid = 1'b1;
        wreq_addr = offload_func_call_base; // update the original xa_state input argument
        wreq_data = {xa_state_input_reg[511:256], xasret_node, xa_state_input_reg[191:152], xasret_offset[7:0], xa_state_input_reg[143:0]};
    end

end


always_comb begin
    prev_req_resp = '0;
    fsm_func_call_valid = 1'b0;
    node_i = '0;
    entry_i = '0;
    shift_i = '0;
    order_i = '0;
    index_i = '0;
    read_offset_node_shift = '0;
    read_entry_val = '0;

    if (rreq_complete) begin
        case (curr_req_type)
            func_in_args: begin
                if (input_arg_req == 1'b1) begin
                    prev_req_resp = '1;
                    fsm_func_call_valid = 1'b1;
                    node_i = rreq_data[63:0];
                    entry_i = rreq_data[127:64];
                    shift_i = rreq_data[159:128];
                    order_i = rreq_data[191:160];
                    index_i = xa_state_input_reg[127:64];
                end
            end
            func_read_offset: begin
                prev_req_resp = '1;
                read_offset_node_shift = rreq_data[7:0];
            end
            func_read_entry: begin
                prev_req_resp = '1;
                // mask local_rreq_addr for 64-bytes, then index based on masking bits
                read_entry_val = rreq_data[local_rreq_addr[5:0] * 8 +: 64];
            end

        endcase
    end
    
end

endmodule