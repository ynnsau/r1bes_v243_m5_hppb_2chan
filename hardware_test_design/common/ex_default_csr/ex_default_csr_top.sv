// (C) 2001-2023 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// Copyright 2023 Intel Corporation.
//
// THIS SOFTWARE MAY CONTAIN PREPRODUCTION CODE AND IS PROVIDED BY THE
// COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
// OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

module ex_default_csr_top
// import mig_params::*;
(
    input  logic        csr_avmm_clk,
    input  logic        csr_avmm_rstn,  
    output logic        csr_avmm_waitrequest,  
    output logic [63:0] csr_avmm_readdata,
    output logic        csr_avmm_readdatavalid,
    input  logic [63:0] csr_avmm_writedata,
    input  logic        csr_avmm_poison,
    input  logic [21:0] csr_avmm_address,
    input  logic        csr_avmm_write,
    input  logic        csr_avmm_read, 
    input  logic [7:0]  csr_avmm_byteenable,

   // for monitor
   input logic afu_clk,
   input logic cxlip2iafu_read_eclk_chan0,
   input logic cxlip2iafu_write_eclk_chan0,
   input logic cxlip2iafu_read_eclk_chan1,
   input logic cxlip2iafu_write_eclk_chan1,

   // for tracker
   output logic [31:0] page_query_rate,
   output logic [63:0] cxl_start_pa, // byte level address, start_pfn << 12
   output logic [63:0] cxl_addr_offset,
   input logic page_mig_addr_en,
   input logic [27:0]  page_mig_addr,


    // for hot page pushing pushing
    output logic [63:0] csr_hapb_head,
    output logic [63:0] csr_dst_addr_buf_pAddr,
    output logic [63:0] csr_dst_addr_valid_cnt,

    // HPPB DEBUGGING
    input  logic [63:0] csr_hppb_test_mig_done_cnt,

   output logic [5:0] csr_aruser,
   output logic [5:0] csr_awuser,
   output logic [32:0]  csr_addr_ub,
   output logic [32:0]  csr_addr_lb,


    // HPPB Performance
    input logic [63:0] csr_hppb_min_mig_time,
    input logic [63:0] csr_hppb_max_mig_time,
    input logic [63:0] csr_hppb_total_curr_mig_time,
    input logic [63:0] csr_hppb_min_pg0_mig_time,
    input logic [63:0] csr_hppb_max_pg0_mig_time,
    input logic [63:0] csr_hppb_min_pgn_mig_time,
    input logic [63:0] csr_hppb_max_pgn_mig_time,
    input logic [63:0] csr_hppb_max_fifo_full_cnt,
    input logic [63:0] csr_hppb_max_fifo_empty_cnt,
    input logic [63:0] csr_hppb_max_total_read_cnt,
    input logic [63:0] csr_hppb_max_total_write_cnt,
    input logic [63:0] csr_hppb_rresp_err_cnt,
    input logic [63:0] csr_hppb_bresp_err_cnt,
    input logic [63:0] csr_hppb_max_outstanding_rreq_cnt,
    input logic [63:0] csr_hppb_max_outstanding_wreq_cnt

//    output logic [63:0] csr_host_ack_cnt [MIG_GRP_SIZE],
//    output logic [63:0] csr_ahppb_dst_addr_head,
//    input logic [63:0]  csr_need_new_base_cnt,

//    output logic [63:0]  csr_ahppb_src_addr_vld_cnt,
//    output logic [63:0]  csr_ahppb_src_addr[MIG_GRP_SIZE]

);

//CSR block

   ex_default_csr_avmm_slave ex_default_csr_avmm_slave_inst(
       .clk          (csr_avmm_clk),
       .reset_n      (csr_avmm_rstn),
       .writedata    (csr_avmm_writedata),
       .read         (csr_avmm_read),
       .write        (csr_avmm_write),
       .poison       (csr_avmm_poison),
       .byteenable   (csr_avmm_byteenable),
       .readdata     (csr_avmm_readdata),
       .readdatavalid(csr_avmm_readdatavalid),
       .address      ({10'h0,csr_avmm_address}),
       .waitrequest  (csr_avmm_waitrequest),
       .cxl_start_pa (cxl_start_pa),
       .cxl_addr_offset (cxl_addr_offset),

       .afu_clk               (afu_clk),
       .cxlip2iafu_read_eclk_chan0 (cxlip2iafu_read_eclk_chan0),
       .cxlip2iafu_write_eclk_chan0 (cxlip2iafu_write_eclk_chan0),
       .cxlip2iafu_read_eclk_chan1 (cxlip2iafu_read_eclk_chan1),
       .cxlip2iafu_write_eclk_chan1 (cxlip2iafu_write_eclk_chan1),

       .page_query_rate (page_query_rate),
       .page_mig_addr_en  (page_mig_addr_en),
       .page_mig_addr   (page_mig_addr),

    // for hot page pushing pushing
        .csr_hapb_head(csr_hapb_head),
        .csr_dst_addr_buf_pAddr(csr_dst_addr_buf_pAddr),
        .csr_dst_addr_valid_cnt(csr_dst_addr_valid_cnt),

        // HPPB DEBUGGING
        .csr_hppb_test_mig_done_cnt(csr_hppb_test_mig_done_cnt),

        // HPPB Performance
        .csr_hppb_min_mig_time(csr_hppb_min_mig_time),
        .csr_hppb_max_mig_time(csr_hppb_max_mig_time),
        .csr_hppb_total_curr_mig_time(csr_hppb_total_curr_mig_time),
        .csr_hppb_min_pg0_mig_time(csr_hppb_min_pg0_mig_time),
        .csr_hppb_max_pg0_mig_time(csr_hppb_max_pg0_mig_time),
        .csr_hppb_min_pgn_mig_time(csr_hppb_min_pgn_mig_time),
        .csr_hppb_max_pgn_mig_time(csr_hppb_max_pgn_mig_time),
        .csr_hppb_max_fifo_full_cnt(csr_hppb_max_fifo_full_cnt),
        .csr_hppb_max_fifo_empty_cnt(csr_hppb_max_fifo_empty_cnt),
        .csr_hppb_max_total_read_cnt(csr_hppb_max_total_read_cnt),
        .csr_hppb_max_total_write_cnt(csr_hppb_max_total_write_cnt),
        .csr_hppb_rresp_err_cnt(csr_hppb_rresp_err_cnt),
        .csr_hppb_bresp_err_cnt(csr_hppb_bresp_err_cnt),
        .csr_hppb_max_outstanding_rreq_cnt(csr_hppb_max_outstanding_rreq_cnt),
        .csr_hppb_max_outstanding_wreq_cnt(csr_hppb_max_outstanding_wreq_cnt),

        // .csr_host_ack_cnt(csr_host_ack_cnt),
        // .csr_ahppb_dst_addr_head(csr_ahppb_dst_addr_head),
        // .csr_need_new_base_cnt(csr_need_new_base_cnt),

       .csr_aruser(csr_aruser),
       .csr_awuser(csr_awuser),
       .csr_addr_ub(csr_addr_ub),
       .csr_addr_lb(csr_addr_lb)//,

    //    .csr_ahppb_src_addr_vld_cnt(csr_ahppb_src_addr_vld_cnt),
    //    .csr_ahppb_src_addr(csr_ahppb_src_addr)
   );

//USER LOGIC Implementation 
//
//


endmodule
