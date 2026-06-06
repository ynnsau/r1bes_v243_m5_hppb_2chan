// (C) 2001-2025 Altera Corporation. All rights reserved.
// Your use of Altera Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Altera Program License Subscription 
// Agreement, Altera IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Altera and sold by 
// Altera or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



///////////////////////////////////////////////////////////////////////////////
// This module handles the creation and wiring of the HPS clock/reset signals.
//
///////////////////////////////////////////////////////////////////////////////

// altera message_off 10036

 module altera_emif_arch_fm_hps_clks_rsts #(
   parameter PORT_CLKS_SHARING_MASTER_OUT_WIDTH      = 32,
   parameter PORT_CLKS_SHARING_SLAVE_IN_WIDTH        = 32,
   parameter PORT_DFT_ND_CORE_CLK_BUF_OUT_WIDTH      = 1,
   parameter PORT_DFT_ND_CORE_CLK_LOCKED_WIDTH       = 1,
   parameter PORT_HPS_EMIF_H2E_GP_WIDTH              = 1
) (
   // For a master interface, the PLL ref clock and the global reset signal
   // come from an external source from user logic, via the following ports. 
   // For slave interfaces, they come from the master via the sharing interface.
   // The connectivity ensures that all interfaces in a master/slave
   // configuration share the same ref clock and global reset, which is
   // one of the requirements for core-clock sharing.
   // pll_ref_clk_int is the actual PLL ref clock signal that will be used by the
   // reset of the IP. For a master interface it is equivalent to pll_ref_clk. 
   // For a slave interface it is equivalent to the pll_ref_clk signal of the master.
   input  logic                                                 pll_ref_clk,
   output logic                                                 pll_ref_clk_int,
   
   // Feedback signals to CPA via the core
   output logic [1:0]                                           core_clks_fb_to_cpa_pri,
   output logic [1:0]                                           core_clks_fb_to_cpa_sec,
   
   // Reset request signal.
   // local_reset_req_int is the actual reset request signal that will be
   // used internally by the rest of the IP. For a master interface it
   // is equivalent to local_reset_req. For a slave interface it is
   // equivalent to the local_reset_req signal of the master.
   input  logic                                                 local_reset_req,
   output logic                                                 local_reset_req_int,
   
   // The following is the master/slave sharing interfaces.
   input  logic [PORT_CLKS_SHARING_SLAVE_IN_WIDTH-1:0]          clks_sharing_slave_in,
   output logic [PORT_CLKS_SHARING_MASTER_OUT_WIDTH-1:0]        clks_sharing_master_out,
   
   // The following are all the possible core clock/reset signals.
   // afi_* only exists in PHY-only mode (or if soft controller is used).
   // emif_usr_* only exists if hard memory controller is used.
   output logic                                                 afi_clk,
   output logic                                                 afi_half_clk,
   output logic                                                 afi_reset_n,

   output logic                                                 emif_usr_clk,
   output logic                                                 emif_usr_half_clk,
   output logic                                                 emif_usr_reset_n,
   
   output logic                                                 emif_usr_clk_sec,
   output logic                                                 emif_usr_half_clk_sec,
   output logic                                                 emif_usr_reset_n_sec,

   // DFT
   output logic [PORT_DFT_ND_CORE_CLK_BUF_OUT_WIDTH-1:0]        dft_core_clk_buf_out,
   output logic [PORT_DFT_ND_CORE_CLK_LOCKED_WIDTH-1:0]         dft_core_clk_locked
);
   timeunit 1ns;
   timeprecision 1ps;
   
   // HPS clocks are not modeled for simulation.
   // Also in HPS mode we do not generate clocks that are visible to user logic.
   assign pll_ref_clk_int    = pll_ref_clk;
   
   // Reset request is not supported by HPS EMIF.
   // HPS EMIF has its own way of reset request mechanism.
   assign local_reset_req_int     = 1'b0;

   assign afi_clk                 = 1'b0;
   assign afi_half_clk            = 1'b0;
   assign afi_reset_n             = 1'b1;
   
   assign emif_usr_clk            = 1'b0;
   assign emif_usr_half_clk       = 1'b0;
   assign emif_usr_reset_n        = 1'b1;
   
   assign emif_usr_clk_sec        = 1'b0;
   assign emif_usr_half_clk_sec   = 1'b0;
   assign emif_usr_reset_n_sec    = 1'b1;
   
   assign core_clks_fb_to_cpa_pri = '0;
   assign core_clks_fb_to_cpa_sec = '0;
   assign clks_sharing_master_out = '0;
   
   assign dft_core_clk_locked     = '0;
   assign dft_core_clk_buf_out    = '0;
   
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+48V1PJhpE6b7/irP9UMubs1RTCOxZzvQb5stbk4w/0FPW5p3R3EQFsxlzvxw824f++LBRBLacIOOjIJyKgKhKfkmgwLtex/HveJxLX8YFUQ7Nj6vU8yS46/NMx3uHIswFYueO8yiIZrwd12UPgy7cPPmpa0rZZzhmQZyK8zRtwims1y/u8pb0DYaIB9v42qNgfjUyFSggIDMfL74/QWasp2R4gOgX8iU4hoBb/DdZoK1wAlKrwl02AwCaWR2pCLtgflc5C9t7zyyCzldlzAo5ahl6Iz8qCYL2PCNklICjE2vj0/RZb5OIyDhu+B7AbSz1PjB7pLDwUSRwhKlaEhnigoe7WvsbxvxoCUM0AIkpSw9wKpu9ncENd+gJcFabqlCMPcHqSUy1+wkdqeb7QLrIqpu8wNkSB2Yn8YAhXnn5R57EVBEnwc2XVmpHIm3cJ8ZorKeGasz+E1FB6LHsxiK4jKpYTml2pAsksOck4p0HcytNrk2hn3GJ3ynV6bwHsB5wqLi4uolBQz3sDcGBslGzwkBSQ/USqfmh1Go6nSXqU2tYSUGoha2+HEXURBuP50Ca+I7Lcw7/XGKKjdBKYc5YSHrApUdZ1L13tAicdmTkDSolzeDADq4WONMLdpa/VEhEnnYSl0rwSvyamib9YQKFv9ZrFkxEXTIwuCkx1qMSUXzGdX8AAy9G1QiqUlGsGL7jYYqqn3TlnCxSv9oyYSbxaHF0A80Hj819ZUeZ6IiELDB7Ef7h7xsFRKM4NaS8ykd/IowWCufRAD2zJHw8joa3s"
`endif