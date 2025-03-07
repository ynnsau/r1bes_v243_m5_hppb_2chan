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

module alg1a_execute_top
    import ccv_afu_pkg::*;
    import cafu_common_pkg::*;
(
  input logic clk,
  input logic reset_n,  // active low reset
 
  /* signals to/from ccv afu top-level FSM
  */
   input logic        i_enable_exec_wr_reqs,      // active high
   input logic [31:0] i_current_P,
   input logic [51:0] i_current_X,
  output logic        o_execute_busy,

  /*  signals to/from configuration and debug registers
  */
  output logic o_execute_response_slverr_received,        // active high
  
  input logic [7:0]  i_number_of_address_increments_reg,  
  input logic        i_single_transaction_per_set,         // active high
  input logic [3:0]  i_write_semantics_cache_reg,  
  input logic [31:0] i_address_increment_reg,
  input logic        i_force_disable_afu,
  input logic [2:0]  i_pattern_size_reg,
  input logic        i_latency_mode_req,
  input logic [63:0] i_byte_mask_reg,
  input logic [8:0]  i_NAI,
  input logic [37:0] i_RAI,

  /* signals to/from mwae top-level FSM
  */
  input logic i_mwae_set_to_busy,   // active high

  /* signals for AXI-MM write address channel
  */
   input cafu_common_pkg::t_cafu_axi4_wr_addr_ready  i_awready,
  output cafu_common_pkg::t_cafu_axi4_wr_addr_ch     o_write_addr_chan,

  /* signals for AXI-MM write data channel
  */
   input cafu_common_pkg::t_cafu_axi4_wr_data_ready  i_wready,
  output cafu_common_pkg::t_cafu_axi4_wr_data_ch     o_write_data_chan,
 
  /* signals for AXI-MM write responses channel
  */
  output cafu_common_pkg::t_cafu_axi4_wr_resp_ready  o_bready,
  input  cafu_common_pkg::t_cafu_axi4_wr_resp_ch     i_write_resp_chan 
);

// ================================================================================================
logic latency_mode_awready;
logic latency_mode_wready;

/*  signals to/from the Algorithm 1a response count phase
*/
logic enable_write_resps_fsm;
logic write_resps_fsm_busy;   // active high, response count < NAI flag 

/* signals to/from send write reqs
*/
logic         from_send_fifo_pop;
logic         to_send_fifo_empty;
logic [3:0]   to_send_fifo_count;
logic [8:0]   to_send_fifo_out_N;
logic [51:0]  to_send_fifo_out_addr; 
logic         to_send_set_to_busy;
logic         to_send_set_to_not_busy;
logic [511:0] to_send_ERP;

cafu_common_pkg::t_cafu_axi4_wr_addr_ch      from_execute_axi_wr_addr;
cafu_common_pkg::t_cafu_axi4_wr_addr_ready   to_execute_axi_awready;
cafu_common_pkg::t_cafu_axi4_wr_data_ch      from_execute_axi_wr_data;
cafu_common_pkg::t_cafu_axi4_wr_data_ready   to_execute_axi_wready;

// ================================================================================================
alg1a_execute_gen_write_reqs    inst_gen_write_reqs
(
  .clk ( clk ),
  .reset_n ( reset_n ),

  /* signals to/from ccv afu top-level FSM
  */
  .enable_in        ( i_enable_exec_wr_reqs ),
  .current_P_in     ( i_current_P ),
  .current_X_in     ( i_current_X ),
  .execute_busy_out ( o_execute_busy ),

  /*  signals to/from the Algorithm 1a response count phase
  */
  .start_response_count_phase_out ( enable_write_resps_fsm ),
  .response_phase_busy            ( write_resps_fsm_busy ),
 
  /* signals to/from send write reqs
  */
  .fifo_pop        ( from_send_fifo_pop ),
  .fifo_empty      ( to_send_fifo_empty ),
  .fifo_count      ( to_send_fifo_count ),
  .fifo_out_N      ( to_send_fifo_out_N ),
  .fifo_out_addr   ( to_send_fifo_out_addr ),
  .set_to_busy     ( to_send_set_to_busy ),
  .set_to_not_busy ( to_send_set_to_not_busy ),
  .ERP             ( to_send_ERP ),

  /*  signals from configuration and debug registers
  */
  .number_of_address_increments_reg ( i_number_of_address_increments_reg ),
  .single_transaction_per_set       ( i_single_transaction_per_set ),
  .write_semantics_cache_reg        ( i_write_semantics_cache_reg ),
  .address_increment_reg            ( i_address_increment_reg ),
  .force_disable_afu                ( i_force_disable_afu ),
  .pattern_size_reg                 ( i_pattern_size_reg ),
  .byte_mask_reg                    ( i_byte_mask_reg ),
  .NAI                              ( i_NAI ),
  .RAI                              ( i_RAI )
);

// ================================================================================================
alg1a_execute_send_write_reqs    inst_send_write_reqs
(
  .clk        ( clk        ),
  .reset_n    ( reset_n    ),

  /* signals to/from gen write reqs
  */
  .fifo_pop        ( from_send_fifo_pop ),
  .fifo_empty      ( to_send_fifo_empty ),
  .fifo_count      ( to_send_fifo_count ),
  .fifo_out_N      ( to_send_fifo_out_N ),
  .fifo_out_addr   ( to_send_fifo_out_addr ),
  .set_to_busy     ( to_send_set_to_busy ),
  .set_to_not_busy ( to_send_set_to_not_busy ),
  .pipe_4_ERP      ( to_send_ERP ),
  .pipe_4_N        ( to_send_fifo_out_N ),
 
  .byte_mask_reg     ( i_byte_mask_reg ),
  .clock_addr_chan   (),
  .force_disable_afu ( i_force_disable_afu ),

  .write_semantics_cache_reg ( i_write_semantics_cache_reg ),

  /* signals for AXI-MM write address channel
  */
  .awready         ( to_execute_axi_awready   ), //i_awready ),
  .write_addr_chan ( from_execute_axi_wr_addr ), //o_write_addr_chan ),

  /* signals for AXI-MM write data channel
  */
  .wready          ( to_execute_axi_wready    ), //i_wready ),
  .write_data_chan ( from_execute_axi_wr_data ) //o_write_data_chan )
);

