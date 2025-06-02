/*
Module: hot_addr_pusher
Version: 0.0
Last Modified: July 18, 2024
Description: TODO
Workflow: 
    TODO
*/

// HAPB = Hot Address Pushing Buffer

module hot_addr_push
#(
  // common parameter
  parameter ADDR_SIZE = 33,
  parameter HAPB_SIZE = 64 * 1024      // 64kB
)
(

    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // host pAddr input (Based on HW/SW sync buff)
    input logic [63:0]                  hapb_head,    // == host_pAddr, initial address assigned/last address read by software
    input logic [63:0]                  mig_done_cnt,    // mig_done_cnt = count of valid addresses in hapb
    input logic                         atleast_one_valid_src,
    output logic [63:0]                 hapb_valid_count,    // hapb_valid_count * 512 = count of valid addresses in hapb
    // input logic [63:0]                  src_addr_valid_cnt,

    // hot page tracker interface
    input logic                         page_mig_addr_en,
    input logic [ADDR_SIZE-1:0]         page_mig_addr,
    output logic                        page_mig_addr_ready,

    input logic [63:0]                  cxl_start_pa, // byte level address, start_pfn << 12
    input logic [63:0]                  cxl_addr_offset,
    input logic [32:0]                  csr_addr_ub,
    input logic [32:0]                  csr_addr_lb,


    input logic [5:0]                   csr_awuser,

    // write address channel
    output logic [11:0]                 hapb_awid,
    output logic [63:0]                 hapb_awaddr, 
    output logic [5:0]                  hapb_awuser,
    output logic                        hapb_awvalid,
    input                               hapb_awready,

    // write data channel
    output logic [511:0]                hapb_wdata,
    output logic [(512/8)-1:0]          hapb_wstrb,
    output logic                        hapb_wlast,
    output logic                        hapb_wvalid,
    input                               hapb_wready,

    // write response channel
    input [11:0]                        hapb_bid,
    input [1:0]                         hapb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                         hapb_buser,  // must be tied to 4'b0000
    input                               hapb_bvalid,
    output logic                        hapb_bready
);




logic w_handshake;
logic aw_handshake;

logic [63:0]                                    hapb_pAddr_base;
logic                                           hapb_pAddr_ready;
logic [$clog2(HAPB_SIZE / (512/8)) - 1:0]       hapb_pAddr_offset; // log_2 ( HAPB_SIZE / (512 {bits/axi} / 8 {bits/bytes}) )

localparam HAPB_LOCAL_BUFF_SIZE = 12800;       // 400 addresses * 32 bits each == 16 addresses per transation * 25 addresses from m5 setup

logic [HAPB_LOCAL_BUFF_SIZE-1:0]                hot_addr_pg_data;
logic [$clog2(HAPB_LOCAL_BUFF_SIZE/(ADDR_SIZE-1)) - 1:0]         hot_addr_pg_ptr;       // clog2(400) == 9 
logic                                           hot_addr_pg_valid;
logic                                           hot_addr_pg_ready;

logic [63:0]                  old_mig_done_cnt;

// ================ hardware address conversion

logic                     h_pfn_en;
logic                     h_pfn_en_r;
logic                     h_pfn_valid_pfn_guarded;
logic[31:0]               h_pfn_addr_i;
logic[31:0]               h_pfn_addr_r;
logic[63:0]               h_pfn_addr_cvtr_b4_module;
logic[63:0]               h_pfn_addr_cvtr;


logic [ADDR_SIZE-1:0]         page_mig_addr_r;
logic                         page_mig_addr_en_r;

assign h_pfn_valid_pfn_guarded = (page_mig_addr_r != '1);
// PFN to byte address
// 28 + 12 = 40
assign h_pfn_addr_cvtr_b4_module = ({24'h0, page_mig_addr_r, 12'h0} + cxl_addr_offset); // adding current address by offset, circular map to 16GB
assign h_pfn_addr_cvtr = {31'h0, h_pfn_addr_cvtr_b4_module[33:0]}; // modulo by 16GB = [33:0]

assign h_pfn_en = page_mig_addr_en_r & h_pfn_valid_pfn_guarded;
assign h_pfn_addr_i = h_pfn_addr_cvtr[43:12] + cxl_start_pa[63:12]; // taking PFN from byte address

// ================ hardware address conversion (end)

enum logic [4:0] {
    STATE_RESET,
    STATE_WR_SUB,
    STATE_WR_SUB_RESP
} state, next_state;

/*---------------------------------
functions
-----------------------------------*/
function void set_default();
    hapb_awvalid = 1'b0;
    hapb_wvalid = 1'b0;
    hapb_bready = 1'b0;
    hapb_wdata = hot_addr_pg_ptr == '0 ? hot_addr_pg_data[((HAPB_LOCAL_BUFF_SIZE/(ADDR_SIZE-1)) - 16) * 32 +: 512] : hot_addr_pg_data[(hot_addr_pg_ptr[$clog2(HAPB_LOCAL_BUFF_SIZE/(ADDR_SIZE-1)) - 1 : 4] - 1'b1) * 512 +: 512];
    hapb_awaddr = 'b0;
    hapb_awid = 'b0;
    hapb_awuser = 'b0; 
    hapb_wlast = 1'b0;
    hapb_wstrb = 64'h0;

    page_mig_addr_ready = '0;
endfunction

