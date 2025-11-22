/*
Module: prefetch_read_write
Version: 0.0
Last Modified: March 5, 2024
Description: Modified based on packet generator 0.0.1
Workflow: 
    1. set prefetch_page_addr to cxl mem address
    2. trigger start_prefetch, nc-read + nc-p-write
    3. wait for end_prefetch, finish
*/

module wppprefetch_rw
import wppprefetch_pkg::*;
import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
(

    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,
    
    // read address channel
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

    // read response channel
    input [11:0]                      rid,    // no use
    input [511:0]                     rdata,  
    input [1:0]                       rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                             rlast,  // no use
    input                             ruser,  // no use
    input                             rvalid,
    output logic                      rready,

    // write address channel
    output logic [11:0]               awid,
    output logic [63:0]               awaddr,   // output ncp write address?
    output logic [9:0]                awlen,    // must tie to 10'd0
    output logic [2:0]                awsize,   // must tie to 3'b110 (64B/T)
    output logic [1:0]                awburst,  // must tie to 2'b00
    output logic [2:0]                awprot,   // must tie to 3'b000
    output logic [3:0]                awqos,    // must tie to 4'b0000
    output logic [6:0]                awuser,
    output logic                      awvalid,
    output logic [3:0]                awcache,  // must tie to 4'b0000
    output logic [1:0]                awlock,   // must tie to 2'b00
    output logic [3:0]                awregion, // must tie to 4'b0000
    output logic [5:0]                awatop,   // must tie to 6'b000000
    input                             awready,

    // write data channel
    output logic [511:0]              wdata,
    output logic [(512/8)-1:0]        wstrb,
    output logic                      wlast,
    output logic                      wuser,  // must tie to 1'b0
    output logic                      wvalid,
    input                             wready,

    // write response channel
    input [11:0]                      bid,    // no use
    input [1:0]                       bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                       buser,  // must tie to 4'b0000
    input                             bvalid,
    output logic                      bready,

    // control logic 
    // set physical address of target cache line to prefetch_page_addr
    input logic [63:0] prefetch_page_addr, // byte level address, XXX, this may change during the states 
    input logic start_prefetch,
    // output logic end_prefetch,
    // output logic [511:0] prefetch_page_data,

    input logic [5:0] csr_aruser,
    input logic [6:0] csr_awuser,

    input logic clst_d1_tvalid,
    input logic [71:0] clst_d1_tdata,

    // for new ncp method
    output wppprefetch_rw_state_t prefetch_rw_curr_state, // for AFU specifically 
    output logic [63:0] curr_working_address,   // address that prefetching is working on
    
    input logic addr_seen,  // signal provided by AFU, 1 = prefetch can issue ncp, 0 = prefetch cannot issue ncp
    input logic abort_op,   // signal from AFU to abort current prefetch operation

    // statistics output
    output logic [63:0] prefetch_abt_cnt, // for prefetching stat, abort count
    output logic [63:0] prefetch_ok_cnt,  // for prefetching stat, success count

    // get next addr
    output logic addr_issued,
    output logic get_next_addr,

    //filter read req channel
    output logic [63:0]                faraddr,
    output logic                       farvalid,
    //filter read resp channel
    input  logic                        frvalid,
    input  logic                        frdata
);

assign  awlen        = '0   ;
assign  awsize       = 3'b110   ; // must tie to 3'b110
assign  awburst      = '0   ;
assign  awprot       = '0   ;
assign  awqos        = '0   ;

assign  awcache      = '0   ;
assign  awlock       = '0   ;
assign  awregion     = '0   ;
assign  awatop       = '0   ; 

assign  wuser        = '0   ;

assign  arlen        = '0   ;
assign  arsize       = 3'b110   ; // must tie to 3'b110
assign  arburst      = '0   ;
assign  arprot       = '0   ;
assign  arqos        = '0   ;

assign  arcache      = '0   ;
assign  arlock       = '0   ;
assign  arregion     = '0   ;

logic [511:0] hb_rdata_reg;
logic [63:0] prefetch_page_addr_r; // latched prefetch_page_addr
logic [31:0] abort_cnt_reg, success_cnt_reg, new_abt_cnt, new_success_cnt, prefetch_cnt, ncp_timeout_cnt_r, ncp_timeout_cnt_n;

(* preserve_for_debug *) wppprefetch_rw_state_t  state, next_state, prev_state;

assign prefetch_page_data = hb_rdata_reg;
assign prefetch_rw_curr_state = state;
assign curr_working_address = prefetch_page_addr_r; // a simple wire
assign prefetch_abt_cnt = {ncp_timeout_cnt_r, abort_cnt_reg};
assign prefetch_ok_cnt = {prefetch_cnt, success_cnt_reg};


(* preserve_for_debug *) logic[11:0] rid_debug;
assign rid_debug = rid;

(* preserve_for_debug *) logic clst_hit;
assign clst_hit = clst_d1_tvalid & 
                    (prefetch_page_addr_r[51:0] == clst_d1_tdata[51:0]);

// (* preserve_for_debug *) logic rvalid_debug;

