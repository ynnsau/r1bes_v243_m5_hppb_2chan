module wppprefetch_rw_pipeline_v2
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // read address channel
    axi_ports.ar_req                  wppp_axi_r_ch,
    axi_ports.aw_req                  wppp_axi_w_ch,

    // control logic 
    // set physical address of target cache line to prefetch_page_addr
    // input logic [63:0] prefetch_page_addr, // byte level address, XXX, this may change during the states 
    // input logic start_prefetch,
    input logic [5:0] csr_aruser,
    input logic [6:0] csr_awuser,
	input logic [63:0] start_address_i, 	        // user defined starting address
    input logic enable_prefetch_i,
	input logic [33:0] address_lower_i,		// 16GB range
	input logic [33:0] address_upper_i,		// 16GB range
    input logic enqueue_valid_i,
    input logic [63:0] enqueue_address_i,       // enqueued physical address, 64 bits
    input logic [15:0] enqueue_num_of_cl_i,      // number of cache lines to enqueue, 9 bits

    input logic clst_d1_tvalid,
    input logic [71:0] clst_d1_tdata,

    // for new ncp method
    input logic csr_flush_lut,
    output wppprefetch_rw_state_t prefetch_rw_curr_state, // for AFU specifically 
    output logic [63:0] curr_working_address,   // address that prefetching is working on
    
    input logic addr_seen,  // signal provided by AFU, 1 = prefetch can issue ncp, 0 = prefetch cannot issue ncp
    input logic abort_op,   // signal from AFU to abort current prefetch operation

    // statistics output
    output logic [63:0] prefetch_abt_cnt, // for prefetching stat, abort count
    output logic [63:0] prefetch_ok_cnt,  // for prefetching stat, success count

    // get next addr
    output logic addr_issued,
    output logic get_next_addr,

    //filter read req channel
    output logic [63:0]                faraddr,
    output logic                       farvalid,
    //filter read resp channel
    input  logic                        frvalid,
    input  logic                        frdata
);

/* local param */
localparam NCP_PIPE_ON = 1; // update this to use pipeline
localparam MAX_REQUEST_COUNT = 32'd256; // max prefetch request count
// localparam SIM_ON = 0;

/* other */
logic [9:0] curr_rid;
logic [63:0] push_page_addr_r, filter_addr_r;
logic [31:0] success_count;
logic write_lut, read_lut;
logic lut_valid, lut_in_use;
logic [31:0] request_count;
wppprefetch_rw_state_t filter_state, next_filter_state;
wppprefetch_rw_pipe_t hb_resp_out; // , filter_out; // stage out
wppprefetch_rw_pipe_t hb2ncp_pipe; // stage register
// wppprefetch_rw_pipe_t hb2filter_pipe, filter2ncp_pipe; // stage register


assign prefetch_ok_cnt = {32'b00000000, success_count}; // statistics output
assign prefetch_abt_cnt = 64'b0; // not implemented yet



// pipeline registers
always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        // hb2filter_pipe <= '0;
        // filter2ncp_pipe <= '0;
        hb2ncp_pipe <= '0;
    end
    else begin
        // hb2filter_pipe <= hb_resp_out; // hb -> filter
        // filter2ncp_pipe <= filter_out; // filter -> ncp
        hb2ncp_pipe <= hb_resp_out; // hb -> ncp
    end
end

wppp_lut lut_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .flush_lut(csr_flush_lut),
    .write_lut(write_lut),
    .read_lut(read_lut),
    .curr_arid(wppp_axi_r_ch.arid[9:0]),
    .curr_araddr(wppp_axi_r_ch.araddr),
    .curr_rid(curr_rid),
    .lut_valid(lut_valid),
    .lut_in_use(lut_in_use),
    .push_page_addr_r(push_page_addr_r)
);

