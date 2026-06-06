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
// UFI wrapper for FalconMesa EMIFs
///////////////////////////////////////////////////////////////////////////////

module altera_emif_arch_fm_ufi_wrapper #(
   parameter MODE   = "pin_ufi_use_in_direct_out_direct",
   parameter IS_HPS = 1,
   parameter IS_C2P = 1,
   parameter HIPI_DELAY= 225,
   parameter TIEOFF = 0
) (
   input logic                                       i_src_clk,
   input logic                                       i_dst_clk,

   input  logic                                      i_din,
   output logic                                      o_dout
);
   generate
     if (TIEOFF) begin
        assign o_dout = i_din;
     end else begin
        if (IS_HPS && !IS_C2P) begin : hps_p2c_ufi
           (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON; -name HYPER_REGISTER_DELAY_CHAIN 225; -name PRESERVE_FANOUT_FREE_WYSIWYG ON"} *)
           tennm_ufi #(
             .mode    (MODE),
             .datapath("p2c")
           ) preserved_ufi_inst (
             .srcclk (i_src_clk),
             .destclk(i_dst_clk),
             .d      (i_din),
             .dout   (o_dout)
           );
        end else begin
           if (!IS_C2P) begin : p2c_ufi
              (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_PERIPHERY_CORE_TRANSFER ON"} *)
              tennm_ufi #(
                .mode    (MODE),
                .datapath("p2c")
              ) ufi_inst (
                .srcclk (i_src_clk),
                .destclk(i_dst_clk),
                .d      (i_din),
                .dout   (o_dout)
              );
           end else if (HIPI_DELAY == 350) begin : c2p_350_ufi 
              (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_CORE_PERIPHERY_TRANSFER ON; -name HYPER_REGISTER_DELAY_CHAIN 350"} *)
              tennm_ufi #(
                .mode    (MODE),
                .datapath("c2p")
              ) ufi_inst (
                .srcclk (i_src_clk),
                .destclk(i_dst_clk),
                .d      (i_din),
                .dout   (o_dout)
              );
           end else if (HIPI_DELAY == 100) begin: c2p_100_ufi
              (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_CORE_PERIPHERY_TRANSFER ON; -name HYPER_REGISTER_DELAY_CHAIN 100"} *)
              tennm_ufi #(
                .mode    (MODE),
                .datapath("c2p")
              ) ufi_inst (
                .srcclk (i_src_clk),
                .destclk(i_dst_clk),
                .d      (i_din),
                .dout   (o_dout)
              );
           end else begin: c2p_225_ufi
              (* altera_attribute = {"-name FORCE_HYPER_REGISTER_FOR_CORE_PERIPHERY_TRANSFER ON; -name HYPER_REGISTER_DELAY_CHAIN 225"} *)
              tennm_ufi #(
                .mode    (MODE),
                .datapath("c2p")
              ) ufi_inst (
                .srcclk (i_src_clk),
                .destclk(i_dst_clk),
                .d      (i_din),
                .dout   (o_dout)
              );
           end

        end
     end
     
   endgenerate 
         

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "IurukvpYH/8+/WDspakoTaXH+Q6agJWvYHckqHJ+D/ViOnCNkf7YhzAy23h5CurtnybgQY7DqA2HeIRNB1Pcqq30nATi5sAc8uMyjWLhTrbgXDo0HhuhgiSHRiWu7LqEQntqg6ZiiMXZv8tjWpBIjqIIzvyRLUApEX0egjZ/iHmZDDUpd8mzvwWVi7yymC2VK+oZdaYBDw6TVLZKla3gx8pwuCHKIb6xmukyXRHXqOhNB+iYyV5HyeMo5HArrR0L8VVxel6/0JAmU0Ymfkl6oizA+buybbkZVdY1p0jZoma9eV49ocCNdp4hDcPzaGRiukZlnmDRCSTP5Ff+LWL2Yg9aQ8CpHLUGn2RMO43FDspVtqM1WhNI5Taqg2c1jxZS1DEA+30AxsPybQcFMea5bnmapPkU8R6tRppkOpyO1VYTYjmJzGbZugOJAaTt6taHt/Pc1Q9MAbg1SpNbWaNonFrGZ5XU9Lny2/+3u6OOY++qtGyfhMsu67RTx8dvsIlmyvIqe6DkTRzSbCBQTUubsJ2QRodtsY2S0WieFm5RtkPF/g+knhUBfoavvI5AMPm7iryI2mMjpA4H+k8i67Sx1zThMz7BxVBnO2kwZ+mANwneqzLIwbVj/4rGiwPULwfg6jBxgb9pF1PpyAyKRpHJoEevXm+c2/S+de2eNyt3ASMaawgB4ZU0fdVSyInAS3LEnvU3uTV0qebn0JKenkbgiXSHeRhg6m1P7ScRCFEl8Qc2UhT1ZnLigw9g2ExeL+tMvncTnSMv6jDXeQG226Di25IvJpgGER/E9dAcIlOmHviF+TW8Ck72P01szVFYxRzWIieYTCrXnEs6X7sKA0qkvAXiOXRZ3bx+T0BfAU4yO7GkSsjGgUNNGOUNo18kdKgPWMgvfeeJuI9CB0A68pdPBG0lbjSooqnWAZoHAGw3/Bv5jj6k3DuiNlOnzpwfMCaoCNOMVSoRfCsd75g3ac02y+Zvy7bgMdnnP0mxKu5FwWGhC20rZhcGNLLZhjHNZKu/"
`endif