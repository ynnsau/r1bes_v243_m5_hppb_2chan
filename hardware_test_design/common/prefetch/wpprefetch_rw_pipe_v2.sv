module wppprefetch_rw_pipeline_v2
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // read address channel
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
    input logic                       arready,

    // read response channel
    input logic [11:0]                rid,
    input logic [511:0]               rdata,  
    input logic [1:0]                 rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic                       rlast,  // no use
    input logic                       ruser,  // no use
    input logic                       rvalid,
    output logic                      rready,

    // write address channel
    output logic [11:0]               awid,
    output logic [63:0]               awaddr,   // output ncp write address?
    output logic [9:0]                awlen,    // must tie to 10'd0
    output logic [2:0]                awsize,   // must tie to 3'b110 (64B/T)
    output logic [1:0]                awburst,  // must tie to 2'b00
    output logic [2:0]                awprot,   // must tie to 3'b000
    output logic [3:0]                awqos,    // must tie to 4'b0000
    output logic [6:0]                awuser,
    output logic                      awvalid,
    output logic [3:0]                awcache,  // must tie to 4'b0000
    output logic [1:0]                awlock,   // must tie to 2'b00
    output logic [3:0]                awregion, // must tie to 4'b0000
    output logic [5:0]                awatop,   // must tie to 6'b000000
    input  logic                      awready,

    // write data channel
    output logic [511:0]              wdata,
    output logic [(512/8)-1:0]        wstrb,
    output logic                      wlast,
    output logic                      wuser,  // must tie to 1'b0
    output logic                      wvalid,
    input  logic                      wready,

    // write response channel
    input [11:0]                      bid,    // no use
    input [1:0]                       bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                       buser,  // must tie to 4'b0000
    input logic                       bvalid,
    output logic                      bready,

    // control logic 
    // set physical address of target cache line to prefetch_page_addr
    input logic [63:0] prefetch_page_addr, // byte level address, XXX, this may change during the states 
    input logic start_prefetch,
    // output logic end_prefetch,
    // output logic [511:0] prefetch_page_data,

    input logic [5:0] csr_aruser,
    input logic [6:0] csr_awuser,

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
localparam NCP_PIPE_ON = 0; // update this to use pipeline
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
wppprefetch_rw_pipe_t hb_resp_out, filter_out; // stage out
wppprefetch_rw_pipe_t hb2filter_pipe, filter2ncp_pipe; // stage register

assign prefetch_ok_cnt = {32'b00000000, success_count}; // statistics output
assign prefetch_abt_cnt = 64'b0; // not implemented yet
assign req_block = (request_count >= MAX_REQUEST_COUNT - 1);


// pipeline registers
always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        hb2filter_pipe <= '0;
        filter2ncp_pipe <= '0;
        request_count <= '0; // strange implementation
    end
    else begin
        hb2filter_pipe <= hb_resp_out; // hb -> filter
        filter2ncp_pipe <= filter_out; // filter -> ncp

        if (write_lut && ~read_lut) begin
            request_count <= request_count + 1;
        end
        else if (~write_lut && read_lut) begin
            request_count <= request_count - 1;
        end
    end
end

wppp_lut lut_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .flush_lut(csr_flush_lut),
    .write_lut(write_lut),
    .read_lut(read_lut),
    .curr_arid(arid[9:0]),
    .curr_araddr(araddr),
    .curr_rid(curr_rid),
    .lut_valid(lut_valid),
    .lut_in_use(lut_in_use),
    .push_page_addr_r(push_page_addr_r)
);

wppp_hb_req hb_req_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arprot(arprot),
    .arqos(arqos),
    .aruser(aruser),
    .arvalid(arvalid),
    .arcache(arcache),
    .arlock(arlock),
    .arregion(arregion),
    .arready(arready),
    .start_prefetch(start_prefetch),
    .prefetch_page_addr(prefetch_page_addr),
    .lut_in_use(lut_in_use),
    .abort_op(abort_op | req_block), // if request count exceed, also abort
    .addr_issued(addr_issued),
    .get_next_addr(get_next_addr),
    .write_lut(write_lut)
);

