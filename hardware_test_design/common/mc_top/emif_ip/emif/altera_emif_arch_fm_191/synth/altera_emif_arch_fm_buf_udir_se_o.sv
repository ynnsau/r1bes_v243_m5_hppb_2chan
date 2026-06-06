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


module altera_emif_arch_fm_buf_udir_se_o #(
   parameter OCT_CONTROL_WIDTH = 1,
   parameter CALIBRATED_OCT = 1
) (
   input  logic i,
   output logic o,
   input  logic oe,
   input  logic oct_termin
);
   timeunit 1ns;
   timeprecision 1ps;

   generate
      if (CALIBRATED_OCT) 
      begin : cal_oct
         tennm_io_obuf obuf (
            .i(i),
            .o(o),
            .term_in(oct_termin),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .oe(oe),
            .dynamicterminationcontrol(),
            .devoe()
            );    
      end else 
      begin : no_oct
         tennm_io_obuf obuf (
            .i(i),
            .o(o),
            .seriesterminationcontrol(),
            .parallelterminationcontrol(),
            .obar(),
            .oe(oe),
            .dynamicterminationcontrol(),
            .devoe()
            );    
      end
   endgenerate
endmodule

`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+50haykdt7urVbEI6kqnQhPOnGuRt5+9HGVwNVVMlr71T9vCTnL+FOfEfB75d6aYIOqYAYkT2DoHwgvZ2b3XHWp6V+q4fpc/4x/E/Sk93VYmGjN3xhnouEhBLoAb0m/Cv8bxPt8lct3lMywWyMqvec0n34abXJ+q02mB6NeQ5+kvgIrGpRqZdWJgOG9izS50Fr8JhGxkY3H8z0LvcfuejZ0lMoO/DP8cyxxzQyaJbhCeg5P77vqLYwngmzShn/fsEDCZgmYwHkbfWm2rB8x1jxMHSm0oULvDE0gRZ10s85ri43qbV27aMmYDscRPQmiW+GJSlLc7ggbtoVfQTB8tzIDxP5u7MYImWTTfbwg3+kJfS0HDspwnbAlvTpNr21bGA/f1Wq6p7MoqSpZG9nQwoxkT1wQd3XVGw8Vfb8MyALMuhTqIimWK9XB+IEWlm9V6agGl/xCJWsc0b7fWbLmll3bxCACFslEzzFLzx16SDvv3+mwNwS7nDP5+uh/03KdVKIlu8bWyPiehxBts3hG6nQjkYF4aiBK1kCVQBh/eepb32UNoOHujXagzK9f1mGoqebGt1Zij90CjDofD8a9bc3/zQ7cY3/1gYITothyKMK7ETlO2A16ay4krSm229EM/wODOLpooYQpH2AqkU2qXT3dncHEN+/+w9de0EoX0pspueAxCj5B1t8DHWvuzch4KKKQRqeJOYUdLLxnmZRoUKBt9DcGXcs0tPHMxV+WJ8xg0D/cohpjFiZ9H2hOyIskF/gkrmixscteWA8WkhDEBzCD"
`endif