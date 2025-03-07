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


import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
import m5_pkg::*;


module afu_top#(
  // common parameter
  parameter ADDR_SIZE = 34,
  parameter CNT_SIZE = 14,

  // CM-sketch parameter
  parameter W = 32768,
  parameter W_UNIT = 4096,
  parameter NUM_SKETCH = W / W_UNIT,
  parameter SKETCH_INDEX_SIZE = $clog2(NUM_SKETCH),
  parameter COLUMN_INDEX_SIZE = $clog2(W_UNIT),
  parameter NUM_HASH = 4, // number of hash function, MUST be exponential of 2
  parameter HASH_SIZE = $clog2(W),

  // sorted CAM parameter
  parameter NUM_ENTRY = 25,
  parameter INDEX_SIZE = 5 // $clog2(NUM_ENTRY)
)(

    input  logic                                             afu_clk,
    input  logic                                             afu_rstn,

    input                   page_query_en,
    output                  page_query_ready,
    output                  page_mig_addr_en,
    output [ADDR_SIZE-1:0]  page_mig_addr,
    input                   page_mig_addr_ready,
    output                  mem_chan_rd_en,

    // April 2023 - Supporting out of order responses with AXI4
    input  ed_mc_axi_if_pkg::t_to_mc_axi4    [MC_CHANNEL-1:0] cxlip2iafu_to_mc_axi4,
    output ed_mc_axi_if_pkg::t_to_mc_axi4    [MC_CHANNEL-1:0] iafu2mc_to_mc_axi4 ,
    input  ed_mc_axi_if_pkg::t_from_mc_axi4  [MC_CHANNEL-1:0] mc2iafu_from_mc_axi4,
    output ed_mc_axi_if_pkg::t_from_mc_axi4  [MC_CHANNEL-1:0] iafu2cxlip_from_mc_axi4

);
localparam PAGE_ADDR_SIZE   = 22;


//Passthrough User can implement the AFU logic here 
assign iafu2mc_to_mc_axi4      = cxlip2iafu_to_mc_axi4;
assign iafu2cxlip_from_mc_axi4 = mc2iafu_from_mc_axi4;

m5_pkg::queue_struct_t chan0_queue_struct;
m5_pkg::queue_struct_t chan1_queue_struct;
m5_pkg::queue_struct_t queue_output_struct;
m5_pkg::queue_struct_t to_tracker_struct;

assign chan0_queue_struct.araddr = cxlip2iafu_to_mc_axi4[0].araddr;
assign chan0_queue_struct.arvalid = cxlip2iafu_to_mc_axi4[0].arvalid;
assign chan0_queue_struct.arready = mc2iafu_from_mc_axi4[0].arready;

assign chan1_queue_struct.araddr = cxlip2iafu_to_mc_axi4[1].araddr;
assign chan1_queue_struct.arvalid = cxlip2iafu_to_mc_axi4[1].arvalid;
assign chan1_queue_struct.arready = mc2iafu_from_mc_axi4[1].arready;

logic tracker_buff_empty, tracker_buff_full, tracker_buff_empty_r;
logic chan0_valid, chan1_valid, request_both, request_none;
assign chan0_valid = (chan0_queue_struct.arvalid & chan0_queue_struct.arready);
assign chan1_valid = (chan1_queue_struct.arvalid & chan1_queue_struct.arready);
assign request_both = (chan0_valid & chan1_valid);
assign request_none = (!chan0_valid & !chan1_valid);

logic[5:0] usedw;

fifo_36w_64d tracker_buff
(
  .data  (chan1_queue_struct),
  .wrreq (request_both & ~tracker_buff_full),
  .rdreq (request_none & ~tracker_buff_empty),
  .clock (afu_clk),
  .q     (queue_output_struct),
  .usedw (usedw),
  .full  (tracker_buff_full),
  .empty (tracker_buff_empty)
);

always_comb begin
    to_tracker_struct = chan0_queue_struct;
    case({chan1_valid, chan0_valid})
        2'b00:
            to_tracker_struct = tracker_buff_empty_r ? chan0_queue_struct : queue_output_struct;
        2'b01:
            to_tracker_struct = chan0_queue_struct;
        2'b10:
            to_tracker_struct = chan1_queue_struct;
        2'b11:
            to_tracker_struct = chan0_queue_struct;
    endcase
