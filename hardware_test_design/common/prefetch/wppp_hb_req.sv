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
logic [9:0] curr_arid; // 10 bit arid counter, max 1024 requests
logic [72:0] fifo_in_up, fifo_out_up;
logic enq_ok;
logic queue_full, queue_empty, dequeue_valid;
logic active_valid;
logic [63:0] active_num_cl, cl_counter;
logic [63:0] active_base_addr;
logic [63:0] addr_low_limit, addr_up_limit;
logic active_addr_in_range;
logic launch_valid;
logic ar_pending;
logic ar_fire;
logic [11:0] held_arid;
logic [63:0] held_araddr;
(*preserve_for_debug *) logic [4:0] usedw;

// the fifo has been updated to have a depth of 256, the name is not updated, double-check if needed
fifo_32w_73d hint_fifo( 
	.data(fifo_in_up/*fifo_in*/),
	.wrreq(enq_ok),
	.rdreq(dequeue_valid),
	.clock(axi4_mm_clk),
	.q(fifo_out_up/*fifo_out*/),
	.usedw(usedw),
	.full(queue_full),
	.empty(queue_empty)
);

// Transfer FIFO-head ownership into a stable active context. The FIFO entry is
// no longer the live source of an AXI request and can be popped immediately.
assign dequeue_valid = axi4_mm_rst_n & ~active_valid & ~queue_empty;

assign active_addr_in_range =
    (active_base_addr >= addr_low_limit) &&
    (active_base_addr < addr_up_limit);
assign launch_valid = active_valid & enable_prefetch_i & active_addr_in_range &
                      ~abort_op & ~lut_in_use;

// The fall-through path retains one-request-per-cycle throughput. If READY is
// low at a sampling edge, ar_pending captures the complete payload and keeps
// VALID asserted even if enable/abort/range/LUT controls subsequently change.
assign arvalid = ar_pending | launch_valid;
assign arid = ar_pending ? held_arid : {2'b0, curr_arid};
assign araddr = ar_pending ? held_araddr :
                active_base_addr + (cl_counter << 6);
assign aruser = 6'b110000; // used to be Host Bias, now it is Device Bias
assign ar_fire = arvalid & arready;
assign write_lut = ar_fire;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        addr_low_limit <= '0;
        addr_up_limit <= '0;
    end
    else begin
        addr_low_limit <= start_address_i;
        addr_up_limit <= start_address_i + address_upper_i;
    end
end

/* fifo signals */
always_comb begin
    enq_ok = enqueue_valid_i & enable_prefetch_i & ~queue_full;
    fifo_in_up = {9'b0, enqueue_num_of_cl_i[13:0], enqueue_address_i[49:0]};
end

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        curr_arid <= '0; /* arid id, up counter */
        active_valid <= 1'b0;
        active_num_cl <= '0;
        active_base_addr <= '0;
        cl_counter <= '0;
        ar_pending <= 1'b0;
        held_arid <= '0;
        held_araddr <= '0;
    end
    else begin
        if (dequeue_valid) begin
            active_valid <= 1'b1;
            active_num_cl <= {50'b0, fifo_out_up[63:50]};
            active_base_addr <= {14'b0, fifo_out_up[49:0]};
            cl_counter <= '0;
        end

        if (~ar_pending & launch_valid & ~arready) begin
            ar_pending <= 1'b1;
            held_arid <= {2'b0, curr_arid};
            held_araddr <= active_base_addr + (cl_counter << 6);
        end
        else if (ar_pending & arready) begin
            ar_pending <= 1'b0;
        end

        if (ar_fire) begin
            curr_arid <= curr_arid + 10'd1;
            if (cl_counter + 64'd1 == active_num_cl) begin
                active_valid <= 1'b0;
                cl_counter <= '0;
            end
            else begin
                cl_counter <= cl_counter + 64'd1;
            end
        end
    end
end
endmodule
