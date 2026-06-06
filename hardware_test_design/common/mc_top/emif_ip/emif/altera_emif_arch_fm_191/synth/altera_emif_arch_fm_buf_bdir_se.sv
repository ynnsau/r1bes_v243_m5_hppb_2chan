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


module altera_emif_arch_fm_buf_bdir_se #(
   parameter OCT_CONTROL_WIDTH = 1,
   parameter HPRX_CTLE_EN = "off",
   parameter HPRX_OFFSET_CAL = "false",
   parameter CALIBRATED_OCT = 1
) (
   inout  tri   io,
   output logic ibuf_o,
   input  logic obuf_i,
   input  logic obuf_oe,
   input  logic obuf_dtc,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;
   
   generate
      if (CALIBRATED_OCT) 
      begin : cal_oct
         tennm_io_ibuf # (
            .hprx_ctle_en (HPRX_CTLE_EN),
            .hprx_offset_cal (HPRX_OFFSET_CAL)
         ) ibuf (
            .i(io),
            .o(ibuf_o),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .ibar()
            );
            
         tennm_io_obuf obuf (
            .i(obuf_i),
            .o(io),
            .oe(obuf_oe),
            .term_in(oct_termin),
            .dynamicterminationcontrol(obuf_dtc),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .devoe()
            );
      end else 
      begin : no_oct
         tennm_io_ibuf # (
            .hprx_ctle_en (HPRX_CTLE_EN),
            .hprx_offset_cal (HPRX_OFFSET_CAL)
         ) ibuf (
            .i(io),
            .o(ibuf_o),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol(),
            .ibar()
         );
            
         tennm_io_obuf obuf (
            .i(obuf_i),
            .o(io),
            .oe(obuf_oe),
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
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+6ECr5+syY18/7pPPjZ/1Rg0wIxKlOAmyraVS2wr9ZPItk234IscwyvFXPOCxMkh4c9YJAI81+ILBHOz1bqMbDZ5yKxSccTmittO5ig81n5BUCyoTleGkgJcYJVUwmi43ehIkyQO2CaB32A9+ZzPooBPsPJFvanecvg46nt2o/je585wIE0MMdqsyati3aqeMMldkBYMTjVEWVZ70Swhp82R2zW40ro7VhmjdYedUBnLEhaKua9uqdmC26klPkg6Fc6kKVo5iDnJAx93xsoyNP4CT+Q/Hop+XyiOLu9DexFxSMdcGnqDVgoQmfSAE1qpbxydrTDXDLEwZI8Y21rS8OX7dqCAZXThfQi0mq2C7gEiI0XFwBRSzTYCMZbRuexpRVfs6rVuNHorG3BbzlZDdRPp3MIyr3zos1svpAhZXDRkm2PxXn841ODqo/Xpq23pXCiK0nutjLXG0rFLEtcUifWw/o61fqs82LFj65RBQWYyO6+8WVtzZIyrYEBMVpejmjCHuQZUBZT7XFlksiP1y7AkjtyP3CfDQvb+PuB9vJMwQWITLfi2sTxHXS3ECIp7QDsnvNpmiDMGp8j2+E+cqo+3e2hTgJCuk/smi3DAdIqBc0Cw94tQBGphsq7AjLttDRdS141ep62vsBBHHDZrZp3g3EEaw5qIjUdRkOwNKpQ/q7XGa9gTQy4c41LRk59bhPBCrAq5AoCdDf7m55t1HqGAV2D4bqbSyv0eAq740eu1STRs0LARpH3ojlJkHLX+IYT7vLTvvdMlYg3LEaPOcEw"
`endif