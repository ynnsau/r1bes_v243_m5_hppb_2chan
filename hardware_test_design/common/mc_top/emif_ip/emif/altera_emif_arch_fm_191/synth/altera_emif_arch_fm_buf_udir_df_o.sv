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


module altera_emif_arch_fm_buf_udir_df_o #(
   parameter OCT_CONTROL_WIDTH = 1,
   parameter CALIBRATED_OCT = 1
) (
   input  logic i,
   input  logic ibar,
   output logic o,
   output logic obar,
   input  logic oein,
   input  logic oeinb,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;

   localparam DCCEN = "true";

   logic pdiff_out_o;
   logic pdiff_out_obar;

   logic pdiff_out_oe;
   logic pdiff_out_oebar;

   tennm_pseudo_diff_out # (
      .feedthrough("true")
   ) pdiff_out (
      .i(i),
      .ibar(ibar),
      .o(pdiff_out_o),
      .obar(pdiff_out_obar),
      .oein(oein),
      .oebin(oeinb),
      .oeout(pdiff_out_oe),
      .oebout(pdiff_out_oebar),
      .dtcin(),
      .dtcbarin(),
      .dtc(),
      .dtcbar()
   );

   generate
      if (CALIBRATED_OCT)
      begin : cal_oct
         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf (
            .i(pdiff_out_o),
            .o(o),
            .oe(pdiff_out_oe),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .obar(),
            .devoe()
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf_bar (
            .i(pdiff_out_obar),
            .o(obar),
            .oe(pdiff_out_oebar),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .obar(),
            .devoe()
         );
      end else
      begin : no_oct
         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf (
            .i(pdiff_out_o),
            .o(o),
            .oe(pdiff_out_oe),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .obar(),
            .devoe()
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf_bar (
            .i(pdiff_out_obar),
            .o(obar),
            .oe(pdiff_out_oebar),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .obar(),
            .devoe()
         );
      end
   endgenerate

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+7RekSLY2bx0/y/u7NVBBgfP0AlhKL28WFo55u2u6AC7o0BRJX1CP5jl+unE7xS2YSiuV0wYA/lLfRy+kAEUqx+o0zAIxBcI9WL7WoRRuq0yxJT8I3bUvBWCeSbatVkJIWrM1b/gL9o1m0BKccxkMUKG1jiYjGHJANIuz8NC7hFTOQmDnqh1ew3AHAhYDCTMRpGYVmPQQ1NzdEVhW5U+vwu0uSinF3lEBmZT7SRrG0ciVmHIE43mMbvqLWAjfiD7DsW6uNlKUyHgxYbcQqmIBnpwn+m+es01YvyLRjb5alARLMoUIZsfmYeCh8EhEFQVDYgEIcKsPbzTchDOwbeATQ31aOzjCvz8iD0bAWclCZHytqww20yPiNeCGlFX1X8be0h1cqTadlX0tucW5F4X4RxgbWo6xCFULolmkuTUIK89T8WpbEi0PaNkinW2gDnwhZQ9Bkf4lcGuMLp2h4/TNJRQb0jucXbitHNiw0hZn+0+egPCfQb0rFcDtrZkHCpwpfhwHvxfVr2sEI2fChxK3F4dbMSHcnU8rJerFejB/fb28Jl/8+ZgwrgGNpwZy/l+ntz20x6ZqJcfezLgwFKUu+37y5T1H56JvPiuBERYLmK2+wv3GQTemYZE3AoX22KkqRLyrn7LcEDaRAQ1Uu1GelWpPgb3MARyj9aEHNtrbI9g+fGHbgX7IdG/eMfHvx3CGHoIkkfaSFyhR1ZIgP9Xfosd1a5gVZQefKfvLF8Fprr5RiAK0huoCFKy5IcUjIv8HbvQRG/TNxFE7ujwd8ocBp2"
`endif