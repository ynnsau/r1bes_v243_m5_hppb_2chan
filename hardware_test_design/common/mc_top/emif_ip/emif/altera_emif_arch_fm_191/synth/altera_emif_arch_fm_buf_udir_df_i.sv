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


module altera_emif_arch_fm_buf_udir_df_i # (
   parameter OCT_CONTROL_WIDTH = 1,
   parameter CALIBRATED_OCT = 1
) (
   input  logic i,
   input  logic ibar,
   output logic o,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;
   
   generate
      if (CALIBRATED_OCT) 
      begin : cal_oct   
         tennm_io_ibuf  # (
            .differential_mode ("true")
         ) ibuf (
            .i(i),
            .ibar(ibar),
            .o(o),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );
      end else 
      begin : no_oct
         tennm_io_ibuf  # (
            .differential_mode ("true")
         ) ibuf (
            .i(i),
            .ibar(ibar),
            .o(o),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );      
      end
   endgenerate      
endmodule

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+4hXuH3mIGBnG+4PLos3XOPUCWOB0mTbD5MqMwrrUIcQ52FpH6j6D4VVbzVrV2DL1YM66ejgLfM7mC3Br/TRelv6FY1rRjy2ExF2g/ATYBXhZf7wx/TomcATVLqZpPgGitb/9NJKCirMXiiMN0ODfjlghx52+8SFbOXldtY1r3sEM4o0vhX+NnnYKizA9W/9rsxxpv9WaT/BJ2dva3cAIRb7pW3bLt3KZWlPvo23mrnw69+ljpiN++xXohjgOL9MiGGfW7gpqi1u2MpO7Bxo8/6+oz29OD0HGXnOvPsyrPqZ3pQp3nyqOm+peMduJ3xB4xsQe4dxSrhtSb4RqAHEZkiRmimOBc52T3EtCKrLBNZ8Lt4Ph1J3PJFWqUfmAL1bKCrLM8RJK6u3VTazTKGl0GxJQZlK4GLI6Qy8sGLkbAoM7rkteHqjQmRNlpAQ1h3WlbhsSHNwkfqEoiaXntnsOUVmydjeZ3/vaQtDVrpUiaWIPFtEQ3z36IN0/oSg2HntfrTjsNa0m3PQ2JgI57YvfBIdUHROBniQXgCJDSvB6gGy+pyN+qflpZaJf2GGiPNNa1P3O+7X6t7sMNYLk8SPRVWF1hZumLoLrqURsTLTDXg0r7a56drrZ0hjP80j4bi3y0DJJVqBc113cV5zfGYxzR5Mc+1w8Arl4xs0Oy0aWh0uBclT60wCfJvPZFIsTD3K5IRbgD9shax8yqhbNUgfhY8W4jYD6PI0F+URzBWnCW0Kgmw0FJgsqTE+VKWpSZ9C4c3gnsIX5ONvKFtOXDoMdl4"
`endif