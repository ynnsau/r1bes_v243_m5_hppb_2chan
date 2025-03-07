// (C) 2001-2024 Intel Corporation. All rights reserved.
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
///////////////////////////////////////////////////////////////////////
`include "ccv_afu_globals.vh.iv"

module alg1a_verify_sc_top
    import ccv_afu_pkg::*;
    import cafu_common_pkg::*;
(
  input logic clk,
  input logic reset_n,  // active low reset
 
  /* signals to/from mwae top-level FSM
  */
  input logic i_mwae_busy,          // active high
  input logic i_mwae_set_to_busy,   // active high
 
  output logic o_verify_sc_busy,    // active high
 
  /*  signals for read only mode to skip error recordings
  */
  input logic i_reads_only_mode_enable,
 
  /*   signals to/from the alg1a top level FSM
  */
  input logic [51:0] i_current_X,
  input logic [31:0] i_current_P,
  input logic        i_clear_errors, // active high, should be top level FSM set_to_busy
  input logic        i_enable_verify_sc_gen_read_reqs,  // active high

  /*  signals from configuration and debug registers  
  */
  input logic [7:0]  i_number_of_address_increments_reg,
  input logic [2:0]  i_verify_semantics_cache_reg,
  input logic        i_single_transaction_per_set,        // active high
  input logic [31:0] i_address_increment_reg,
  input logic        i_force_disable_afu,                 // active high
  input logic [2:0]  i_pattern_size_reg,
  input logic [63:0] i_byte_mask_reg,
  input logic        i_latency_mode,
  input logic [8:0]  i_NAI,
  input logic [37:0] i_RAI,

  /* signals to ccv afu top-level FSM and debug registers
  */
  output logic o_record_error_flag_out,
  output logic o_slverr_received,
  output logic o_poison_received,

  output logic [7:0]  o_error_addr_increment,
  output logic [31:0] o_error_expected_pattern,
  output logic [31:0] o_error_received_pattern,
  output logic [51:0] o_error_address,
  output logic [5:0]  o_error_byte_offset,
  output logic        o_error_found_out,
 
  /* signals for AXI-MM read address channel
  */
  output cafu_common_pkg::t_cafu_axi4_rd_addr_ch       o_read_addr_chan,
  input  cafu_common_pkg::t_cafu_axi4_rd_addr_ready    i_arready,
 
  /* signals for AXI-MM read address channel
  */
  input  cafu_common_pkg::t_cafu_axi4_rd_resp_ch       i_read_resp_chan,
  output cafu_common_pkg::t_cafu_axi4_rd_resp_ready    o_rready
);

// ================================================================================================
localparam FIFO_PTR_WIDTH = 4;

logic gen_read_reqs_start_response_phase;
logic read_rsp_busy_flag;
 
logic [FIFO_PTR_WIDTH-1:0] gen_read_reqs_fifo_count;
logic                      gen_read_reqs_fifo_empty;
logic [8:0]                gen_read_reqs_fifo_out_N;
logic [51:0]               gen_read_reqs_fifo_out_addr;
logic                      gen_read_reqs_fifo_pop;
logic                      gen_read_reqs_set_to_not_busy;
logic                      gen_read_reqs_set_to_busy;

cafu_common_pkg::t_cafu_axi4_rd_addr_ch      from_verify_sc_axi_rd_addr;
cafu_common_pkg::t_cafu_axi4_rd_addr_ready   to_verify_sc_axi_arready;

// ================================================================================================
alg1a_verify_sc_gen_read_reqs
#(
   .FIFO_PTR_WIDTH ( FIFO_PTR_WIDTH )
)
inst_gen_read_reqs
(
  .clk ( clk ),
  .reset_n ( reset_n ),

  /* signals to/from ccv afu top-level FSM
  */
  .enable_in ( i_enable_verify_sc_gen_read_reqs ),

  /*  signals from configuration and debug registers  
  */
  .number_of_address_increments_reg ( i_number_of_address_increments_reg ),
  .single_transaction_per_set       ( i_single_transaction_per_set ),
  .address_increment_reg            ( i_address_increment_reg ),
  .force_disable_afu                ( i_force_disable_afu ),
  .NAI                              ( i_NAI ),
  .RAI                              ( i_RAI ),
  
  /*   signals to/from the alg1a top level FSM
  */
  .current_X_in ( i_current_X ),

  /*  signals to/from the Algorithm 1a self checking verify
      reponse phase
  */
  .response_phase_busy_flag ( read_rsp_busy_flag ),
  .start_response_phase_out ( gen_read_reqs_start_response_phase ),
  .busy_flag_out            ( o_verify_sc_busy ),

  /* signals to/from axi read channel control / send read reqs fsm
  */
  .fifo_count    ( gen_read_reqs_fifo_count    ),
  .fifo_empty    ( gen_read_reqs_fifo_empty    ),
  .fifo_out_N    ( gen_read_reqs_fifo_out_N    ),
  .fifo_out_addr ( gen_read_reqs_fifo_out_addr ),
  .fifo_pop      ( gen_read_reqs_fifo_pop      ),
 
  .o_set_to_not_busy ( gen_read_reqs_set_to_not_busy ),
  .o_set_to_busy     ( gen_read_reqs_set_to_busy     )
);

// ================================================================================================
alg1a_verify_sc_send_read_reqs
#(
   .FIFO_PTR_WIDTH ( FIFO_PTR_WIDTH )
)
inst_send_read_reqs
(
  .clk            ( clk ),
  .reset_n        ( reset_n ),

  .force_disable_afu ( i_force_disable_afu ),
  .set_to_busy       ( gen_read_reqs_set_to_busy ),
  .set_to_not_busy   ( gen_read_reqs_set_to_not_busy ),

  .verify_semantics_cache_reg ( i_verify_semantics_cache_reg ),

  .fifo_count    ( gen_read_reqs_fifo_count    ),
  .fifo_empty    ( gen_read_reqs_fifo_empty    ),
  .fifo_out_N    ( gen_read_reqs_fifo_out_N    ),
  .fifo_out_addr ( gen_read_reqs_fifo_out_addr ),
  .fifo_pop      ( gen_read_reqs_fifo_pop      ),
 
  //.latency_mode_enabled ( i_latency_mode ),
 
  /* signals for AXI-MM read address channel
  */
  .read_addr_chan ( from_verify_sc_axi_rd_addr ),   //o_read_addr_chan ),
  .arready        ( to_verify_sc_axi_arready   )  //i_arready )
);

// ================================================================================================
alg1a_latency_mode
#(
  .READSORWRITES( 0 )
 )
inst_latency_mode
(
  .clk     ( clk ),
  .reset_n ( reset_n ),

  /* signals from ccv afu config register space
  */
  .i_forceful_disable ( i_force_disable_afu ),
  .i_latency_mode     ( i_latency_mode ),
 
  /* signals from gen axi reqs
     same enable to send read reqs or send write reqs
  */ 
  .i_enable       ( gen_read_reqs_set_to_busy ),
  .i_set_not_busy ( gen_read_reqs_set_to_not_busy ),

  /*  AXI-MM interface channels
  */
  .i_from_execute_axi_wr_addr ( '0 ),
  .o_to_cxlip_axi_wr_addr     ( ),
 
  .i_from_cxlip_axi_awready ( '0 ),
  .o_to_execute_axi_awready ( ),
  
  .i_from_execute_axi_wr_data ( '0 ),
  .o_to_cxlip_axi_wr_data     ( ),

  .i_from_cxlip_axi_wready ( '0 ),
  .o_to_execute_axi_wready ( ),
 
  .i_from_verify_sc_axi_rd_addr ( from_verify_sc_axi_rd_addr ),
  .o_to_cxlip_axi_rd_addr       ( o_read_addr_chan ),

  .i_from_cxlip_axi_arready   ( i_arready ),
  .o_to_verify_sc_axi_arready ( to_verify_sc_axi_arready ),
 
  .i_from_cxlip_axi_wr_resp_bvalid ( 1'b0 ),
  .i_from_cxlip_axi_rd_resp_rvalid ( i_read_resp_chan.rvalid )
);

// ================================================================================================
alg1a_verify_sc_read_resps   inst_read_resps
(
  .clk            ( clk ),
  .reset_n        ( reset_n ),

  /*  signals for read only mode to skip error recordings
  */
  .reads_only_mode_enable ( i_reads_only_mode_enable ),

  /*  signals from configuration and debug registers
  */
  .number_of_address_increments_reg ( i_number_of_address_increments_reg ),
  .single_transaction_per_set       ( i_single_transaction_per_set ),
  .address_increment_reg            ( i_address_increment_reg ),
  .force_disable_afu                ( i_force_disable_afu ),
  .pattern_size_reg                 ( i_pattern_size_reg ),
  .byte_mask_reg                    ( i_byte_mask_reg ),
  .NAI                              ( i_NAI ),
  .RAI                              ( i_RAI ),
  
  /*   signals from the top level FSM
  */
  .clear_errors_in ( i_clear_errors ),
  .current_X_in    ( i_current_X ),
  .current_P_in    ( i_current_P ),

  /*  signals from the Algorithm 1a self checking verify
      read phase
  */
  .i_mwae_busy ( i_mwae_busy ),
  .enable_in   ( gen_read_reqs_start_response_phase ),

  /* signals to ccv afu top-level FSM and debug registers
  */
  .error_received_pattern ( o_error_received_pattern ),
  .error_expected_pattern ( o_error_expected_pattern ),
  .record_error_flag_out  ( o_record_error_flag_out ),  
  .error_addr_increment   ( o_error_addr_increment ),
  .error_byte_offset      ( o_error_byte_offset ),
  .slverr_received        ( o_slverr_received ),
  .poison_received	      ( o_poison_received ),
  .error_found_out        ( o_error_found_out ),
  .error_address          ( o_error_address ),

  /*  signals to the Algorithm 1a self checking verify
      read phase
  */
  .busy_out ( read_rsp_busy_flag ),

  /* signals for AXI-MM read address channel
  */
  .read_resp_chan ( i_read_resp_chan ),
  .rready         ( o_rready )
);


endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "CKUI7fxegcKVh4tgW/mpuzitVwewYkyz7TMV7+f90AhBJKvD98sjfBvbmxSG1I1A3LysG9obCcPnyzMPnYyMrcpXk+K7GRJExc8254QvDHvfaCJnqYA5D6Nac4KKUymNNkbEDeIpCIqDEhWJyac7SOjB3oz/PXRc7JbbIpxix+KArfwGhCgez+E/prMj1lSPbv0SwkqnoDiPBAW09C88cJ22OwduIBFqDrKD1asfb1Jb19RlFLvLcvGM2cFl1GiBDlT7ykObkiyU9/4VmAqP+nPZShBDR7uG0Q+FwCgR+gdYQRxV6IoBFgmRhQ1d7UJqfnDMOOHvv5J8+H8cGdZYWIDqM4ATGndh+5WKYUmJva1lKZw3f95VjtHiFJzveEvav0bU7RJMIvRmEz9ULyE2dGgrA/7J2SDsOu7B30fKpx9Hlp0P/jdjZ366w/odxTYgqc6jyJoGi0Y596Kz8Qoy3JTpXXI4hFDI7NUWDiAjWHm3kkdUAEX5nuINEJi5n5H3q+AUyrOANXAFPsW0Kp2YP28p2+j2Hlog+pBlP0vq/2pMtSIyr2ZkL3tB2LAY3COX6OCBR8k6bK9QNy3A1WLoNmMe0NUAp5CYPwPszMXTD/fMh9msINoUMyGrS813UyWdB5qZqgWDIrSVXyuubY13UA5RgMz8eNuTecGJccjGgMq7NUkHmWlUcq/NxxQhw835tYAuwz2IV2stW+LGHbuElTbC82gJ6O1JIMX9McLhphIt13Aq8k7rmfS4oVNJu4VmT5lelWC0RNeRmT+JR3P1zHEUPvjuHus3ksXq1Z6M3UHmmRFqDNz3R0Uikt53VQo6oXrA7RKt/b7wa3eWNB2AHw8kBGr/Ewld2fBr586SVwSV3GpryxBvYZarymYkfOb1x4Ben+aOl7e8mZa4qWDPzHzfHWm9DZ7WctVuxGFC9KYGVsAVGO+NuQH5/ezthqYklJbhp6SpqU+YKtPQnFS0U8OyiOp5nLk34bzITpVrszT+09IIBsNTt0qS8tVTCYRG"
`endif