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


module altera_emif_arch_fm_buf_bdir_df #(
   parameter OCT_CONTROL_WIDTH = 1,
   parameter HPRX_CTLE_EN = "off",
   parameter HPRX_OFFSET_CAL = "false",
   parameter CALIBRATED_OCT = 1
) (
   inout  tri   io,
   inout  tri   iobar,
   output logic ibuf_o,
   input  logic obuf_i,
   input  logic obuf_ibar,
   input  logic obuf_oe,
   input  logic obuf_oebar,
   input  logic obuf_dtc,
   input  logic obuf_dtcbar,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;

   localparam DCCEN = "true";

   logic pdiff_out_o;
   logic pdiff_out_obar;
   logic pdiff_out_oe;
   logic pdiff_out_oebar;

   generate
      if (CALIBRATED_OCT)
      begin : cal_oct
         logic pdiff_out_dtc;
         logic pdiff_out_dtcbar;

         tennm_io_ibuf # (
            .hprx_ctle_en (HPRX_CTLE_EN),
            .hprx_offset_cal (HPRX_OFFSET_CAL),
            .differential_mode ("true")
         ) ibuf (
            .i(io),
            .ibar(iobar),
            .o(ibuf_o),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
         );

         tennm_pseudo_diff_out # (
            .feedthrough ("true")
         ) pdiff_out (
            .i(obuf_i),
            .ibar(obuf_ibar),
            .oein(obuf_oe),
            .oebin(obuf_oebar),
            .dtcin(obuf_dtc),
            .dtcbarin(obuf_dtcbar),
            .o(pdiff_out_o),
            .obar(pdiff_out_obar),
            .oeout(pdiff_out_oe),
            .oebout(pdiff_out_oebar),
            .dtc(pdiff_out_dtc),
            .dtcbar(pdiff_out_dtcbar)
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf (
            .i(pdiff_out_o),
            .o(io),
            .oe(pdiff_out_oe),
            .term_in(oct_termin),
            .dynamicterminationcontrol(pdiff_out_dtc),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .devoe()
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf_bar (
            .i(pdiff_out_obar),
            .o(iobar),
            .oe(pdiff_out_oebar),
            .term_in(oct_termin),
            .dynamicterminationcontrol(pdiff_out_dtcbar),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .devoe()
         );
      end else
      begin : no_oct
         tennm_io_ibuf  # (
            .hprx_ctle_en (HPRX_CTLE_EN),
            .hprx_offset_cal (HPRX_OFFSET_CAL),
            .differential_mode ("true")
         ) ibuf (
            .i(io),
            .ibar(iobar),
            .o(ibuf_o),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
         );

         tennm_pseudo_diff_out # (
            .feedthrough ("true")
         ) pdiff_out (
            .i(obuf_i),
            .ibar(obuf_ibar),
            .oein(obuf_oe),
            .oebin(obuf_oebar),
            .dtcin(),
            .dtcbarin(),
            .o(pdiff_out_o),
            .obar(pdiff_out_obar),
            .oeout(pdiff_out_oe),
            .oebout(pdiff_out_oebar),
            .dtc(),
            .dtcbar()
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf (
            .i(pdiff_out_o),
            .o(io),
            .oe(pdiff_out_oe),
            .dynamicterminationcontrol(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .devoe()
         );

         tennm_io_obuf # (
            .dccen(DCCEN)
         ) obuf_bar (
            .i(pdiff_out_obar),
            .o(iobar),
            .oe(pdiff_out_oebar),
            .dynamicterminationcontrol(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .devoe()
         );
      end
   endgenerate
endmodule

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+68VkapifKFc7PhxeW4yq6lGsi0vcggvp/9jRsr2y/G86uHe/6RRn38/qonJBnTl365vi6acXMQyjpaqezuRftEyRa5DxgSrOorGbxIV+MzqLj5z4cBRRVSHIbiY2m9A06F5/c7wHyqFMa0tLi8nfWhXB7LevbW5Wiw5LxcepP9vMKpOKfhpBxWiKY/agJ/V23mFNnlIXOhXRIS9R+fdiSpTtrsUMRN2zZmIptTYhx1tugOqcoLMux4m6vVih5JDNh7J7cmmP5azPPdUEsZ66krQImQBQ36znR2pjll0Vjcbxx5pPBSbdHGWgC8zLSX1numbpzUHg2RiGgBDz7zlSa9LvbjqJy4VKZUen+A0R1c/2Ee4ytwtli2Xf+Q5iRmH/VZBomuI5VhSX0zpYysvVExk4nMQ8qi+4F+U4CdF1eJqiq1KNkIX2NZLbKnc3ryxkt/3DqixgY1fqkGxJASUmVDaTmiFbT+K47tjaVFN1lxHVJm83OGvS71A1QAIYdmJqjdpMZgnSsHJ88nIeN1fyvKuijYUgXZRltgwv9OXaHmaH71VDO15NtbJTsMiCIyXm2kDq6rSGjFx3dzKJ0oiVV0zUqOnK9dRLpxOfFJiL45dxb2qAnhwza+lP+3G48RJ+r/MfUrHXdiCgJf4taxBnCVk01FxuWUnPIf7SxvMxDTzLoxXC4d8atkg6vW9XAKSwNJY2w9WU3MC63KwnhpcNK0y0QezAvXZOUaLCQA5/v/Zf8I6X9xpg3HYVAj4ovlnL/BmZln5CDh1xpKe4NBNBA1"
`endif