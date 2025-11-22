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

module prefetch_read_write 
import prefetch_read_write_pkg::*;
import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
(

    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // control logic 
    // set physical address of target cache line to prefetch_page_addr
    input logic [63:0] prefetch_page_addr, // byte level address
    input logic start_prefetch,
    output logic end_prefetch,
    output logic [511:0] prefetch_page_data,
    input logic [63:0] cxl_start_pa, // the based address to start with? // CDC issue?
    input logic [63:0] cxl_addr_offset, // TODO: double-check this

    input logic [5:0] csr_aruser,
    input logic [6:0] csr_awuser,

    input logic clst_d1_tvalid,
    input logic [71:0] clst_d1_tdata,

    // for new ncp method
    output prefetch_rw_state_t prefetch_rw_curr_state, // for AFU specifically 
    output logic [63:0] curr_working_address, // address that prefetching is working on
    input logic allow_prefetch_continue, // signal provided by AFU to allow prefetching
    input logic prefetch_wait,           // signal provided by AFU, 1 = prefetch needs to wait for AFU, 0 = prefetch can continue
    
    // statistics output
    output logic [63:0] prefetch_abt_cnt, // for prefetching stat, abort count
    output logic [63:0] prefetch_ok_cnt,  // for prefetching stat, success count

    // input ed_mc_axi_if_pkg::t_to_mc_axi4 [ed_cxlip_top_pkg::MC_CHANNEL-1:0] axi4_if, // AXI4 interface to memory controller
    
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
    output logic                      bready
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

localparam resp_stall_count = 100;

logic start_prefetch_guarded;
logic [511:0] rdata_reg;
logic [63:0] prefetch_page_addr_r; // latched prefetch_page_addr
logic [63:0] cxl_start_pa_r, cxl_addr_offset_r;
logic start_prefetch_r; // latched start_prefetch signal
logic w_handshake;
logic aw_handshake;
logic [63:0] prefetch_cnt;
logic [63:0] abort_cnt_reg, success_cnt_reg, new_abt_cnt, new_success_cnt;   
logic [15:0] prefetch_resp_stall;

assign start_prefetch_guarded = start_prefetch & (prefetch_page_addr[33:6] != '1);

prefetch_rw_state_t  state, next_state;

assign prefetch_page_data = rdata_reg;
assign prefetch_rw_curr_state = state;
assign curr_working_address = prefetch_page_addr_r; // a simple wire
assign prefetch_abt_cnt = abort_cnt_reg;
assign prefetch_ok_cnt = success_cnt_reg;

(* preserve_for_debug *) logic clst_hit;
assign clst_hit = clst_d1_tvalid & 
                    (prefetch_page_addr_r[51:0] == clst_d1_tdata[51:0]);

/*---------------------------------
functions
-----------------------------------*/
function void set_default();
    awvalid = 1'b0;
    wvalid = 1'b0;
    bready = 1'b0;
    arvalid = 1'b0;
    rready = 1'b0;
    arid = 'b0;
    araddr = 'b0;
    wdata = rdata_reg;  
    aruser = 'b0;
    awaddr = 'b0;
    awid = 'b0;
    awuser = 'b0; 
    wlast = 1'b0;
    wstrb = 64'h0;
endfunction

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        state <= STATE_RESET;
        rdata_reg <= 512'b0;
        end_prefetch <= 1'b0;

        start_prefetch_r <= 1'b0;
        prefetch_page_addr_r <= 'b0;
        cxl_start_pa_r <= 'b0;
        cxl_addr_offset_r <= 'b0;

        w_handshake <= 1'b0;
        aw_handshake <= 1'b0;

        prefetch_cnt <= '0;
        abort_cnt_reg <= '0;
        success_cnt_reg <= '0;
//        prefetch_resp_stall <= resp_stall_count;
    end
    else begin
        prefetch_page_addr_r <= prefetch_page_addr;
        start_prefetch_r <= start_prefetch;
        abort_cnt_reg <= new_abt_cnt;
        success_cnt_reg <= new_success_cnt;

        state <= next_state;
        cxl_start_pa_r <= cxl_start_pa;
        cxl_addr_offset_r <= cxl_addr_offset;

        unique case(state) 
            STATE_RESET: begin
                if (start_prefetch_r) begin
                    prefetch_cnt <= prefetch_cnt + 64'd1;
                end
            end
//            STATE_RESET: begin
//                prefetch_resp_stall <= resp_stall_count; // reset stall count
//            end

            STATE_RD_DATA: begin
                if (rready & rvalid) begin
                    rdata_reg <= {prefetch_cnt, rdata[447:0]};
                    aw_handshake <= 1'b0;
                    w_handshake <= 1'b0;
                end
            end

            STATE_WR_SUB: begin
                if(prefetch_wait == '0) begin // check if AFU unset wait
                    if (allow_prefetch_continue) begin 
                        if (awvalid & awready) begin
                            aw_handshake <= 1'b1;
                        end
                        if (wvalid & wready) begin  // nc-p-write can start, otherwise wait 
                            w_handshake <= 1'b1;
                        end
                    end
                    else begin
                        aw_handshake <= 1'b0;
                        w_handshake <= 1'b0;
                    end
                end
            end

            STATE_WR_SUB_RESP: begin
                if (bvalid & bready) begin  // nc-p-write done
                    aw_handshake <= 1'b0;
                    w_handshake <= 1'b0;
                    end_prefetch <= 1'b1;
                end
		//prefetch_resp_stall <= prefetch_resp_stall - 1'b1;
            end

            default: begin
                end_prefetch <= 1'b0;
            end
        endcase
    end
end

/*---------------------------------
FSM
-----------------------------------*/

always_comb begin
    next_state = state;
    new_abt_cnt = abort_cnt_reg;
    new_success_cnt = success_cnt_reg;
    unique case(state)
        STATE_RESET: begin
            // guard for prefetching wrong address
            if (start_prefetch_r) begin
                next_state = STATE_RD_ADDR;
            end else begin
                next_state = STATE_RESET;
            end
        end

        STATE_RD_ADDR: begin 
            if(prefetch_wait) begin
                next_state = STATE_RD_ADDR; // wait for AFU to allow prefetch
            end
            else if (allow_prefetch_continue) begin // no waiting, check if prefetch can continue
                if (arready & arvalid) begin
                    next_state = STATE_RD_DATA;
                end
                else begin
                    next_state = STATE_RD_ADDR;
                end
            end
            else begin // reset prefetch
                next_state = STATE_RESET;
                new_abt_cnt[31:0] = abort_cnt_reg[31:0] + 32'd1; // increment abort count
            end
        end

        STATE_RD_DATA: begin
            if (rready & rvalid) begin
                next_state = STATE_WR_SUB;
	    	    if (rresp != 2'b1) begin // if NOT EXOKAY
	      		    next_state = STATE_RESET;
                	new_abt_cnt[63:32] = abort_cnt_reg[63:32] + 32'd1; // increment abort count
	    	    end
	    end
            else begin
                next_state = STATE_RD_DATA;
            end
        end

        STATE_WR_SUB: begin
            if(prefetch_wait) begin // wait for AFU to allow prefetch
                next_state = STATE_WR_SUB;
            end
            else if(allow_prefetch_continue) begin // no waiting, check for host read before NCP happens
                if (awready & wready) begin
                    next_state = STATE_WR_SUB_RESP;
                end
                else if (wvalid == 1'b0) begin
                    if (awready) begin
                        next_state = STATE_WR_SUB_RESP;
                    end
                    else begin
                        next_state = STATE_WR_SUB;
                    end
                end
                else if (awvalid == 1'b0) begin
                    if (wready) begin
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
            else begin
                next_state = STATE_RESET; // reset prefetch
            end
        end

        STATE_WR_SUB_RESP: begin
            if (bvalid & bready) begin
				//if (prefetch_resp_stall == '0) begin
            	next_state = STATE_RESET;
                new_success_cnt = success_cnt_reg + 64'd1; // increment success count
            end
            else begin
                next_state = STATE_WR_SUB_RESP;
            end
        end

        default: begin
            next_state = STATE_RESET;
        end
    endcase
end

always_comb begin
    set_default();
    unique case(state)
        STATE_RD_ADDR: begin
            arvalid = 1'b1;
            arid = 12'd2; // id can be any value within 2^12 as you want
            aruser = csr_aruser; // own, host-bias, hdm 
            // aruser = 6'b100000; // may need to change to host bias 
            araddr = prefetch_page_addr_r;
        end

        STATE_RD_DATA: begin
            rready = 1'b1;
        end

        STATE_WR_SUB: begin
            if (aw_handshake == 1'b0) begin
                awvalid = 1'b1;
            end
            else begin
                awvalid = 1'b0;
            end
            awid = 12'd2;
            awuser = csr_awuser; // non-cacheable push, d2d, host bias
            awaddr = prefetch_page_addr_r;

            if (w_handshake == 1'b0) begin
                wvalid = 1'b1;
            end
            else begin
                wvalid = 1'b0;
            end
            wlast = 1'b1;
            wstrb = 64'hffffffffffffffff;
        end

        STATE_WR_SUB_RESP: begin
            bready = 1'b1;
        end

        default: begin

        end
    endcase
end
    

endmodule
