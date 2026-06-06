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



module altera_emif_arch_fm_oct #(
   parameter PHY_CALIBRATED_OCT = 0
) (
   input  logic oct_rzqin, 
   output logic oct_termin 
);
   localparam OCT_USER_OCT = "A_OCT_USER_OCT_OFF";

   generate if (PHY_CALIBRATED_OCT == 1) begin
     tennm_termination term_inst (
       .req_recal (1'b0),
       .ack_recal (/*open*/),
       .rzqin     (oct_rzqin),
       .serdataout(oct_termin)
     );
   end
   endgenerate

endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+5Wcl52n8hNyJ3cSlHo/IRH0/71VWaRwGUzTs2593M5Poq3YzbPm7hK9udD18fg+Axd6YX1KsvOXv8x371mchsUBpLgvR86UX1ZiakiJKg/3LDD+jDWCVAY+UDiSxLYRO4UFRj/Af2zhMzNtK1bPP2JNt2t+slzz8VF4Hc3abeYN6u4dZxzEvjUecdNOXsCWX5cSsJiZs4Xllr1ydnWtGErYFJHwQhEus8WFJGUxhhHC3ZM7tH5Nq9JepIm0SBnRfmOQ7L1hAKIcYAfbYMYWsMf9myXBCgdQyfWdq75EYWPOgJNd5WGyrFpebevKEQ8mB4hlIXi+772oxsiuQgqScU11BlkMtwmcWVlGBzdhYOseRSncjv5JZIJTG0xhODBaPaExHU7YxhyVgPuOwBpg6F440ysLipWxdq4oznjUuNqQH+AFZ9KG7yhmddmTs1QUqcRgTKBYWibMj1jV4KwwNi0sWHKwXnjOaa21+QgFoMiitGRMnm37aQ24sOUigGoFn5tioCDPLZ0o0//bHTWcqJgkuucA9zEaRsFGFHdGTVNqi3W2gYX4jxzFdpsJKtP5zvbBIgl+pyo8LJdaaDyJ8USCUs32V8sMzSFoFFFuoeEt310U3RG7wWmWJ2tISZQ1pjrdi1/rsGRMftHWYBmGfUiJ0tUK3xZ2w60a8c82uzguxuOF3flQTTSPrjoLrDTr1657CyfXFTud+ZVTHBL4tyCloCCFUMI2wVdjV5hGH/wGsHviZGbHAHrlXoZ5TaZ66fF/gwzMKCeRIWxTDrsT72o"
`endif