wppp_hb_req hb_req_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .arid(wppp_axi_r_ch.arid),
    .araddr(wppp_axi_r_ch.araddr),
    .arlen(wppp_axi_r_ch.arlen),
    .arsize(wppp_axi_r_ch.arsize),
    .arburst(wppp_axi_r_ch.arburst),
    .arprot(wppp_axi_r_ch.arprot),
    .arqos(wppp_axi_r_ch.arqos),
    .aruser(wppp_axi_r_ch.aruser),
    .arvalid(wppp_axi_r_ch.arvalid),
    .arcache(wppp_axi_r_ch.arcache),
    .arlock(wppp_axi_r_ch.arlock),
    .arregion(wppp_axi_r_ch.arregion),
    .arready(wppp_axi_r_ch.arready),

	.start_address_i(start_address_i), 	    // user defined starting address
    .enable_prefetch_i(enable_prefetch_i),
	.address_lower_i(address_lower_i),		// 16GB range
	.address_upper_i(address_upper_i),		// 16GB range
    .enqueue_valid_i(enqueue_valid_i),
    .enqueue_address_i(enqueue_address_i),       // enqueued physical address, 64 bits
    .enqueue_num_of_cl_i(enqueue_num_of_cl_i),      // number of cache lines to enqueue, 9 bits

    .lut_in_use(lut_in_use),
    .abort_op(abort_op),
    .write_lut(write_lut)

    // .start_prefetch(start_prefetch),
    // .prefetch_page_addr(prefetch_page_addr),
    // .addr_issued(addr_issued),
    // .get_next_addr(get_next_addr),
);

wppp_hb_resp hb_resp_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .rid(wppp_axi_r_ch.rid),
    .rdata(wppp_axi_r_ch.rdata),
    .rresp(wppp_axi_r_ch.rresp),
    .rlast(wppp_axi_r_ch.rlast),
    .ruser(wppp_axi_r_ch.ruser),
    .rvalid(wppp_axi_r_ch.rvalid),
    .rready(wppp_axi_r_ch.rready),
    .read_lut(read_lut),
    .curr_rid(curr_rid),
    .lut_valid(lut_valid),
    .push_page_addr_r(push_page_addr_r),
    .hb_resp_out(hb_resp_out)
);

generate
    if (NCP_PIPE_ON) begin
        wppp_ncp_pipe ncp_inst(
         .axi4_mm_clk(axi4_mm_clk),
            .axi4_mm_rst_n(axi4_mm_rst_n),
            .awid(wppp_axi_w_ch.awid),
            .awaddr(wppp_axi_w_ch.awaddr),
            .awlen(wppp_axi_w_ch.awlen),
            .awsize(wppp_axi_w_ch.awsize),
            .awburst(wppp_axi_w_ch.awburst),
            .awprot(wppp_axi_w_ch.awprot),
            .awqos(wppp_axi_w_ch.awqos),
            .awuser(wppp_axi_w_ch.awuser),
            .awvalid(wppp_axi_w_ch.awvalid),
            .awcache(wppp_axi_w_ch.awcache),
            .awlock(wppp_axi_w_ch.awlock),
            .awregion(wppp_axi_w_ch.awregion),
            .awatop(wppp_axi_w_ch.awatop),
            .awready(wppp_axi_w_ch.awready),
            .wdata(wppp_axi_w_ch.wdata),
            .wstrb(wppp_axi_w_ch.wstrb),
            .wlast(wppp_axi_w_ch.wlast),
            .wuser(wppp_axi_w_ch.wuser),
            .wvalid(wppp_axi_w_ch.wvalid),
            .wready(wppp_axi_w_ch.wready),
            .bid(wppp_axi_w_ch.bid),
            .bresp(wppp_axi_w_ch.bresp),
            .buser(wppp_axi_w_ch.buser),
            .bvalid(wppp_axi_w_ch.bvalid),
            .bready(wppp_axi_w_ch.bready),
            .filter2ncp_pipe(hb2ncp_pipe),
            .success_count(success_count)
        );
    end
    else begin
        wppp_ncp ncp_inst(
            .axi4_mm_clk(axi4_mm_clk),
            .axi4_mm_rst_n(axi4_mm_rst_n),
            .awid(wppp_axi_w_ch.awid),
            .awaddr(wppp_axi_w_ch.awaddr),
            .awlen(wppp_axi_w_ch.awlen),
            .awsize(wppp_axi_w_ch.awsize),
            .awburst(wppp_axi_w_ch.awburst),
            .awprot(wppp_axi_w_ch.awprot),
            .awqos(wppp_axi_w_ch.awqos),
            .awuser(wppp_axi_w_ch.awuser),
            .awvalid(wppp_axi_w_ch.awvalid),
            .awcache(wppp_axi_w_ch.awcache),
            .awlock(wppp_axi_w_ch.awlock),
            .awregion(wppp_axi_w_ch.awregion),
            .awatop(wppp_axi_w_ch.awatop),
            .awready(wppp_axi_w_ch.awready),
            .wdata(wppp_axi_w_ch.wdata),
            .wstrb(wppp_axi_w_ch.wstrb),
            .wlast(wppp_axi_w_ch.wlast),
            .wuser(wppp_axi_w_ch.wuser),
            .wvalid(wppp_axi_w_ch.wvalid),
            .wready(wppp_axi_w_ch.wready),
            .bid(wppp_axi_w_ch.bid),
            .bresp(wppp_axi_w_ch.bresp),
            .buser(wppp_axi_w_ch.buser),
            .bvalid(wppp_axi_w_ch.bvalid),
            .bready(wppp_axi_w_ch.bready),
            .filter2ncp_pipe(hb2ncp_pipe),
            .success_count(success_count)
        );
    end
