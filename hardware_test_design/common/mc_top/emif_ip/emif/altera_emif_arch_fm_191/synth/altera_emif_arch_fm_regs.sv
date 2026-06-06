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
// This module handles the creation of a conditional register stage.
// This module may be used to implement a synchronizer (with properly selected
// REGISTER value)
///////////////////////////////////////////////////////////////////////////////

// The following ensures that the register stage isn't synthesized into
// RAM-based shift-regs (especially if customer logic implements another follow-on
// pipeline stage). RAM-based shift-regs can degrade timing for C2P/P2C transfers.
(* altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *)

 module altera_emif_arch_fm_regs #(
   parameter REGISTER       = 0,
   parameter WIDTH          = 0
) (
   input  logic              clk,
   input  logic              reset_n,
   input  logic [WIDTH-1:0]  data_in,
   output logic [WIDTH-1:0]  data_out
) /* synthesis dont_merge */;
   timeunit 1ns;
   timeprecision 1ps;

   generate
      genvar stage;

      if (REGISTER == 0) begin : no_reg
         assign data_out = data_in;
      end else begin : regs
         logic [WIDTH-1:0] sr_out [(REGISTER > 0 ? REGISTER-1 : 0):0];

         assign data_out = sr_out[REGISTER-1];

         for (stage = 0; stage < REGISTER; stage = stage + 1)
         begin : stage_gen
            always_ff @(posedge clk or negedge reset_n) begin
               if (~reset_n) begin
                  sr_out[stage] <= '0;
               end else begin
                  sr_out[stage] <= (stage == 0) ? data_in : sr_out[stage-1];
               end
            end
         end
      end
   endgenerate
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "IurukvpYH/8+/WDspakoTaXH+Q6agJWvYHckqHJ+D/ViOnCNkf7YhzAy23h5CurtnybgQY7DqA2HeIRNB1Pcqq30nATi5sAc8uMyjWLhTrbgXDo0HhuhgiSHRiWu7LqEQntqg6ZiiMXZv8tjWpBIjqIIzvyRLUApEX0egjZ/iHmZDDUpd8mzvwWVi7yymC2VK+oZdaYBDw6TVLZKla3gx8pwuCHKIb6xmukyXRHXqOiHZrlA8O7c1ygS63NeiE//PcItFpAEGQw22EAYUtIn5MS43+hy93BUNp/koJDzKXqiFwV7zFtxC9oXIGvtwJlJ7OnlAgPBEVwPIl6hQZyzjQwGFQQeVHxMvK/bTgbq3olxA8sWRUX70nmkMYEikPqYsUrK5Ut9neq6mCzwZjXTN0ZPhEJ8VNlX5b5sz8eYXp1tQPp8y9UVuIad8tMjJJ8CiE3tyduRkIw6DgMaItlxUtx+ocMj6vK4NEAhQFMaylEMPAt+x3oySfmB0zf+xOljQPkxWLj32qWzKzHL894XCbggOezZR7+gNDw1GRCuObCuUDsPKQvotTNBG+wkLVNio+pC0ie13225aPs4vCdCGkg+U0gJG4yhv7RgI66+EhxKVAKIh49uDB9rOuEg8SQm87koYCEM2Zr2ruHu/i8cFVTCRbHh7RYX+M+gprTTSfn4qgNA4SDFYaR9KrQ9CD5vGWWFPKj+/DMKI+tOjqUS4eeka28BQyqqmGM49q/A9HNd9z4Ud74R2+EHatVlMSuY59BbP5uBAvIXqjK2wfN/sJE8aZsydQV7nVSGRDB4yxxMsm57iJ7yBmLpqk71ZqkaMzuns6NlN/WGYP/5jWUl0iP7zJ+gkpiYrrUFH+9zKBgQaHFsZV9nmXTs+Mzek6xSDzMUOjOOp6A/GN8xzB/k0Rnk9WuVFXQrum0IAnhneCw8W7gQaFTTap3lrpGxfnVzcKZuhBGDB4AzrpcejKU7MlAzhcTgjFMKdmbEOqIQWJ1zM7CabQFnMPOQPVQySUwI"
`endif