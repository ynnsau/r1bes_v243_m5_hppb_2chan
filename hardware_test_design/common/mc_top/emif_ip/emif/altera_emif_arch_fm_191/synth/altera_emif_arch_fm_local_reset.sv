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
//  Reset request sequencing state machine.
//
///////////////////////////////////////////////////////////////////////////////
module altera_emif_arch_fm_local_reset # (
   parameter PHY_CONFIG_ENUM    = "",
   parameter IS_HPS             = 0
) (
   input  logic   afi_clk,
   input  logic   afi_reset_n,
   input  logic   emif_usr_clk,
   input  logic   emif_usr_reset_n,

   input  logic   local_reset_req_int,
   output logic   core2seq_reset_req,

   output logic   local_reset_done,
   input  logic   seq2core_reset_done
);
   timeunit 1ns;
   timeprecision 1ps;

   typedef enum {
      WAIT_RESET_DONE,
      WAIT_USER_RESET_REQ_1ST_DEASSERT,
      WAIT_USER_RESET_REQ_ASSERT,
      WAIT_USER_RESET_REQ_2ND_DEASSERT,
      ASSERT_CORE2SEQ_RESET_REQ
   } state_t;

   generate
      if (IS_HPS) begin: hps
         assign core2seq_reset_req = 1'b0;
         assign local_reset_done   = 1'b0;
      end else begin : non_hps
         logic clk;
         logic reset_n;

         if (PHY_CONFIG_ENUM == "CONFIG_PHY_AND_HARD_CTRL") begin : hmc
            assign clk = emif_usr_clk;
            assign reset_n = emif_usr_reset_n;
         end else begin : non_hmc
            assign clk = afi_clk;
            assign reset_n = afi_reset_n;
         end

         ////////////////////////////////////////////////////////////////////
         // State machine
         ////////////////////////////////////////////////////////////////////
         state_t state                 /* synthesis ignore_power_up */;
         logic   core2seq_reset_req_r  /* synthesis ignore_power_up dont_merge syn_noprune syn_preserve = 1 */;
         logic   local_reset_done_r    /* synthesis ignore_power_up dont_merge syn_noprune syn_preserve = 1 */;

         always_ff @(posedge clk, negedge reset_n)
         begin
            if (!reset_n) begin
               state                <= WAIT_RESET_DONE;
               core2seq_reset_req_r <= 1'b0;
               local_reset_done_r   <= 1'b0;
            end else begin
               case (state)
                  WAIT_RESET_DONE:
                  begin
                     // Wait until sequencer signals it's ready to accept a reset request.
                     if (seq2core_reset_done) begin
                        if (local_reset_req_int == 1'b1) begin
                           state                <= WAIT_USER_RESET_REQ_1ST_DEASSERT;
                           core2seq_reset_req_r <= 1'b0;
                           local_reset_done_r   <= 1'b1;
                        end else begin
                           state                <= WAIT_USER_RESET_REQ_ASSERT;
                           core2seq_reset_req_r <= 1'b0;
                           local_reset_done_r   <= 1'b1;
                        end
                     end
                     else
                     begin
                        state                <= WAIT_RESET_DONE;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b0;
                     end
                  end

                  WAIT_USER_RESET_REQ_1ST_DEASSERT:
                  begin
                     if (~local_reset_req_int) begin
                        state                <= WAIT_USER_RESET_REQ_ASSERT;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b1;
                     end else begin
                        state                <= WAIT_USER_RESET_REQ_1ST_DEASSERT;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b1;
                     end
                  end

                  WAIT_USER_RESET_REQ_ASSERT:
                  begin
                     if (local_reset_req_int) begin
                        state                <= WAIT_USER_RESET_REQ_2ND_DEASSERT;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b1;
                     end else begin
                        state                <= WAIT_USER_RESET_REQ_ASSERT;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b1;
                     end

                  end

                  WAIT_USER_RESET_REQ_2ND_DEASSERT:
                  begin
                     if (~local_reset_req_int) begin
                        state                <= ASSERT_CORE2SEQ_RESET_REQ;
                        core2seq_reset_req_r <= 1'b1;
                        local_reset_done_r   <= 1'b0;
                     end else begin
                        state                <= WAIT_USER_RESET_REQ_2ND_DEASSERT;
                        core2seq_reset_req_r <= 1'b0;
                        local_reset_done_r   <= 1'b1;
                     end
                  end

                  ASSERT_CORE2SEQ_RESET_REQ:
                  begin
                     state                   <= ASSERT_CORE2SEQ_RESET_REQ;
                     core2seq_reset_req_r    <= 1'b1;
                     local_reset_done_r      <= 1'b0;
                  end
                  default:
                  begin
                     state                   <= WAIT_RESET_DONE;
                     core2seq_reset_req_r    <= 1'b0;
                     local_reset_done_r      <= 1'b0;
                  end
               endcase
            end
         end

         ////////////////////////////////////////////////////////////////////
         // Output generation
         ////////////////////////////////////////////////////////////////////
         assign core2seq_reset_req = core2seq_reset_req_r;

         // Instead of passing seq2core_reset_done directly to user, we have the ability
         // to acknowledge the reset request earlier, as soon as a local_reset_req pulse
         // is detected.
         assign local_reset_done = local_reset_done_r;
      end
   endgenerate
endmodule
`ifdef QUESTA_INTEL_OEM
`pragma questa_oem_00 "S21ufhxyHOixFKMiQucGFQxuc85AXjjh9ebHGNTiQxJHIE75pahmYrhDUnfcenC3iv6PgryhDAZYmSRMI3X3Ii6wCyY9ZXrpS7S4iZ9zHRtzvWWnLt0LVFloedB6S+BFjhK7cRMWcPqvzdRgK0yTUmjHuSlrpTq7XHwXsxX+jRHI31LP6jtPwGC266ZHPF7M3kZl6oL+ze9pdKayTsMR3/gtivRus1q2ZU32c1nDB+45mBaiScskfY6fZDmTWzgrSmaS3/QJaR5BisUOaNpqbqD2Kz+P87caNnkTKsCcpIfvzonBwlPNLeWHf9QP+HCcRZRnkvelhCUaAq0dNNjnoHFHK6i0ouZ5rTLyx2zOg3ic4XOnWSp28kUYCVohi2ax3vQWJpU6SxPIyLAiGriEjj8r1bqxc2slaGkI4qnRhxpbqGM89ylyDiNT/1v/94JNAKYFQBsn5055xAXsJbuj8eiZCktgYdwcUTiCXwuKnVUlyubFygm8N/o4q7rsoZFrpAjlFfulBhjR5qvCEAJbGXWBU9qoed9CbIfFh4NXwfFWJSRy79m3cvbyg8oxCHxli6LDN67q46GSWda5jV4MHL8EdFKwGwYFmrEj9VlwtqisOeoojfBpk1p3E2488leUc+1XNR6uhGN1GAHwBDYRAM60oezz08lmFL9W8tt0N86KudqHG9fWsmuvcKM7qb25wIFFOk+a0lYE70Z8g99kuFl+uHrzfSYGVJkgAH7cXW4ph+fbYuX+pPrp+9U4YUWCgAmrTC+MxEL5v4MtgDsoWzG2vDdj+oL/yG9W3tgcTFGIlEkCpRcicNiLVjHXQsctc0jA1s+6R5UINObghWYS5xfopcz/dBh7NbQ8LgpyLc07q+BYdKxB+PoeyusJ/FdiiLCBj3QBnFQgzkiQUFj6/Uf80hhY93GwbGt9N54ihnzyBAXrP+wZuRrnrIzixbyD30LChzaEm116x+deVYyc8M0nHnLKgTN0B1WffLnOXWJcTBFgAmRMujC2AX0L+CW1"
`endif