endgenerate
endmodule

/*
w4096_d64 u0 (
    .data_a    (_connected_to_data_a_),    //   input,  width = 64,    data_a.datain_a
    .q_a       (_connected_to_q_a_),       //  output,  width = 64,       q_a.dataout_a
    .data_b    (_connected_to_data_b_),    //   input,  width = 64,    data_b.datain_b
    .q_b       (_connected_to_q_b_),       //  output,  width = 64,       q_b.dataout_b
    .address_a (_connected_to_address_a_), //   input,  width = 12, address_a.address_a
    .address_b (_connected_to_address_b_), //   input,  width = 12, address_b.address_b
    .wren_a    (_connected_to_wren_a_),    //   input,   width = 1,    wren_a.wren_a
    .wren_b    (_connected_to_wren_b_),    //   input,   width = 1,    wren_b.wren_b
    .clock     (_connected_to_clock_)      //   input,   width = 1,     clock.clk
);
*/

/* ncp write addr */
// always_comb begin // simply issue
//     ncp_write_out = '0;
//     if (filter2ncp_pipe.push_valid) begin
//         ncp_write_out.push_valid = 1'b1;
//         ncp_write_out.push_data = filter2ncp_pipe.push_data;
//     end
//     wppp_axi_w_ch.awid = filter2ncp_pipe.push_id;
//     wppp_axi_w_ch.awuser = 7'b0100010; // NCP to host
//     wppp_axi_w_ch.awvalid = filter2ncp_pipe.push_valid;
//     wppp_axi_w_ch.awaddr = filter2ncp_pipe.push_addr;
// end

// /* ncp wirte data */
// always_comb begin
//     wppp_axi_w_ch.wlast = 1'b1;
//     wppp_axi_w_ch.wstrb = 64'hFFFFFFFFFFFFFFFF; // all bytes valid
//     wppp_axi_w_ch.wvalid = ncp_addr2write_pipe.push_valid;
//     wppp_axi_w_ch.wdata = ncp_addr2write_pipe.push_data;
// end

// logic lut_valid;
// logic id2addr_valids [4095:0];
// assign lut_valid = id2addr_valids[curr_rid];
// /* id to address valid LUT */
// always_ff @(posedge axi4_mm_clk) begin
//     if (!axi4_mm_rst_n) begin
//         id2addr_valids <= '0;
//     end
//     else begin
//         if (write_lut) begin // writing to LUT
//             id2addr_valids[wppp_axi_r_ch.arid] <= 1'b1;
//         end
//         if (read_lut) begin // reading from LUT
//             id2addr_valids[curr_rid] <= 1'b0;
//         end
//     end
// end

// w4096_d64 id2addr_lut (
//     .data_a    (wppp_axi_r_ch.araddr),    //   input,  width = 64,    data_a.datain_a
//     .q_a       (),       //  output,  width = 64,       q_a.dataout_a
//     .data_b    (),    //   input,  width = 64,    data_b.datain_b
//     .q_b       (push_page_addr_r),       //  output,  width = 64,       q_b.dataout_b
//     .address_a (wppp_axi_r_ch.arid), //   input,  width = 12, address_a.address_a
//     .address_b (curr_rid), //   input,  width = 12, address_b.address_b
//     .wren_a    (write_lut),    //   input,   width = 1,    wren_a.wren_a
//     .wren_b    ('0),    //   input,   width = 1,    wren_b.wren_b
//     .clock     (axi4_mm_clk)      //   input,   width = 1,     clock.clk
// );
