module wppp_hb_req
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,
    
    // req only need ar information, read address channel
    output logic [11:0]               arid,
    output logic [63:0]               araddr,   // output nc read address
    output logic [9:0]                arlen,    // must tie to 10'd0
    output logic [2:0]                arsize,   // must tie to 3'b110
    output logic [1:0]                arburst,  // must tie to 2'b00
    output logic [2:0]                arprot,   // must tie to 3'b000
    output logic [3:0]                arqos,    // must tie to 4'b0000
    output logic [5:0]                aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cachebale owned
    output logic                      arvalid,
    output logic [3:0]                arcache,  // must tie to 4'b0000
    output logic [1:0]                arlock,   // must tie to 2'b00
    output logic [3:0]                arregion, // must tie to 4'b0000
    input                             arready,

    // other signals
	input logic [63:0] start_address_i, 	        // user defined starting address
    input logic enable_prefetch_i,
	input logic [33:0] address_lower_i,		// 16GB range
	input logic [33:0] address_upper_i,		// 16GB range
    input logic enqueue_valid_i,
    input logic [63:0] enqueue_address_i,       // enqueued physical address, 64 bits
    input logic [15:0] enqueue_num_of_cl_i,      // number of cache lines to enqueue, 9 bits


    // input logic start_prefetch,
    // input [63:0] prefetch_page_addr,
    // output logic addr_issued,
    // output logic get_next_addr,
    input logic lut_in_use,
    input logic abort_op,
    output logic write_lut // writing the LUT entry
);
/* const */
assign  arlen        = '0   ;
assign  arsize       = 3'b110   ; // must tie to 3'b110
assign  arburst      = '0   ;
assign  arprot       = '0   ;
assign  arqos        = '0   ;
assign  arcache      = '0   ;
assign  arlock       = '0   ;
assign  arregion     = '0   ;

/* internal */
logic [9:0] curr_arid, next_arid; // 10 bit arid counter, max 1024 requests
logic [72:0] fifo_in_up, fifo_out_up; 
logic enq_ok;
logic queue_full, queue_empty, dequeue_valid;
logic [63:0] num_cl, cl_counter;
logic [63:0] push_cl_addr;
logic [63:0] addr_low_limit, addr_up_limit;
logic start_prefetch;
logic addr_in_range;

fifo_32w_73d hint_fifo(
	.data(fifo_in_up/*fifo_in*/),
	.wrreq(enq_ok),
	.rdreq(dequeue_valid),
	.clock(axi4_mm_clk),
	.q(fifo_out_up/*fifo_out*/),
	.usedw(),
	.full(queue_full),
	.empty(queue_empty)
);

assign write_lut = arvalid & arready; // write LUT when read address is accepted
assign dequeue_valid = (cl_counter + 1'd1 == num_cl) & ~queue_empty; // dequeue when all cachelines are issued
assign addr_in_range = (push_cl_addr >= addr_low_limit) && (push_cl_addr < addr_up_limit);

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        addr_low_limit <= '0;
        addr_up_limit <= '0;
        start_prefetch <= 1'b0;
    end
    else begin
        start_prefetch <= enable_prefetch_i & addr_in_range;
        addr_low_limit <= start_address_i;
        addr_up_limit <= start_address_i + address_upper_i;
    end
end

/* fifo signls */
always_comb begin
    enq_ok = enqueue_valid_i & enable_prefetch_i & ~queue_full;
    fifo_in_up = {9'b0, enqueue_num_of_cl_i[13:0], enqueue_address_i[49:0]};
    push_cl_addr = {14'b0, fifo_out_up[49:0]}; 
    num_cl = {50'b0, fifo_out_up[63:50]};
end

/* ar signals */
always_comb begin
    arvalid     = ~queue_empty & start_prefetch & ~abort_op & ~lut_in_use;
    arid        = {2'b0, curr_arid}; // zero extend to 12 bit
    araddr      = push_cl_addr + (cl_counter << 6); // each cache line is 64 bytes
    aruser      = 6'b100000;
end

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        curr_arid <= '0; /* arid id, up counter */
        cl_counter <= '0;
    end
    else begin
        if (arvalid & arready) begin
            curr_arid <= curr_arid + 10'd1;
            cl_counter <= cl_counter + 64'd1;
            if (cl_counter + 1'd1 == num_cl) begin // 
                cl_counter <= '0;
            end
        end
    end
end

/* state update */
// always_comb begin
//     next_ar_state = ar_state;
//     next_wait_cnt = wait_cnt;
//     next_arid = curr_arid;
//     addr_issued = 1'b0;
//     arid_cnt_overflow = 1'b0; // indicate arid overflow
    // unique case(ar_state)
    //     IDLE: begin
    //         if (start_prefetch & ~abort_op & ~lut_in_use) begin // start prefetching if not abort and LUT entry not in use
    //             addr_issued = 1'b1;
    //             next_ar_state = HB_READ_ADDR;
    //         end
    //     end
    //     HB_READ_ADDR: begin
    //         if (arready & arvalid) begin
    //             next_ar_state = LUT_WAIT;
    //         end
    //     end
    //     LUT_WAIT: begin
    //         // update to this because the BRAM is pipelined, we need to wait one cycle
    //         if (curr_arid == 10'h3FF) begin // arid overflow
    //             arid_cnt_overflow = 1'b1;
    //         end
    //         next_arid = curr_arid + 10'd1;
    //         next_ar_state = IDLE;

            // wait logic removed for simplification
            // if (wait_cnt == 2'd2) begin
            //     next_ar_state = IDLE;
            //     next_wait_cnt = 2'd0;

            //     if (curr_arid == 12'hFFF) begin // arid overflow
            //         arid_cnt_overflow = 1'b1;
            //     end
            //     next_arid = curr_arid + 12'd1;
            // end
            // else begin
            //     next_wait_cnt = wait_cnt + 2'd1;
            // end
//         end
//         default:;
//     endcase
// end
// /* state output */
// always_comb begin
//     arvalid     = 1'b0;
//     arid        = {2'b0, curr_arid}; // zero extend to 12 bit
//     araddr      = '0;
//     aruser      = '0;
//     write_lut   = 1'b0;
//     unique case(ar_state)
//         HB_READ_ADDR: begin
//             arvalid  = '1;
//             // arid     = curr_arid;
//             araddr   = prefetch_page_addr_r;
//             aruser   = 6'b100000;
//         end
//         LUT_WAIT: begin
//             // arid = curr_arid;
//             araddr = prefetch_page_addr_r;
//             write_lut = 1'b1;
//         end
//         default:;
//     endcase
// end
endmodule
