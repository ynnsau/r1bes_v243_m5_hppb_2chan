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




module afu_top

import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
(
    
      input  logic                                             afu_clk,
      input  logic                                             afu_rstn,
     // April 2023 - Supporting out of order responses with AXI4
      input  ed_mc_axi_if_pkg::t_to_mc_axi4    [MC_CHANNEL-1:0] cxlip2iafu_to_mc_axi4,
      output ed_mc_axi_if_pkg::t_to_mc_axi4    [MC_CHANNEL-1:0] iafu2mc_to_mc_axi4 ,
      input  ed_mc_axi_if_pkg::t_from_mc_axi4  [MC_CHANNEL-1:0] mc2iafu_from_mc_axi4,
      output ed_mc_axi_if_pkg::t_from_mc_axi4  [MC_CHANNEL-1:0] iafu2cxlip_from_mc_axi4
    
);




//Passthrough User can implement the AFU logic here 
      assign iafu2mc_to_mc_axi4      = cxlip2iafu_to_mc_axi4;
      assign iafu2cxlip_from_mc_axi4 = mc2iafu_from_mc_axi4;



endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "POizRfZBu2Za2e25gOrjvm1fIPLBk0eZmyFcDIFazcJl7PX67tT/saAlNoEXLHgw5mDQeEFh0JzMQ+qx/C0+PVE6a6spr5K6BpvxdLuS075hXOTsVE7Wc/lebFBxsNWYC7WKZkRFLi9LEIJIuDzdBuFqpnd6KNxaDlPfUh7jN8WMLzEL3yixxC+CcpZ1nL96FjsMR9I8wgkeME02AXMssvm/ZFxRfH2JRVTb/5Z7jzDsL2WpgVfQCjjHJ6iHMXgtMukpclk89l2S7mS02ZKKST94bLCO2ECwg+Qx3EKTSDKbEjLPA4iRDxcG0cx9Lm6nvljWvXWNQUxcJX5cGnR3yu0fadxCvEy/bsyJ37AQeJOTGRkhql/aCDLyCb+nZtjXCNJecS5+hX0J7UXt0aPP/5Coe4GPyIL3o13OhlUy9gnw5MMa+KXm8MoygZ9Ho+GazWtkKEhqZwR9t+9defkCmebYc0ra7/3ttH5Z4Fj7vf3vDtnGK93QnK/PLVJ3ZZqVFSvV9ddXOLiBNjNdlRglX/IE8WbqJFxGUGmUnfIm7+rfGGaHeE8STkXd+Q4OWFhGPi+7+suo1KZb0vEV45VSoWGAIkdwmMewkV6KrNqUPte75hX/Az3mhdMe/xsF8Vn/6k7CsLAxiFJrRFfEEl9JGj3aUG8PTkBg9QdhrfUBCCwIuP+ru3tHaiL7/zG3HYc2K1jnmaxgtdHxGYJ+BV/bOoO0oIUw4qSNlSQiyYaJDAgkvOeAxnlWNGol76gAwWvaVQIxlA+dD7epTUECBThTwpVRQD2b+urfoi7KmamtJ0AVQY4szoiXghLRPt/jJeIYozC/3CS6PfLYQRF0DWqLy0qV5XjFpgIbp9ciRtdgFvm5T1NZfX0hHmRqDBVahGpPCtwF7CIQ3BXw4yWF5Ib0NsPQsxpbQa65b4h5e8eSmcWGeOfQHWHWs526rgAHJtGht+TVaUDB941HR7l8hkGYKJn3qrDIABM3KG4zM5hN2PRlsGy+wpiC3cWlxctnww5f"
`endif