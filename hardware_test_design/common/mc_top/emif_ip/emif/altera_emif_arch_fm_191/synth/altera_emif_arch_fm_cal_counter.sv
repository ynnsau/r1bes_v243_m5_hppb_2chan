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



module altera_emif_arch_fm_cal_counter # (
   parameter IS_HPS = 0
) (
   input logic pll_ref_clk_int,
   input logic local_reset_req_int,
   input logic afi_cal_in_progress
);
   timeunit 1ps;
   timeprecision 1ps;

   typedef enum {
      INIT,
      IDLE,
      COUNT_CAL,
      STOP
   } counter_state_t;

   logic                         done;
   logic [31:0]                  clk_counter;

   generate
      if (IS_HPS == 0) begin : non_hps
         logic                         cal_done;
         logic                         reset_req_sync;
         logic                         cal_in_progress_sync;

         altera_std_synchronizer_nocut
         inst_sync_reset_n (
            .clk     (pll_ref_clk_int),
            .reset_n (1'b1),
            .din     (local_reset_req_int),
            .dout    (reset_req_sync)
         );

         altera_std_synchronizer_nocut
         inst_sync_cal_in_progress (
            .clk     (pll_ref_clk_int),
            .reset_n (1'b1),
            .din     (afi_cal_in_progress),
            .dout    (cal_in_progress_sync)
         );

         counter_state_t counter_state /* synthesis ignore_power_up */;

         assign done = ((counter_state == STOP) ? 1'b1 : 1'b0);

         always_ff @(posedge pll_ref_clk_int) begin
            if(reset_req_sync == 1'b1) begin
               counter_state <= INIT;
            end
            else begin
               case(counter_state)
                  INIT:
                  begin
                     clk_counter <= 32'h0;
                     counter_state <= IDLE;
                  end

                  IDLE:
                  begin
                     if (cal_in_progress_sync == 1'b1)
                     begin
                        counter_state <= COUNT_CAL;
                     end
                  end

                  COUNT_CAL:
                  begin
                     clk_counter[31:0] <= clk_counter[31:0] + 32'h0000_0001;

                     if (cal_in_progress_sync == 1'b0)
                     begin
                        counter_state <= STOP;
                     end
                  end

                  STOP:
                  begin
                     counter_state <= STOP;
                  end

                  default:
                  begin
                     counter_state <= INIT;
                  end
               endcase
            end
         end
      end else begin : hps
         assign done = 1'b1;
         assign clk_counter = '0;
      end
   endgenerate

`ifdef ALTERA_EMIF_ENABLE_ISSP
   altsource_probe #(         
      .sld_auto_instance_index ("YES"),
      .sld_instance_index      (0),
      .instance_id             ("CALC"),
      .probe_width             (33),
      .source_width            (0),
      .source_initial_value    ("0"),
      .enable_metastability    ("NO")
      ) cal_counter_issp (
      .probe  ({done, clk_counter[31:0]})
   );
`endif

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+4xEG4mW2W9hN+KjKEAkWHl1Gl4QxgvqhWcOsYRP5EvoW5O1AvSmB9Q+YVTth0ukR9YWUHpZmO/CDgcZyvlUCwgSxC6t8JzckPK8DhzsxGikNwR2ZhW3BrUPFo6+R7XATWTLAtCQl/QRIB5UnFvO/sA9HC317paSSVyYpurD+0GqNie8X6ALwzQlMTu/OpqFxcoRAjUVXYAYXnOxvlCiZ6EQTObH9cWQB//WWQV2xWQVlf2egMCjlkT3H4qTTiK1r3RQaMWHA2oqCbxAb+V8/SYZzOndb9p5WUK6ovKNE3Dmhd0e39YwWt6U+KGyL+vMcVRnM8iN+rhbZeynEzru8f/vXSWfSMWh3b2Lcl7MfdWKvTE/VyOAZ3wWTMP+wtyosWuXUij+K6gJXRiadNoGxIJj2u/fg1uR5TwGn7vYdQhEfim1ncIoTg+1nukTDG5uPzy0XZ73YPnbbB3/+y5G9l2bDSRDZQsYo20mHRkVWEUpWPQ7A/lZTs1Eo/VwbhI8pOwjEBKulKBqf52PLALhnVLEA86H/tdFJr5PNGKIYk8Ih5g6zJuB/nYJ9uf2CA2GOhFOrBdWjxvdVz1+TC8UqIBjJJHt5ppGkc7lxO2TEzC1l3BMuz8QvkjBYZW1pI9dQPleJBbwBAJf4/gUEo7+AgInLZlnGRZRAZIwz0TbU66RTjaZelksnrPbglieJQZjQJbsPhhiMb1zutP6HChmpiWAOEoPOtCgQMWncbNxuz+bWZrlI/9gMu23xCrBDkJGhc3kVDgmsljyDRuis/ZQCJ5"
`endif