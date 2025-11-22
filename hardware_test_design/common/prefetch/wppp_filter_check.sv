// filter check stage
module wppp_filter_check
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    output logic [63:0] faraddr,
    output logic        farvalid,
    input  logic        frvalid,
    input  logic        frdata,
    input  wppprefetch_rw_pipe_t hb2filter_pipe,
    output wppprefetch_rw_pipe_t filter_out
);

logic filter_out_valid;
wppprefetch_rw_state_t filter_state, next_filter_state;
wppprefetch_rw_pipe_t pipe_in_reg;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        filter_state <= IDLE;
        pipe_in_reg <= '0;
    end
    else begin
        filter_state <= next_filter_state;
        unique case(filter_state)
            IDLE: begin
                if (hb2filter_pipe.push_valid) begin // if pipe from previous stage is valid
                    pipe_in_reg <= hb2filter_pipe;
                end
            end
            default:;
        endcase
    end
end

always_comb begin
    filter_out = '0;
    if (filter_out_valid) begin
        filter_out.push_valid = 1'b1;
        filter_out.push_id = pipe_in_reg.push_id;
        filter_out.push_addr = pipe_in_reg.push_addr;
        filter_out.push_data = pipe_in_reg.push_data;
    end
end

/* state transition */
always_comb begin
    next_filter_state = filter_state;
    filter_out_valid = 1'b0;
    unique case(filter_state)
        IDLE: begin
            if (hb2filter_pipe.push_valid) begin
                next_filter_state = F_READ_ADDR;
            end
        end
        F_READ_ADDR: begin
            if (farvalid & frvalid) begin // TODO: need to modify this later to fit the filter delay
                next_filter_state = F_READ_DATA;
            end
        end
        F_READ_DATA: begin
            if (frdata) begin
                filter_out_valid = 1'b1;
                next_filter_state = IDLE;
            end
        end
        default:;
    endcase
end

always_comb begin
    farvalid = '0;
    faraddr = '0;
    unique case(filter_state)
        F_READ_ADDR: begin
            farvalid = 1;
            faraddr = pipe_in_reg.push_addr;
        end
        default:;
    endcase
end

endmodule
