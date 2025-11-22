module wppp_hb_req
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,
    
    // req only need ar information, read address channel
    output logic [11:0]               arid,
    output logic [63:0]               araddr,   // output nc read address
    output logic [9:0]                arlen,    // must tie to 10'd0
    output logic [2:0]                arsize,   // must tie to 3'b110
    output logic [1:0]                arburst,  // must tie to 2'b00
    output logic [2:0]                arprot,   // must tie to 3'b000
    output logic [3:0]                arqos,    // must tie to 4'b0000
    output logic [5:0]                aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cachebale owned
    output logic                      arvalid,
    output logic [3:0]                arcache,  // must tie to 4'b0000
    output logic [1:0]                arlock,   // must tie to 2'b00
    output logic [3:0]                arregion, // must tie to 4'b0000
    input                             arready,

    // other signals
    input logic start_prefetch,
    input [63:0] prefetch_page_addr,
    input logic lut_in_use,
    input logic abort_op,
    output logic addr_issued,
    output logic get_next_addr,
    output logic write_lut // writing the LUT entry
);
/* const */
assign  arlen        = '0   ;
assign  arsize       = 3'b110   ; // must tie to 3'b110
assign  arburst      = '0   ;
assign  arprot       = '0   ;
assign  arqos        = '0   ;
assign  arcache      = '0   ;
assign  arlock       = '0   ;
assign  arregion     = '0   ;

/* internal */
logic [9:0] curr_arid, next_arid; // 10 bit arid counter, max 1024 requests
logic [1:0] wait_cnt, next_wait_cnt;
logic [63:0] prefetch_page_addr_r;
wppprefetch_rw_state_t ar_state, next_ar_state;
(* preserve_for_debug *) logic arid_cnt_overflow;
assign get_next_addr = (next_ar_state == IDLE) && (ar_state != IDLE);
//assign curr_araddr = prefetch_page_addr_r;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        curr_arid <= '0; /* arid id, up counter */
        wait_cnt <= 'd0;
        ar_state <= IDLE;
        prefetch_page_addr_r <= '0;
    end
    else begin
        ar_state <= next_ar_state;
        curr_arid <= next_arid;
        wait_cnt <= next_wait_cnt;
        unique case(ar_state)
            IDLE: begin
                if (start_prefetch & ~abort_op & ~lut_in_use) begin
                    prefetch_page_addr_r <= prefetch_page_addr;
                end
            end
            default:;
        endcase
    end
end

/* state update */
always_comb begin
    next_ar_state = ar_state;
    next_wait_cnt = wait_cnt;
    next_arid = curr_arid;
    addr_issued = 1'b0;
    arid_cnt_overflow = 1'b0; // indicate arid overflow
    unique case(ar_state)
        IDLE: begin
            if (start_prefetch & ~abort_op & ~lut_in_use) begin // start prefetching if not abort and LUT entry not in use
                addr_issued = 1'b1;
                next_ar_state = HB_READ_ADDR;
            end
        end
        HB_READ_ADDR: begin
            if (arready & arvalid) begin
                next_ar_state = LUT_WAIT;
            end
        end
        LUT_WAIT: begin
            // update to this because the BRAM is pipelined, we need to wait one cycle
            if (curr_arid == 10'h3FF) begin // arid overflow
                arid_cnt_overflow = 1'b1;
            end
            next_arid = curr_arid + 10'd1;
            next_ar_state = IDLE;

            // wait logic removed for simplification
            // if (wait_cnt == 2'd2) begin
            //     next_ar_state = IDLE;
            //     next_wait_cnt = 2'd0;

            //     if (curr_arid == 12'hFFF) begin // arid overflow
            //         arid_cnt_overflow = 1'b1;
            //     end
            //     next_arid = curr_arid + 12'd1;
            // end
            // else begin
            //     next_wait_cnt = wait_cnt + 2'd1;
            // end
        end
        default:;
    endcase
end
/* state output */
always_comb begin
    arvalid     = 1'b0;
    arid        = {2'b0, curr_arid}; // zero extend to 12 bit
    araddr      = '0;
    aruser      = '0;
    write_lut   = 1'b0;
    unique case(ar_state)
        HB_READ_ADDR: begin
            arvalid  = '1;
            // arid     = curr_arid;
            araddr   = prefetch_page_addr_r;
            aruser   = 6'b100000;
        end
        LUT_WAIT: begin
            // arid = curr_arid;
            araddr = prefetch_page_addr_r;
            write_lut = 1'b1;
        end
        default:;
    endcase
end
endmodule
