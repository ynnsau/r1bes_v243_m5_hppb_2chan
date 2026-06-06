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
//  Expose extra core clocks from IOPLL
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////
module altera_emif_arch_fm_pll_extra_clks #(
   parameter PLL_NUM_OF_EXTRA_CLKS = 0,
   parameter DIAG_SIM_REGTEST_MODE = 0
) (
   input  logic                                               pll_locked,            
   input  logic [8:0]                                         pll_c_counters,        
   output logic                                               pll_extra_clk_0,       
   output logic                                               pll_extra_clk_1,
   output logic                                               pll_extra_clk_2,
   output logic                                               pll_extra_clk_3,
   output logic                                               pll_extra_clk_diag_ok
);
   timeunit 1ns;
   timeprecision 1ps;
   
   logic [3:0] pll_extra_clks;
   
   // Extra core clocks to user logic.
   // These clocks are unrelated to EMIF core clock domains. The feature is intended as a
   // way to reuse EMIF PLL to generate core clocks for designs in which physical PLLs are scarce.
   assign pll_extra_clks   = pll_c_counters[8:5];
   assign pll_extra_clk_0  = pll_extra_clks[0];
   assign pll_extra_clk_1  = pll_extra_clks[1];
   assign pll_extra_clk_2  = pll_extra_clks[2];
   assign pll_extra_clk_3  = pll_extra_clks[3];
   
   // In internal test mode, generate additional counters clocked by the extra clocks
   generate
      genvar i;
      
      if (DIAG_SIM_REGTEST_MODE && PLL_NUM_OF_EXTRA_CLKS > 0) begin: test_mode
         logic [PLL_NUM_OF_EXTRA_CLKS-1:0] pll_extra_clk_diag_done;
      
         for (i = 0; i < PLL_NUM_OF_EXTRA_CLKS; ++i)
         begin : extra_clk
            logic [9:0] counter;

            always_ff @(posedge pll_extra_clks[i] or negedge pll_locked) begin
               if (~pll_locked) begin	
                  counter <= '0;
                  pll_extra_clk_diag_done[i] <= 1'b0;
               end else begin
                  if (~counter[9]) begin
                     counter <= counter + 1'b1;
                  end
                  pll_extra_clk_diag_done[i] <= counter[9];
               end
            end         
         end
         
         assign pll_extra_clk_diag_ok = &pll_extra_clk_diag_done;
         
      end else begin : normal_mode
         assign pll_extra_clk_diag_ok = 1'b1;
      end
   endgenerate
   
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "IurukvpYH/8+/WDspakoTaXH+Q6agJWvYHckqHJ+D/ViOnCNkf7YhzAy23h5CurtnybgQY7DqA2HeIRNB1Pcqq30nATi5sAc8uMyjWLhTrbgXDo0HhuhgiSHRiWu7LqEQntqg6ZiiMXZv8tjWpBIjqIIzvyRLUApEX0egjZ/iHmZDDUpd8mzvwWVi7yymC2VK+oZdaYBDw6TVLZKla3gx8pwuCHKIb6xmukyXRHXqOgb81Cv3pGIoXlMATIgRGLgKPT8pFsycAfGSB8HRiNGv/4MUkme0BBYqMA4ALmobKS2a2AUPLhtiOlX93qtYNsIMjw1URs+ndO6I9vUvGFdS7ISAVvk7T0SVJ3f8KSVd1Z57X0gCh2ZRBs6SBk8HBawwSErv53Buj5UNaS5HGkh+kIFNFX8ale3oshSlfoOoQXUGuGF4lcKpOkFSAVZoKFsFQaEi1XF0XZ0eEFNyeiG8sFHlOzUKdv8l8tqKpzovNeWYPfrHFjg8u+zbQoUWBZS03NvNnzlMs2jm2oNfdu6484l5ddTZ6CIRQKb4gtAn1XT4DdlRT8/82VXavI4VF0pUKRKlhgdlzWYeJALxTHWmUExw2R4FsEDZVBeCay83y1PW7mJ7zbnOPaxeloAxN7+EhAnlqEFFGM10Tf6NDNV/Kgiwhz7Zt8b2he0r0kvfEO5RgkU/0p5DBzfzrssqefzFIycdyrH9r7/c/evRkiWP57S6JPL04C0SRlAn9fMaSlNZqZ5qnAGFDC8Q3smT9iFBVEK/MynS57/V8By5iKUdvmbs9Uzy5o7ReBKqhDeOAvxr4yMNXF453X9jiUl/Xe6Bw9+pusTVbE6kU50t3v18eH2d5Jiaa6eAv704S26yFeZtYWX1vgGoEf0ZfMYtawPt8WYo2+nJZ4TYOhoehbypUbySj3H3/YiIt0NjIxeh4G4Rtj3t0Q/S4Ps3DfkjsPCEGo+vjjMVbjKOqVdNv6TJTrdV0lOZ0eKV90f43F8+vrv/9PkSlEpUkzyM0Gj+xnS"
`endif