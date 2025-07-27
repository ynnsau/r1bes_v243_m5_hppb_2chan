module descend_fsm 

(
    input logic clk,
    input logic rst_n, 

    input logic func_call_valid,
    output logic func_call_ready,
    output logic func_call_complete,

    input logic  [63:0] node_i,
    input logic  [63:0] entry_i,
    input logic  [31:0] shift_i,
    input logic  [31:0] order_i,
    input logic  [63:0] index_i, //xas.xa_index

    output logic [63:0] xasret_node,
    output logic [31:0] xasret_offset,

    input logic prev_req_resp,
    output logic [63:0] rreq_addr,

    output logic read_offset_req,
    input logic [7:0] read_offset_node_shift,
    
    output logic read_entry_req,
    input logic [63:0] read_entry_val
);

localparam XA_CHUNK_SHIFT_ = 6;
// localparam XA_CHUNK_SIZE_ = (1 << XA_CHUNK_SHIFT_);
// localparam XA_CHUNK_MASK_ = (XA_CHUNK_SIZE_ - 1);
localparam XA_CHUNK_MASK = 6'h3F; // 63

logic [63:0] entry_reg;
logic [63:0] node_reg;      // ptr, (struct xa_node_ *)
logic [31:0] shift_reg;
logic [31:0] offset_reg;
logic [63:0] index_reg;
logic [31:0] order_reg;

logic return_next, return_reg;

typedef enum logic [2:0] {
    STATE_IDLE, 
    STATE_DECREMENT, //decremnt shift and if entry is 0 abort, else if entry check, set node_
                     //else, abort
    STATE_READ_OFFSET, 
    STATE_READ_ENTRY, 
    STATE_UPDATE_ENTRY, //check and then update entry, write output values
    STATE_LOOP         //loop and ret here
    } while_state_type;

while_state_type state_reg, state_next;

always_comb begin
    func_call_ready = 1'b0;
    func_call_complete = 1'b0;
    state_next = state_reg;
    read_offset_req = 1'b0;
    read_entry_req = 1'b0;
    rreq_addr = '0;
    return_next = '0;
    unique case (state_reg)
        STATE_IDLE         :
            begin
                func_call_ready = 1'b1;
                if (func_call_valid) begin
                    state_next = STATE_DECREMENT;
                end
            end
        STATE_DECREMENT    :
            begin
                if (entry_reg == '0) begin // how to check if entry is null
                    state_next = STATE_LOOP;
                    return_next = 1'b1;
                end else if (entry_reg[1:0] == 2'b10 && entry_reg[63:12] != 52'b0) begin
                    state_next = STATE_READ_OFFSET;
                end else begin
                    state_next = STATE_LOOP;
                    return_next = 1'b1;
                end
            end
        STATE_READ_OFFSET  :
            begin
                //send read signals
                read_offset_req = 1'b1;
                rreq_addr = node_reg;
                if (prev_req_resp) begin 
                    state_next = STATE_READ_ENTRY;
                end
            end
        STATE_READ_ENTRY   :
            begin
                //send read signals
                read_entry_req = 1'b1;
                rreq_addr = node_reg + 40 + offset_reg * 8;     // this will not be aligned
                if (prev_req_resp) begin
                    state_next = STATE_UPDATE_ENTRY;
                end
            end
        STATE_UPDATE_ENTRY : 
            begin // loop and ret logic here
                // return_next = 1'b1;  // TODO: BUG!!
                state_next = STATE_LOOP;
            end
        STATE_LOOP : 
            begin
                if (shift_reg > order_reg && ~return_reg) begin
                    state_next = STATE_DECREMENT;
                end else begin
                    state_next = STATE_IDLE;
                    func_call_complete = 1'b1;
                end
            end
        default            :
            begin
            end
    endcase
end

always_ff @(posedge clk) begin
    if (~rst_n) begin
        state_reg <= STATE_IDLE;
        entry_reg <= '0;
        node_reg <= '0;
        shift_reg <= '0;
        offset_reg <= '0;
        index_reg <= '0;
        order_reg <= '0;

        xasret_node <= '0;
        xasret_offset <= '0;
    end else begin
        state_reg <= state_next;
        return_reg <= return_next;
        if (func_call_ready && func_call_valid) begin
            index_reg <= index_i;
            entry_reg <= entry_i;
            node_reg <= node_i;
            shift_reg <= shift_i;
            order_reg <= order_i;
        end
        if (return_next) begin
            xasret_node <= node_reg;
            xasret_offset <= offset_reg;    
        end
        unique case (state_reg)
            STATE_DECREMENT: 
                begin
                    shift_reg <= shift_reg - XA_CHUNK_SHIFT_;
                    if (state_next == STATE_READ_OFFSET) begin 
                        node_reg <= entry_reg - 64'd2; 
                    end
                end
            STATE_READ_OFFSET:
                begin
                    if (prev_req_resp) begin
                        offset_reg <= (index_reg >> read_offset_node_shift) & XA_CHUNK_MASK;
                    end
                end
            STATE_READ_ENTRY:
                begin
                    if (prev_req_resp) begin
                       entry_reg <= read_entry_val;
                    end
                end
            STATE_UPDATE_ENTRY:
                begin
                    if (entry_reg[1:0] == 2'b10 && (entry_reg < 64'd254)) begin
                        entry_reg <= '1;
                    end
                end
            default: 
                begin
                end
        endcase
    end
end

endmodule
