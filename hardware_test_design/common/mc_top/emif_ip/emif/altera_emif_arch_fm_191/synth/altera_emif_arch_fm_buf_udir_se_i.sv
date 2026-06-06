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


module altera_emif_arch_fm_buf_udir_se_i #(
   parameter OCT_CONTROL_WIDTH = 1,
   parameter CALIBRATED_OCT = 1
) (
   input  logic i,
   input  logic oct_termin,
   output logic o
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
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .ibar(),
            .dynamicterminationcontrol()
            );    
      end else 
      begin : no_oct
         tennm_io_ibuf ibuf(
            .i(i),
            .o(o),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .ibar(),
            .dynamicterminationcontrol()
            );
      end
   endgenerate
endmodule

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+6xTwWoCU7dNZNMtnO8ThM7RCS4VzvduVjzoskaV76clRuUgwfGqxJt/yHy8M1k8p+763hUv4vWZtn8H/0AFVbueayvqesfF8exftWJM3KpD01jNzyugt21UsIQZPdi+Ds/9bO3bE72ljJqELyNlsvsElHfUP4j5LgYgP0S/W0QbydEomVb78MWbCvaxG2Scusd+Ye7KavG6h3AniyDi+BBcXFSPLkip0dwVdcNjFjg3EDH3zIFcTePPpD6SpExapOfaFwp+wQRClF/YDllVQCLOLSeXZ7zN2aarJojHWIL+bh8hykNmw64S4bRh09OvyPdHLa3O58vTEMEuGib1O5o6tIBswibYRSenHxgs67i0CRSLIOUPdJuSQfT75NG91UxgDvORhUKGMTRl0hf6n9EzTgnKYdpcTDSyiFD5uRjugDBm6yVTOBkP8vJbsGdXnz94AG3uF9zFP45Eem+CvNytL6lS7Lfvr6H9J0JX4cazen2h7qET/Fprp09LHyi0SsymLWL1UeFx5o/eLWNXOHj0XHAhLsXdPW0ka58cCT6DO98RBYQ433PCUh9r0PD99alMbJ+vzpXSi+Pkgm9QcdyBdMBENbGaSeMnR2+oIXmXbjKwySkoe4p6oq1k1db3cu5RhW0ALOP4UaMvOXOi7eBcefYS7nvvAzGalOpVgKjY3+sjW0MmRZB2ERQyLB7hz7va4GO9/I8YcZFitEtp0t1jY9iq4sX0cjB8VpqAyuD1hUfVsgufWCjooVrEHQzK1yIYwKa8XFHfiaGTuaFJGV0"
`endif