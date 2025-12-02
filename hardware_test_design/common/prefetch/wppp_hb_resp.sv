module wppp_hb_resp
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // read response channel
    input logic [11:0]          rid,    // no use
    input logic [511:0]         rdata,  
    input logic [1:0]           rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic                 rlast,  // no use
    input logic                 ruser,  // no use
    input logic                 rvalid,
    output logic                rready,

    // other signals
    output logic read_lut,
    output logic [9:0] curr_rid,
    input logic  lut_valid,
    input logic [63:0] push_page_addr_r,
    output wppprefetch_rw_pipe_t hb_resp_out
);

// pipeline implementation

/* internal */
// logic [511:0] rdata_reg; // for the next stage
// wppprefetch_rw_state_t rd_state, next_rd_state;
// logic [1:0] rd_wait_cnt, next_rd_wait_cnt;
logic stage_out_valid;
wppprefetch_rw_pipe_t stage_1, stage_2; // stage 1: intermediate stage, stage 2: output stage

always_comb begin
    rready = 1'b1;
    curr_rid = '0;
    read_lut = 1'b0;
    stage_out_valid = 1'b0; // this is read combinationally
    if (rvalid & rready) begin
        read_lut = 1'b1; // insert this for 1 cycle for LUT to update
        curr_rid = rid[9:0]; // insert this for 1 cycle for BRAM to read
        stage_out_valid = lut_valid; // depending on the valid array
    end
end

always_comb begin
	hb_resp_out = stage_2;
	hb_resp_out.push_addr = push_page_addr_r;
end

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        stage_1 <= '0;
//        hb_resp_out <= '0;
		  stage_2 <= '0;
    end
    else begin
        stage_1.push_valid <= stage_out_valid; // latch the valid
        stage_1.push_id <= {2'b0, curr_rid}; // zero extend to 12 bit
        stage_1.push_data <= rdata; // latch the data
		  
		  stage_2.push_valid <= stage_1.push_valid;
		  stage_2.push_id <= stage_1.push_id;
		  stage_2.push_data <= stage_1.push_data;
		  
//        hb_resp_out.push_valid <= stage_1.push_valid;
//        hb_resp_out.push_id <= stage_1.push_id;
//        hb_resp_out.push_data <= stage_1.push_data;
//        hb_resp_out.push_addr <= push_page_addr_r; // pass through from BRAM
    end
end
endmodule

/* stage out */
// always_comb begin
//     hb_resp_out = stage_2;
// end
/* state update */
// always_comb begin
//     next_rd_state = rd_state;
//     next_rd_wait_cnt = rd_wait_cnt;
//     stage_out_valid = 1'b0;
//     unique case(rd_state)
//         HB_READ_DATA: begin
//             if (rvalid & rready) begin
//                 next_rd_state = LUT_WAIT;
//             end
//         end
//         LUT_WAIT: begin
//             if (rd_wait_cnt == 2'd2) begin 
//                 next_rd_state = HB_READ_DATA;
//                 stage_out_valid = lut_valid; // depending on the valid array
//                 next_rd_wait_cnt = 2'd0;
//             end
//             else begin
//                 next_rd_wait_cnt = rd_wait_cnt + 2'd1;
//             end
//         end 
//         default:;
//     endcase 
// end

/* state signal */
// always_comb begin
//     rready = 1'b1;
//     read_lut = 1'b0;
//    unique case(rd_state)
//       LUT_WAIT: begin // during look up, cannot take another address
//            rready = 1'b0;
//            if (rd_wait_cnt == 2'd2) begin
//                read_lut = 1'b1;
//            end
//        end
//        default:;
//    endcase
// end

/* 
    cycle 0 | cycle 1  | cycle 2 
    index   | index data | data out
    so two stage pipeline
*/
