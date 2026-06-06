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


module altera_emif_arch_fm_buf_udir_cp_i # (
   parameter OCT_CONTROL_WIDTH = 1,
   parameter CALIBRATED_OCT = 1
) (
   input  logic i,
   input  logic ibar,
   output logic o,
   output logic obar,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;
   
   generate
      if (CALIBRATED_OCT) 
      begin : cal_oct      
         tennm_io_ibuf ibuf(
            .i(i),
            .o(o),
            .term_in(oct_termin),
            .ibar(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );
            
         tennm_io_ibuf ibuf_bar(
            .i(ibar),
            .o(obar),
            .term_in(oct_termin),
            .ibar(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );
      end else 
      begin : no_oct
         tennm_io_ibuf ibuf(
            .i(i),
            .o(o),
            .ibar(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );
            
         tennm_io_ibuf ibuf_bar(
            .i(ibar),
            .o(obar),
            .ibar(),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .dynamicterminationcontrol()
            );      
      end
   endgenerate
endmodule

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+61hVg/V4a43vAIdIO9S+RZJMZ0HV8Usr6Y/dkKr1AIqjvHz8KkKdljZaE9JsESZlHuom+tN6tbp9bLjE5+X9N/vPueE7tROpq4DprCbL4yzkkAoUd3bubiS75OEEKtzPoGJM0yWT+Buv9XkgVg4HzJPngcyQWH28x95XKqPX+W12nqifj0VMqRJvkbS8d6NWjSVtogRSS9z56jO3bYjqQcqiizT8Orc95WJ7LHsUfV/gaB5gL4JdiJPqtTBhXcPnMGSHWTAM6FDsivqng4AaBb654EOMnyqp5gn0yDQOOMLOFqQIJBHilHmhestmEwDAhlLm1bdaagF2RsXs9TX10OyGWCKgTEAKXazr1b7fbp6pTDBaEOkgYKHJJtv0eCAzevxKXSyOXLtMR1d1sYNrOziB6hNWqxrl5rR1kr+RXMmFmXQ3e/QZTYhCIBBhzUhakWj7PZ4wrq3gEyEjV3y3LJciF0XZJX8nKVho5inAIDU62D1xv3yN+8uwE0w4GJnyHaWpY26puiWXlUSPOOncHnyEXAkPXdqpah5uQtKQvnXTasUpviYrC/ZgcbZ0OQyibosp7Rt+iRlyMPY0yCX3HG9lwjadK0kJPnrfTDoktFFBAz96m9PvPNp4ERONlNyqBo2yWL+KsrfUqMt5J5DF+JuFnog0SUGI2aNHEzERFb12gBoZtOy5E1z2ZVbvhhrPFaNwa0h5uz6H0RBoBk2gfOqH3wLvWOU264Y94Lg1MR9BTLZWqUv0VO91zQ4Fu2SvcuyafxbGxpsLTpDhDArZpa"
`endif