function void reset_ff();
    state <= STATE_RESET;

    w_handshake <= 1'b0;
    aw_handshake <= 1'b0;

    hapb_pAddr_base <= '0;
    hapb_pAddr_offset <= '0;
    hapb_valid_count <= '0;

    hot_addr_pg_data <= '0;
    hot_addr_pg_ptr <= '0;
    hot_addr_pg_valid <= '0;

    page_mig_addr_r <= '0;
    page_mig_addr_en_r <= '0;
    h_pfn_addr_r <= '0;
endfunction

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n || hapb_head == '0) begin
        reset_ff();
        old_mig_done_cnt <= '1;            // FFFF..FFFF = To match case at transaction 0
    end

    else begin
        state <= next_state;
        unique case(state) 

            STATE_WR_SUB: begin
                if (hapb_awvalid & hapb_awready) begin
                    aw_handshake <= 1'b1;
                end
                if (hapb_wvalid & hapb_wready) begin  // nc-p-write can start, otherwise wait 
                    w_handshake <= 1'b1;
                    // the next installment for HAPB has already been sent, invalidate for next request
                    hot_addr_pg_valid <= '0;
                    hapb_pAddr_offset <= hapb_pAddr_offset + 'd1;
                end
            end

            STATE_WR_SUB_RESP: begin
                if (hapb_bvalid & hapb_bready) begin  // nc-p-write done
                    aw_handshake <= 1'b0;
                    w_handshake <= 1'b0;

                    old_mig_done_cnt <= mig_done_cnt;
                    hapb_valid_count <= hapb_valid_count + 'd1;
                end
            end
            default ;
        endcase

        // handle update for hapb_pAddr_base (should only happen once)
        if (hapb_pAddr_base == '0 & hapb_head != '0) begin
            hapb_pAddr_base <= hapb_head;
        end

        // load m5 addresses into a buffer
        if (page_mig_addr_ready & h_pfn_en_r & (h_pfn_addr_r != '0)) begin
            hot_addr_pg_data[hot_addr_pg_ptr*32 +: 32] <= h_pfn_addr_r[ADDR_SIZE-2:0];
            hot_addr_pg_ptr <= hot_addr_pg_ptr + 1'b1;
            if ((hot_addr_pg_ptr + 1'b1) == HAPB_LOCAL_BUFF_SIZE/(ADDR_SIZE-1)) begin
                hot_addr_pg_ptr <= '0;      // improper rounding?
            end
            hot_addr_pg_valid <= '1;
        end

        page_mig_addr_en_r <= page_mig_addr_en;
        page_mig_addr_r <= page_mig_addr;
        h_pfn_addr_r <= h_pfn_addr_i;
        h_pfn_en_r <= h_pfn_en;
    end
end

// Start requesting m5 addresses when buffer is valid and full 
assign hot_addr_pg_ready = hot_addr_pg_valid & (hot_addr_pg_ptr[3:0] == '0);

assign hapb_pAddr_ready = (hapb_pAddr_base != '0) && ((hapb_valid_count == '0) || ((hapb_pAddr_base + (hapb_pAddr_offset*512)/8) != hapb_head)) && ((mig_done_cnt != old_mig_done_cnt) || (~atleast_one_valid_src));

/*---------------------------------
FSM
-----------------------------------*/

always_comb begin
    next_state = state;
    unique case(state)
        STATE_RESET: begin
            // Can move to write requests if this segment of addresses is ready/full, hapb_pAddr_ready valid
            if (hot_addr_pg_ready & hapb_pAddr_ready) begin
                next_state = STATE_WR_SUB;
            end else begin
                next_state = STATE_RESET;
            end
        end
        STATE_WR_SUB: begin
            if (hapb_awready & hapb_wready) begin
                next_state = STATE_WR_SUB_RESP;
            end
            else if (hapb_wvalid == 1'b0) begin
                if (hapb_awready) begin
                    next_state = STATE_WR_SUB_RESP;
                end
                else begin
                    next_state = STATE_WR_SUB;
                end
            end
            else if (hapb_awvalid == 1'b0) begin
                if (hapb_wready) begin
                    next_state = STATE_WR_SUB_RESP;
                end
                else begin
                    next_state = STATE_WR_SUB;
                end
            end
            else begin
                next_state = STATE_WR_SUB;
            end
        end

        STATE_WR_SUB_RESP: begin
            if (hapb_bvalid & hapb_bready) begin
                next_state = STATE_RESET; 
            end
            else begin
                next_state = STATE_WR_SUB_RESP;
            end
        end

        // default: begin
        //     next_state = STATE_RESET;
        // end
    endcase
end

always_comb begin
    set_default();
    hapb_bready = 1'b1;
    unique case(state)
        STATE_RESET: begin
            page_mig_addr_ready = ~hot_addr_pg_ready;
        end
        STATE_WR_SUB: begin
            if (aw_handshake == 1'b0) begin
                hapb_awvalid = 1'b1;
            end
            else begin
                hapb_awvalid = 1'b0;
            end
            hapb_awid = 12'd0;
            hapb_awuser = csr_awuser; 
            hapb_awaddr = hapb_pAddr_base + (hapb_pAddr_offset*512)/8;

            if (w_handshake == 1'b0) begin
                hapb_wvalid = 1'b1;
            end
            else begin
                hapb_wvalid = 1'b0;
            end
            hapb_wlast = 1'b1;
            hapb_wstrb = 64'hffffffffffffffff;
        end

        STATE_WR_SUB_RESP: begin
        end

        default: begin
        end
    endcase
end

endmodule
