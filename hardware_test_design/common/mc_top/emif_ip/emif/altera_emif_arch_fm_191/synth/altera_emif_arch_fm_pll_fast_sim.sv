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



////////////////////////////////////////////////////////////////////////////////////////////////////////////
//  EMIF IOPLL instantiation for 20nm families
//
//  The following table describes the usage of IOPLL by EMIF. 
//
//  PLL Counter    Fanouts                          Usage
//  =====================================================================================
//  VCO Outputs    vcoph[7:0] -> phy_clk_phs[7:0]   FR clocks, 8 phases (45-deg apart)
//                 vcoph[0] -> DLL                  FR clock to DLL
//  C-counter 0    lvds_clk[0] -> phy_clk[1]        Secondary PHY clock tree (C2P/P2C rate)
//  C-counter 1    loaden[0] -> phy_clk[0]          Primary PHY clock tree (PHY/HMC rate)
//  C-counter 2    phy_clk[2]                       Feedback PHY clock tree (slowest phy clock in system)
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////
module altera_emif_arch_fm_pll_fast_sim #(
   parameter PLL_SIM_VCO_FREQ_PS                     = 0,
   parameter PLL_SIM_PHYCLK_0_FREQ_PS                = 0,
   parameter PLL_SIM_PHYCLK_1_FREQ_PS                = 0,
   parameter PLL_SIM_PHYCLK_FB_FREQ_PS               = 0,
   parameter PLL_SIM_PHY_CLK_VCO_PHASE_PS            = 0,
   parameter PORT_DFT_ND_PLL_CNTSEL_WIDTH            = 1,
   parameter PORT_DFT_ND_PLL_NUM_SHIFT_WIDTH         = 1,
   parameter PORT_DFT_ND_PLL_CORE_REFCLK_WIDTH       = 1
   
) (
   input  logic                                               pll_ref_clk_int,       
   output logic                                               pll_locked,            
   output logic                                               pll_dll_clk,           
   output logic [7:0]                                         phy_clk_phs,           
   output logic [1:0]                                         phy_clk,               
   output logic                                               phy_fb_clk_to_tile,    
   input  logic                                               phy_fb_clk_to_pll,     
   output logic [8:0]                                         pll_c_counters,        
   input  logic                                               pll_phase_en,          
   input  logic                                               pll_up_dn,             
   input  logic [PORT_DFT_ND_PLL_CNTSEL_WIDTH-1:0]            pll_cnt_sel,           
   input  logic [PORT_DFT_ND_PLL_NUM_SHIFT_WIDTH-1:0]         pll_num_phase_shifts,  
   output logic                                               pll_phase_done,        
   input  logic [PORT_DFT_ND_PLL_CORE_REFCLK_WIDTH-1:0]       pll_core_refclk        
);
   timeunit 1ps;
   timeprecision 1ps;

   localparam VCO_PHASES = 8;

   reg vco_out, phyclk0_out, phyclk1_out, fbclk_out;
   reg [4:0] pll_lock_count;
   // synthesis translate_off
   initial begin
      vco_out <= 1'b1;
      forever #(PLL_SIM_VCO_FREQ_PS/2) vco_out <= ~vco_out;
   end
   initial begin
      phyclk0_out <= 1'b1;
      #(PLL_SIM_VCO_FREQ_PS*PLL_SIM_PHY_CLK_VCO_PHASE_PS/VCO_PHASES);
      forever #(PLL_SIM_PHYCLK_0_FREQ_PS/2) phyclk0_out <= ~phyclk0_out;
   end
   initial begin
      phyclk1_out <= 1'b1;
      #(PLL_SIM_VCO_FREQ_PS*PLL_SIM_PHY_CLK_VCO_PHASE_PS/VCO_PHASES);
      forever #(PLL_SIM_PHYCLK_1_FREQ_PS/2) phyclk1_out <= ~phyclk1_out;
   end
   initial begin
      fbclk_out <= 1'b1;
      #(PLL_SIM_VCO_FREQ_PS*PLL_SIM_PHY_CLK_VCO_PHASE_PS/VCO_PHASES);
      forever #(PLL_SIM_PHYCLK_FB_FREQ_PS/2) fbclk_out <= ~fbclk_out;
   end

   initial begin
      pll_lock_count <= 5'b0;
   end
   // synthesis translate_on
   
   always @ (posedge vco_out) begin
      if (pll_lock_count != 5'b11111) begin
         pll_lock_count <= pll_lock_count + 1;
      end
   end

   assign pll_locked = (pll_lock_count == 5'b11111);
   assign pll_dll_clk = pll_locked & vco_out;
   assign phy_clk_phs[0] = pll_locked & vco_out;
   always @ (*) begin
      phy_clk_phs[1] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[0];
      phy_clk_phs[2] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[1];
      phy_clk_phs[3] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[2];
      phy_clk_phs[4] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[3];
      phy_clk_phs[5] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[4];
      phy_clk_phs[6] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[5];
      phy_clk_phs[7] <= #(PLL_SIM_VCO_FREQ_PS/VCO_PHASES) phy_clk_phs[6];
   end
   assign phy_clk = {pll_locked & phyclk1_out, pll_locked & phyclk0_out};
   assign phy_fb_clk_to_tile = pll_locked & fbclk_out;
   assign pll_c_counters[0] =  pll_locked & phyclk1_out; 
   assign pll_c_counters[1] =  pll_locked & phyclk0_out;
   assign pll_c_counters[2] =  pll_locked & fbclk_out;
   assign pll_c_counters[8:3] = 6'd0;
   assign pll_phase_done = 1'b1;

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "IurukvpYH/8+/WDspakoTaXH+Q6agJWvYHckqHJ+D/ViOnCNkf7YhzAy23h5CurtnybgQY7DqA2HeIRNB1Pcqq30nATi5sAc8uMyjWLhTrbgXDo0HhuhgiSHRiWu7LqEQntqg6ZiiMXZv8tjWpBIjqIIzvyRLUApEX0egjZ/iHmZDDUpd8mzvwWVi7yymC2VK+oZdaYBDw6TVLZKla3gx8pwuCHKIb6xmukyXRHXqOiQXWn5XEB9qU6b90eS3nBlw9IqcaR/frsbpZo9YOyf3uHNPt09/jDcnjkp7fMtmZfElxA/hBGm+ByaVTrqOV+aXFScUwtwdA04PeYWB1IJ1bgtzamKhkzuJdN9UwmZErJQXLo3IKuwqO7GVQOq/UHXsoVQZz98B5r0t/+wNVV5jWZGRwUpDio6CKErJuHgHj09OTovbbNVmHRbj3816EUMWZxMyWgTpUt76g9WFr1foQ/druIEYtjZdeFY3t5gpXNVsQAabKJhb3qgkCsCnkO0uQY3HmptywW46bAvfjL2sHD2Rn/sdU/Pz82z+UdefsBfREC9K/U9s7o/o2x8cuApNIBSTLSKfeciwZJ5XB4+ry38pmgkc3ozgkTidbaDtEdt9llZ6OoUj9L3biGS/OTae/u/b+8lZvUR1eoeq/F6uaLMM9mkwIddZjcGEyZ90EhOYceXWZII6EneKSu0pK0NTpMcaQe5oudDWDONSdcUa+63AJoiyU5P3CZdEHO/Gk4TVnYs15PxstxTfu17q/niGb45dml8v1ueaX6PwSJRT33iakQFUE05gRYByaBqxYtafXwGrK3d3LKGq17dQRt8rCJQfBPyMBDml48Zt8m4MFUsKeUC8/SCqKw896MdWB2nMnl8p8cUxH5kvH5iJaQA8wv7mmcWyiDLh6O7YCSvg8M4xLHpiSjD4jJ2uKW6+Ufm9i3HJHJYqvSdKkYNKMNEO8soOKO6aAFgJlLrXX+eWZfHmnHkW2geEbGksBEzBqYlkWk802kOy08aYY6kZacN"
`endif