wppp_hb_resp hb_resp_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rlast(rlast),
    .ruser(ruser),
    .rvalid(rvalid),
    .rready(rready),
    .read_lut(read_lut),
    .curr_rid(curr_rid),
    .lut_valid(lut_valid),
    .push_page_addr_r(push_page_addr_r),
    .hb_resp_out(hb_resp_out)
);

wppp_filter_check filter_check_inst(
    .axi4_mm_clk(axi4_mm_clk),
    .axi4_mm_rst_n(axi4_mm_rst_n),
    .faraddr(faraddr),
    .farvalid(farvalid),
    .frvalid(frvalid),
    .frdata(frdata),
    .hb2filter_pipe(hb2filter_pipe),
    .filter_out(filter_out)
);

generate
    if (NCP_PIPE_ON) begin
        wppp_ncp_pipe ncp_pipe_inst(
            .axi4_mm_clk(axi4_mm_clk),
            .axi4_mm_rst_n(axi4_mm_rst_n),
            .awid(awid),
            .awaddr(awaddr),
            .awlen(awlen),
            .awsize(awsize),
            .awburst(awburst),
            .awprot(awprot),
            .awqos(awqos),
            .awuser(awuser),
            .awvalid(awvalid),
            .awcache(awcache),
            .awlock(awlock),
            .awregion(awregion),
            .awatop(awatop),
            .awready(awready),
            .wdata(wdata),
            .wstrb(wstrb),
            .wlast(wlast),
            .wuser(wuser),
            .wvalid(wvalid),
            .wready(wready),
            .bid(bid),
            .bresp(bresp),
            .buser(buser),
            .bvalid(bvalid),
            .bready(bready),
            .filter2ncp_pipe(filter2ncp_pipe)
        );
    end
    else begin
        wppp_ncp ncp_inst(
            .axi4_mm_clk(axi4_mm_clk),
            .axi4_mm_rst_n(axi4_mm_rst_n),
            .awid(awid),
            .awaddr(awaddr),
            .awlen(awlen),
            .awsize(awsize),
            .awburst(awburst),
            .awprot(awprot),
            .awqos(awqos),
            .awuser(awuser),
            .awvalid(awvalid),
            .awcache(awcache),
            .awlock(awlock),
            .awregion(awregion),
            .awatop(awatop),
            .awready(awready),
            .wdata(wdata),
            .wstrb(wstrb),
            .wlast(wlast),
            .wuser(wuser),
            .wvalid(wvalid),
            .wready(wready),
            .bid(bid),
            .bresp(bresp),
            .buser(buser),
            .bvalid(bvalid),
            .bready(bready),
            .filter2ncp_pipe(filter2ncp_pipe),
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
//     awid = filter2ncp_pipe.push_id;
//     awuser = 7'b0100010; // NCP to host
//     awvalid = filter2ncp_pipe.push_valid;
//     awaddr = filter2ncp_pipe.push_addr;
// end

// /* ncp wirte data */
// always_comb begin
//     wlast = 1'b1;
//     wstrb = 64'hFFFFFFFFFFFFFFFF; // all bytes valid
//     wvalid = ncp_addr2write_pipe.push_valid;
//     wdata = ncp_addr2write_pipe.push_data;
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
//             id2addr_valids[arid] <= 1'b1;
//         end
//         if (read_lut) begin // reading from LUT
//             id2addr_valids[curr_rid] <= 1'b0;
//         end
//     end
// end

// w4096_d64 id2addr_lut (
//     .data_a    (araddr),    //   input,  width = 64,    data_a.datain_a
//     .q_a       (),       //  output,  width = 64,       q_a.dataout_a
//     .data_b    (),    //   input,  width = 64,    data_b.datain_b
//     .q_b       (push_page_addr_r),       //  output,  width = 64,       q_b.dataout_b
//     .address_a (arid), //   input,  width = 12, address_a.address_a
//     .address_b (curr_rid), //   input,  width = 12, address_b.address_b
//     .wren_a    (write_lut),    //   input,   width = 1,    wren_a.wren_a
//     .wren_b    ('0),    //   input,   width = 1,    wren_b.wren_b
//     .clock     (axi4_mm_clk)      //   input,   width = 1,     clock.clk
// );