// assign rvalid_debug = rvalid && 
//                         (state == NCP_WRITE || state == NCP_WRITE_DATA || state == NCP_ABORT);

assign get_next_addr = (next_state == IDLE) && (state != IDLE);

/*---------------------------------
functions
-----------------------------------*/
function void set_default();
    awvalid = 1'b0;
    wvalid = 1'b0;
    bready = 1'b1;
    arvalid = 1'b0;
    rready = 1'b1;
    arid = 'b0;
    araddr = 'b0;
    wdata = hb_rdata_reg;  
    aruser = 'b0;
    awaddr = 'b0;
    awid = 'b0;
    awuser = 'b0; 
    wlast = 1'b0;
    wstrb = 64'h0;

    faraddr = '0;
    farvalid = '0; 
endfunction

function void host_bias_read();
    arid = 12'h3;
    aruser = 6'b100000; // target HDM, Host-bias NCR
    aruser = csr_aruser;
    arvalid = 1'b1;
    araddr = prefetch_page_addr_r;
endfunction

function void filter_read();
    farvalid = 1'b1;
    faraddr  = prefetch_page_addr_r;
endfunction

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        state <= IDLE;
        hb_rdata_reg <= '0;
        // end_prefetch <= 1'b0;

        prefetch_page_addr_r <= '0;        
        prefetch_cnt <= '0;
        abort_cnt_reg <= '0;
        success_cnt_reg <= '0;

        prev_state <= IDLE;
    end
    else begin
        abort_cnt_reg <= new_abt_cnt;
        success_cnt_reg <= new_success_cnt;

        state <= next_state;

        if (next_state != state) begin
            prev_state <= state;
        end
        unique case(state)
            IDLE: begin
                if (start_prefetch) begin
                    prefetch_cnt <= prefetch_cnt + 64'd1;
                    prefetch_page_addr_r <= prefetch_page_addr;
                end
            end
            HB_READ_DATA: begin
                if (rvalid & rready) begin
                    hb_rdata_reg <= rdata;
                end
            end
            default:;
        endcase
    end
end

// FSM state transition
always_comb begin
    next_state = state;
    new_abt_cnt = abort_cnt_reg;
    new_success_cnt = success_cnt_reg;
    addr_issued = 1'b0;
    unique case(state)
        IDLE: begin
            if (start_prefetch & ~abort_op) begin
                addr_issued = 1'b1;
                next_state = HB_READ_ADDR;
            end
        end
        HB_READ_ADDR: begin
            if(abort_op =='0) begin
                if (arvalid & arready) begin
                    next_state = HB_READ_DATA;
                end
            end else begin
                if (arready) begin 
                    next_state = HB_ABORT;
                end else begin
                    next_state = ABORT;
                end 
            end
        end
        HB_READ_DATA: begin
            if (abort_op == '0) begin
                if (rvalid & rready) begin
                    if (addr_seen) begin 
                        next_state = F_READ_ADDR;
                    end else begin
                        next_state = ABORT;
                    end
                end
            end
            else begin
                if (rvalid & rready) begin
                    next_state = ABORT;
                end else begin
                    next_state = HB_ABORT;
                end
            end
        end
        F_READ_ADDR: begin
            if (abort_op == '1) begin 
                next_state = F_ABORT;
            end else begin
                next_state = F_READ_DATA;
            end
        end
        F_READ_DATA: begin
            if (abort_op == '1) begin
                if (frvalid) begin
                    next_state = ABORT;
                end else begin
                    next_state = F_ABORT;
                end
            end else if (frvalid) begin
                next_state = (frdata) ? NCP_WRITE : ABORT;
            end 
        end
        NCP_WRITE: begin
            if (awready & awvalid) begin
                next_state = NCP_WRITE_DATA;
            end else begin
                next_state = NCP_WRITE;
            end
        end
        NCP_WRITE_DATA: begin
            if (wready & wvalid) begin
                new_success_cnt = success_cnt_reg + 64'd1;
                next_state = IDLE;
            end else begin
                next_state = NCP_WRITE_DATA;
            end
        end
        HB_ABORT: begin
            if (rvalid & rready) begin
                next_state = ABORT;
            end
        end
        F_ABORT: begin
            if (frvalid) begin
                next_state = ABORT;
            end
        end
        ABORT: begin
            new_abt_cnt = abort_cnt_reg + 64'd1;
            next_state = IDLE;
        end
        default: ;
    endcase
end

// FSM output signals
always_comb begin
    set_default();
    unique case(state)
        HB_READ_ADDR: begin
            host_bias_read();
        end
        HB_READ_DATA: begin
            rready = 1'b1;
        end
        F_READ_ADDR: begin
            filter_read();
        end
        NCP_WRITE: begin
            awid = 12'h2;
            awuser = 7'b0100010; // NCP to host
            awvalid = '1;
            awaddr = prefetch_page_addr_r;
        end
        NCP_WRITE_DATA: begin
            wvalid = '1;
            wdata = hb_rdata_reg;
            wstrb = 64'hFFFFFFFFFFFFFFFF;
            wlast = 1'b1;
        end
        HB_ABORT: begin
            rready = 1'b1;
        end
        default: set_default();
    endcase
end

endmodule
