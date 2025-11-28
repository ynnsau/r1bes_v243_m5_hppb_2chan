module prefetch_hint_fifo
import wppprefetch_pkg::*;
#(
  	parameter interval = 3000,	// interval (in cycles) between prefetch requests
	parameter range_bit = 34	// range of address bits for lower and upper address
)
(
	input logic clk_i,
  	input logic reset_ni,                           // active high reset
	input logic [63:0] start_address_i, 	        // user defined starting address
	input logic [range_bit - 1:0] address_lower_i,		// 16GB range
	input logic [range_bit - 1:0] address_upper_i,		// 16GB range
	input logic [31:0] csr_prefetch_interval_i,         // prefetch interval from CSR

    input logic enqueue_valid_i,
    input logic [63:0] enqueue_address_i,       // enqueued physical address, 64 bits
    input logic [15:0] enqueue_num_of_cl_i,      // number of cache lines to enqueue, 9 bits


  	output logic is_prefetch_o,			// signal start of prefetching
  	output logic [63:0] prefetch_addr_o	// address to prefetch, byte level address

    // unused signals, kept for interface compatibility, will remove later
    // input logic get_next_addr,
    // input logic addr_issued,
  	// output logic [63:0] is_direct_ncp_o, // address to prefetch, byte level address
    // input logic [63:0] csr_prefetch_fifo_ahead_offset,
    // input logic [63:0] chan0_address_i, 
    // input logic chan0_address_valid,
    // input logic [63:0] chan1_address_i, 
    // input logic chan1_address_valid
);

localparam max_range = 64'h1 << 34;	// 2^34 = 16GB
localparam shift_bits = 6; // cache line size is 64 bytes = 2^6

logic [30:0] cycle_counter;			// a large enough counter to count the interval
logic prefetch_enable, queue_empty, queue_full, dequeue_valid, dequeue_valid_r;
logic is_prefetch_r;
logic [30:0] prefetch_interval;
logic next_entry_ready;
logic [63:0] cl_cnt, total_cl_cnt;
logic [63:0] new_prefetch_addr_r, end_addr_reg, queue_front_addr;
logic [63:0] candidate_addr;
(* preserve_for_debug *) logic addr_gt_lb, addr_lt_ub;
wppp_hint_fifo_entry_t fifo_in, fifo_out;
logic [73:0] fifo_in_up, fifo_out_up;

assign is_prefetch_o = prefetch_enable & is_prefetch_r; // only allow prefetch when enabled
assign dequeue_valid = next_entry_ready & ~queue_empty; // only dequeue when done with the current entry
assign addr_gt_lb = candidate_addr >= start_address_i;
assign addr_lt_ub = candidate_addr <= end_addr_reg;

// instantiate fifo here
fifo_32w_73d hint_fifo(
	.data(fifo_in_up/*fifo_in*/),
	.wrreq(enqueue_valid_i),
	.rdreq(dequeue_valid),
	.clock(clk_i),
	.q(fifo_out_up/*fifo_out*/),
	.usedw(),
	.full(queue_full),
	.empty(queue_empty)
);

always_comb begin
    // fifo_in.hint_addr = enqueue_address_i;
    // fifo_in.hint_num_of_cl = enqueue_num_of_cl_i;
    fifo_in_up = {enqueue_num_of_cl_i[13:0], enqueue_address_i[49:0]};
    // queue_front_addr = fifo_out.hint_addr;
    // total_cl_cnt = {55'b0, fifo_out.hint_num_of_cl};
    queue_front_addr = fifo_out_up[49:0];
    total_cl_cnt = {50'b0, fifo_out_up[63:50]};
    prefetch_addr_o = new_prefetch_addr_r;
    candidate_addr = queue_front_addr + (cl_cnt << shift_bits);
end

// use to configure prefetch enable and interval
always_comb begin
    prefetch_enable = 1'b0; // this will be set by MSB of csr_prefetch_interval_i
	prefetch_interval = interval;
	if (csr_prefetch_interval_i[30:0] != 31'h0) begin
		prefetch_interval = csr_prefetch_interval_i[30:0];
	end
    if (csr_prefetch_interval_i[31]) begin 
        prefetch_enable = 1'b1;
    end
end

// push address output logic
// always_ff @(posedge clk_i) begin
//     if (~reset_ni || start_address_i == '0) begin
//         cycle_counter <= '0;
//         is_prefetch_r <= '0;
//         prefetch_addr_o <= '0;
//     end
//     else if(prefetch_enable) begin
//         if(cycle_counter >= prefetch_interval) begin
//             cycle_counter <= '0;
//             prefetch_addr_o <= new_prefetch_addr_r;
//             is_prefetch_r <= (addr_gt_lb & addr_lt_ub);
//         end
//         else begin
//             cycle_counter <= cycle_counter + 1;
//             is_prefetch_r <= 1'b0;
//         end
//     end
// end

// push address generation logic
always_ff @(posedge clk_i) begin
    if(~reset_ni || start_address_i == '0) begin
        next_entry_ready <= 1'b1;
        cl_cnt <= '0;
        end_addr_reg <= '0;
        new_prefetch_addr_r <= '0;
        is_prefetch_r <= 1'b0;
    end
    else begin
        end_addr_reg <= start_address_i + address_upper_i;
        new_prefetch_addr_r <= '0; // default to 0, prevent repeated prefetching when queue is empty
        is_prefetch_r <= 1'b0; // default to 0
        if (dequeue_valid) begin
            // if next entry is ready, grap data from fifo, fifo takes one cycle to respond, so fifo_out is valid until next_entry_ready becomes 0
            next_entry_ready <= 1'b0;
        end
    
        if (!next_entry_ready) begin
            is_prefetch_r <= (addr_gt_lb & addr_lt_ub); // indicate prefetch is valid
            // loop through all cache lines in the current entry
            new_prefetch_addr_r <= candidate_addr; // each cache line is 64 bytes
            if (cl_cnt + 1 >= total_cl_cnt) begin
                next_entry_ready <= 1'b1; // done with this entry, ready for next
                cl_cnt <= '0;
            end 
            else begin
                cl_cnt <= cl_cnt + 1;
            end
        end
    end
end

endmodule