// ================================================================================================
alg1a_latency_mode
#(
  .READSORWRITES ( 1 )
 )
inst_latency_mode
(
  .clk        ( clk        ),
  .reset_n    ( reset_n    ),

  /* signals from ccv afu config register space
  */
  .i_forceful_disable ( i_force_disable_afu ),
  .i_latency_mode     ( i_latency_mode_req ),
 
  /* signals from gen axi reqs
     same enable to send read reqs or send write reqs
  */ 
  .i_enable       ( to_send_set_to_busy ),
  .i_set_not_busy ( to_send_set_to_not_busy ),

  /*  AXI-MM interface channels
  */
  .i_from_execute_axi_wr_addr ( from_execute_axi_wr_addr ),
  .o_to_cxlip_axi_wr_addr     ( o_write_addr_chan ),
  
  .i_from_cxlip_axi_awready ( i_awready ),
  .o_to_execute_axi_awready ( to_execute_axi_awready ),
  
  .i_from_execute_axi_wr_data ( from_execute_axi_wr_data ),
  .o_to_cxlip_axi_wr_data     ( o_write_data_chan ),

  .i_from_cxlip_axi_wready ( i_wready ),
  .o_to_execute_axi_wready ( to_execute_axi_wready ),
 
  .i_from_verify_sc_axi_rd_addr ( '0 ),
  .o_to_cxlip_axi_rd_addr       ( ),
 
  .i_from_cxlip_axi_arready   ( '0 ),
  .o_to_verify_sc_axi_arready ( ),

  .i_from_cxlip_axi_wr_resp_bvalid ( i_write_resp_chan.bvalid ),
  .i_from_cxlip_axi_rd_resp_rvalid ( 1'b0 )
);

// ================================================================================================
alg1a_execute_write_resps   inst_write_resps
(
  .clk        ( clk        ),
  .reset_n    ( reset_n    ),

  /*  signals to/from the write phase FSM of the execute stage of Algorithm 1a
  */
  .enable_in ( enable_write_resps_fsm ),

  /*  signals around a SLVERR on the AXI write response channel
  */
  .busy_out        ( write_resps_fsm_busy ),
  .clear_slverr    ( i_mwae_set_to_busy ),
  .slverr_received ( o_execute_response_slverr_received ),

  /* signals for AXI-MM write responses channel
  */
  .bready          ( o_bready ),
  .write_resp_chan ( i_write_resp_chan ),

  /*  signals from configuration and debug registers
  */
  .number_of_address_increments_reg ( i_number_of_address_increments_reg ),
  .single_transaction_per_set       ( i_single_transaction_per_set ),
  .force_disable_afu                ( i_force_disable_afu ),
  .NAI                              ( i_NAI )
);
  

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "CKUI7fxegcKVh4tgW/mpuzitVwewYkyz7TMV7+f90AhBJKvD98sjfBvbmxSG1I1A3LysG9obCcPnyzMPnYyMrcpXk+K7GRJExc8254QvDHvfaCJnqYA5D6Nac4KKUymNNkbEDeIpCIqDEhWJyac7SOjB3oz/PXRc7JbbIpxix+KArfwGhCgez+E/prMj1lSPbv0SwkqnoDiPBAW09C88cJ22OwduIBFqDrKD1asfb1J87XUcLXiaq0e2xgvA5K4btMYT6J0NATn28JoNVW1FIEGi7LGS8DecYnw7/HuKQn+WV9HmVFSLP2GVcE7+8icub00qDuaCX8acOwPcZx41hpAY0RPDdFSmBj4byNs2XJeFJWHsVf5etR9JdLuTs8io1RsFdUiQmzlysmdztIeGB8tdu3t6mvOAlqpnJpEHZ8CvgewODw+RlsGBJOIPnAKOpJFpDdn+krwiu/PlCPKSAEUS4fK5te3n94LiVQ7ZyzEOf4WIzjTJd8aaMclPxfma0E4Uv0mEWVu85TyExs1Ncn8NrzEXnDtJjLCHaMqm/LH9l8i+4AYB6kOoWtYrKLTRNP56HrGPJUKQqmTDD63xoIL2hhRt9szKklgpu1eRNqXN+F4z4eY0IViAB1QP6jrnwXYCXXt4KkPN2pEnEq+AbFK6HIeHfKYa3GtnoR1O35S16L+pd9UcLJnzxPUanj8P3yqmYjkGifBIcglZa8K+IYOnlhnD6u7DGTAjfMqhxvXYuZ6hXMYiPsrXEVei/M5u5VfHdcEnlQtQjWAFnqpXtSkcvgSDPBE3dXe5CFd7EdbI6aKqxCoY2tb7tXQw1qvqRWCibiyAOGmo1KaxJwzfy4h6vI6bhGghxxW0nhtYjx3vzPzQQozaVe8Zp3mk3c35PA6Insq0DPyoyk+nussJDsH/3assNJlFn+yQJUt9AO/KSZkN43mqsRdsCyDuW4eGXCGKsTQl7OUdzsK+wk64RLOoHcNPrdcseb4b7Bao7vPvPa36IUJaAquS+imF6pVH"
`endif