end

always_ff @ (posedge afu_clk) begin
    if(!afu_rstn) begin
        tracker_buff_empty_r <= 1'b0;
    end else begin 
        tracker_buff_empty_r <= tracker_buff_empty;
    end
end

hot_tracker_top
#(
  // common parameter
  .ADDR_SIZE(ADDR_SIZE),
  .DATA_SIZE(PAGE_ADDR_SIZE),
  .CNT_SIZE(CNT_SIZE),

  // CM-sketch parameter
  .W(W),
  .W_UNIT(W_UNIT),
  .NUM_SKETCH(NUM_SKETCH),
  .SKETCH_INDEX_SIZE(SKETCH_INDEX_SIZE),
  .COLUMN_INDEX_SIZE(COLUMN_INDEX_SIZE),  
  .NUM_HASH(NUM_HASH),
  .HASH_SIZE(HASH_SIZE),

  // sorted CAM parameter
  .NUM_ENTRY(NUM_ENTRY),
  .INDEX_SIZE(INDEX_SIZE)
)
  page_hot_tracker_top_chan_0
(
  .clk                      (afu_clk),
  .rstn                     (afu_rstn),

//`ifdef OOORSP_MC_AXI2AVMM // April 2023 - Supporting out of order responses with AXI4
  .to_tracker_struct           (to_tracker_struct),
  //`else

  // hot tracker interface
  .query_en                 (page_query_en),
  .query_ready              (page_query_ready),

  .mig_addr_en              (page_mig_addr_en),
  .mig_addr                 (page_mig_addr),
  .mig_addr_ready           (page_mig_addr_ready),
  .mem_chan_rd_en           (mem_chan_rd_en)
);

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "POizRfZBu2Za2e25gOrjvm1fIPLBk0eZmyFcDIFazcJl7PX67tT/saAlNoEXLHgw5mDQeEFh0JzMQ+qx/C0+PVE6a6spr5K6BpvxdLuS075hXOTsVE7Wc/lebFBxsNWYC7WKZkRFLi9LEIJIuDzdBuFqpnd6KNxaDlPfUh7jN8WMLzEL3yixxC+CcpZ1nL96FjsMR9I8wgkeME02AXMssvm/ZFxRfH2JRVTb/5Z7jzDsL2WpgVfQCjjHJ6iHMXgtMukpclk89l2S7mS02ZKKST94bLCO2ECwg+Qx3EKTSDKbEjLPA4iRDxcG0cx9Lm6nvljWvXWNQUxcJX5cGnR3yu0fadxCvEy/bsyJ37AQeJOTGRkhql/aCDLyCb+nZtjXCNJecS5+hX0J7UXt0aPP/5Coe4GPyIL3o13OhlUy9gnw5MMa+KXm8MoygZ9Ho+GazWtkKEhqZwR9t+9defkCmebYc0ra7/3ttH5Z4Fj7vf3vDtnGK93QnK/PLVJ3ZZqVFSvV9ddXOLiBNjNdlRglX/IE8WbqJFxGUGmUnfIm7+rfGGaHeE8STkXd+Q4OWFhGPi+7+suo1KZb0vEV45VSoWGAIkdwmMewkV6KrNqUPte75hX/Az3mhdMe/xsF8Vn/6k7CsLAxiFJrRFfEEl9JGj3aUG8PTkBg9QdhrfUBCCwIuP+ru3tHaiL7/zG3HYc2K1jnmaxgtdHxGYJ+BV/bOoO0oIUw4qSNlSQiyYaJDAgkvOeAxnlWNGol76gAwWvaVQIxlA+dD7epTUECBThTwpVRQD2b+urfoi7KmamtJ0AVQY4szoiXghLRPt/jJeIYozC/3CS6PfLYQRF0DWqLy0qV5XjFpgIbp9ciRtdgFvm5T1NZfX0hHmRqDBVahGpPCtwF7CIQ3BXw4yWF5Ib0NsPQsxpbQa65b4h5e8eSmcWGeOfQHWHWs526rgAHJtGht+TVaUDB941HR7l8hkGYKJn3qrDIABM3KG4zM5hN2PRlsGy+wpiC3cWlxctnww5f"
`endif
