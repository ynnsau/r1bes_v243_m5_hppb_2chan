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

/* internal */
logic [511:0] rdata_reg; // for the next stage
logic [1:0] rd_wait_cnt, next_rd_wait_cnt;
logic stage_out_valid;
wppprefetch_rw_state_t rd_state, next_rd_state;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        rd_state <= HB_READ_DATA;
        rdata_reg <= '0;
        rd_wait_cnt <= 'd0;
        curr_rid <= '0;
    end
    else begin
        rd_state <= next_rd_state;
        rd_wait_cnt <= next_rd_wait_cnt;
        unique case(rd_state)
            HB_READ_DATA: begin
                curr_rid <= '0;
                rdata_reg <= '0; 
                if (rvalid & rready) begin
                    curr_rid <= rid[9:0];
                    rdata_reg <= rdata;
                end
            end
            default:;
        endcase
    end
end

/* stage out */
always_comb begin
    hb_resp_out = '0;
    if (stage_out_valid) begin
        hb_resp_out.push_valid = 1'b1;
        hb_resp_out.push_id = {2'b0, curr_rid}; // zero extend to 12 bit
        hb_resp_out.push_addr = push_page_addr_r;
        hb_resp_out.push_data = rdata_reg;
    end
end

/* state update */
always_comb begin
    next_rd_state = rd_state;
    next_rd_wait_cnt = rd_wait_cnt;
    stage_out_valid = 1'b0;
    unique case(rd_state)
        HB_READ_DATA: begin
            if (rvalid & rready) begin
                next_rd_state = LUT_WAIT;
            end
        end
        LUT_WAIT: begin
            if (rd_wait_cnt == 2'd2) begin 
                next_rd_state = HB_READ_DATA;
                stage_out_valid = lut_valid; // depending on the valid array
                next_rd_wait_cnt = 2'd0;
            end
            else begin
                next_rd_wait_cnt = rd_wait_cnt + 2'd1;
            end
        end 
        default:;
    endcase 
end

/* state signal */
always_comb begin
    rready = 1'b1;
    read_lut = 1'b0;
    unique case(rd_state)
        LUT_WAIT: begin // during look up, cannot take another address
            rready = 1'b0;
            if (rd_wait_cnt == 2'd2) begin
                read_lut = 1'b1;
            end
        end
        default:;
    endcase
end
endmodule
