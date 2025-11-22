module wppprefetch_rw_pipeline
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
wppprefetch_rw_pipe_t rd_stage_out, wr_stage_in, rd2wr_reg;
wppprefetch_rw_state_t rd_curr_state, wr_curr_state;
logic [31:0] success_cnt, abt_cnt, prefetch_cnt;

assign prefetch_abt_cnt = {32'd0, abt_cnt};
assign prefetch_ok_cnt = {prefetch_cnt, success_cnt};
assign prefetch_rw_curr_state = rd_curr_state; // TODO: afu only check the read states for now

// 2 stage pipeline data prefetch module, prefetch read -> prefetch write
// 37 ports
wppp_read wppp_read_inst(
    .axi4_mm_clk       (axi4_mm_clk       ),
    .axi4_mm_rst_n     (axi4_mm_rst_n     ),
    .arid              (arid              ),
    .araddr            (araddr            ),
    .arlen             (arlen             ),
    .arsize            (arsize            ),
    .arburst           (arburst           ),
    .arprot            (arprot            ),
    .arqos             (arqos             ),
    .aruser            (aruser            ),
    .arvalid           (arvalid           ),
    .arcache           (arcache           ),
    .arlock            (arlock            ),
    .arregion          (arregion          ),
    .arready           (arready           ),
    .rid               (rid               ),
    .rdata             (rdata             ),
    .rresp             (rresp             ),
    .rlast             (rlast             ),
    .ruser             (ruser             ),
    .rvalid            (rvalid            ),
    .rready            (rready            ),
    .rd_stage_out      (rd_stage_out      ),
    .rd_curr_state     (rd_curr_state     ),
    .prefetch_page_addr   (prefetch_page_addr),
    .curr_working_address (curr_working_address),
    .start_prefetch    (start_prefetch    ),
    .csr_aruser        (csr_aruser        ),
    .addr_seen         (addr_seen         ),
    .abort_op          (abort_op          ),
    .abt_cnt           (abt_cnt           ),
    .prefetch_cnt      (prefetch_cnt      ),
    .addr_issued       (addr_issued       ),
    .get_next_addr     (get_next_addr     ),
    .faraddr           (faraddr           ),
    .farvalid          (farvalid          ),
    .frvalid           (frvalid           ),
    .frdata            (frdata            )
); // double check connection list

// 30 ports
wppp_write wppp_write_inst(
    .axi4_mm_clk       (axi4_mm_clk     ),
    .axi4_mm_rst_n     (axi4_mm_rst_n   ),
    .awid              (awid            ),
    .awaddr            (awaddr          ),
    .awlen             (awlen           ),
    .awsize            (awsize          ),
    .awburst           (awburst         ),
    .awprot            (awprot          ),
    .awqos             (awqos           ),
    .awuser            (awuser          ),
    .awvalid           (awvalid         ),
    .awcache           (awcache         ),
    .awlock            (awlock          ),
    .awregion          (awregion        ),
    .awatop            (awatop          ),
    .awready           (awready         ),
    .wdata             (wdata           ),
    .wstrb             (wstrb           ),
    .wlast             (wlast           ),
    .wuser             (wuser           ),
    .wvalid            (wvalid          ),
    .wready            (wready          ),
    .bid               (bid             ),
    .bresp             (bresp           ),
    .buser             (buser           ),
    .bvalid            (bvalid          ),
    .bready            (bready          ),
    .wr_stage_in       (rd2wr_reg       ),
    .csr_awuser        (csr_awuser      ),
    .success_cnt       (success_cnt     ),
    .wr_curr_state     (wr_curr_state   )
); // double check connection list

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        rd2wr_reg <= '0;
    end
    else begin
        rd2wr_reg <= rd_stage_out;
    end
end
endmodule

module wppp_read
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

    /* customized signals */
    output wppprefetch_rw_pipe_t rd_stage_out,
    output wppprefetch_rw_state_t rd_curr_state,
    input logic [63:0] prefetch_page_addr, // byte level address, XXX, this may change during the states 
    output logic [63:0] curr_working_address,
    input logic start_prefetch,
    input logic [5:0] csr_aruser,
    input logic addr_seen,
    input logic abort_op,
    
    // stat output
    output logic [31:0] abt_cnt,
    output logic [31:0] prefetch_cnt,

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
assign  arlen        = '0   ;
assign  arsize       = 3'b110   ; // must tie to 3'b110
assign  arburst      = '0   ;
assign  arprot       = '0   ;
assign  arqos        = '0   ;
assign  arcache      = '0   ;
assign  arlock       = '0   ;
assign  arregion     = '0   ;

// internal signals
logic rd_stage_valid;
logic [63:0] prefetch_page_addr_r;
logic [511:0] hb_rdata_reg;
logic [31:0] prefetch_cnt_reg, abort_cnt_reg, new_abt_cnt;
wppprefetch_rw_state_t rd_state, next_rd_state, prev_rd_state;

assign rd_curr_state = rd_state;
assign get_next_addr = (next_rd_state == IDLE) && (rd_state != IDLE);
assign curr_working_address = prefetch_page_addr_r;
assign prefetch_cnt = prefetch_cnt_reg;
assign abt_cnt = abort_cnt_reg;

function void set_rd_defaults();
    arvalid     = 1'b0;
    rready      = 1'b1;
    arid        = '0;
    araddr      = '0;
    aruser      = '0;
    faraddr     = '0;
    farvalid    = '0;
endfunction

function void host_bias_read();
    arid    = 12'h3;
    aruser  = 6'b100000; // target HDM, Host-bias NCR
    arvalid = 1'b1;
    araddr  = prefetch_page_addr_r;
endfunction

function void filter_read();
    farvalid = 1'b1;
    faraddr  = prefetch_page_addr_r;
endfunction

/* read pipe */
always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        prefetch_page_addr_r <= '0;
        hb_rdata_reg <= '0;
        rd_state <= IDLE;
        prev_rd_state <= IDLE;
        prefetch_cnt_reg <= '0;
        abort_cnt_reg <= '0;
    end
    else begin
        rd_state <= next_rd_state;
        abort_cnt_reg <= new_abt_cnt;

        if (next_rd_state != rd_state) begin
            prev_rd_state <= rd_state;
        end

        unique case(rd_state)
            IDLE: begin
                if (start_prefetch) begin
                    prefetch_page_addr_r <= prefetch_page_addr;
                    prefetch_cnt_reg <= prefetch_cnt_reg + 32'd1;
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

always_comb begin
    rd_stage_out = '0;
    if (rd_stage_valid) begin
        rd_stage_out.push_valid = 1'b1;
        rd_stage_out.push_addr = prefetch_page_addr_r;
        rd_stage_out.push_data = hb_rdata_reg;
    end
end

// state update
always_comb begin
    next_rd_state = rd_state;
    new_abt_cnt = abort_cnt_reg;
    addr_issued = 1'b0;
    rd_stage_valid = 1'b0;

    unique case(rd_state)
        IDLE: begin
            if (start_prefetch & ~abort_op) begin
                addr_issued = 1'b1;
                next_rd_state = HB_READ_ADDR;
            end
        end
        HB_READ_ADDR: begin
            if(abort_op =='0) begin
                if (arvalid & arready) begin
                    next_rd_state = HB_READ_DATA;
                end
            end else begin
                if (arready) begin 
                    next_rd_state = HB_ABORT;
                end else begin
                    next_rd_state = ABORT;
                end 
            end
        end
        HB_READ_DATA: begin
            if (abort_op == '0) begin
                if (rvalid & rready) begin
                    if (addr_seen) begin 
                        next_rd_state = F_READ_ADDR;
                    end else begin
                        next_rd_state = ABORT;
                    end
                end
            end
            else begin
                if (rvalid & rready) begin
                    next_rd_state = ABORT;
                end else begin
                    next_rd_state = HB_ABORT;
                end
            end
        end
        F_READ_ADDR: begin
            if (abort_op == '1) begin 
                next_rd_state = F_ABORT;
            end else begin
                next_rd_state = F_READ_DATA;
            end
        end
        F_READ_DATA: begin
            if (abort_op == '1) begin
                if (frvalid) begin
                    next_rd_state = ABORT;
                end else begin
                    next_rd_state = F_ABORT;
                end
            end else if (frvalid) begin
                if  (frdata) begin
                    rd_stage_valid = 1'b1; // latch to prefetch write stage
                    next_rd_state = IDLE; // next addr will be issued in IDLE state
                end else begin
                    next_rd_state = ABORT;
                end
            end 
        end
        HB_ABORT: begin
            if (rvalid & rready) begin
                next_rd_state = ABORT;
            end
        end
        F_ABORT: begin
            if (frvalid) begin
                next_rd_state = ABORT;
            end
        end
        ABORT: begin
            new_abt_cnt = abort_cnt_reg + 32'd1;
            next_rd_state = IDLE;
        end
        default: ;
    endcase
end

always_comb begin
    set_rd_defaults(); // notice rready is always high
    unique case(rd_state)
        HB_READ_ADDR: begin
            host_bias_read();
        end
        F_READ_ADDR: begin
            filter_read();
        end
		  default: set_rd_defaults();
    endcase
end

endmodule


module wppp_write
import wppprefetch_pkg::*;
import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,
    // axi4 interface
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

    /* customized signals */
    input wppprefetch_rw_pipe_t wr_stage_in,
    input logic [6:0] csr_awuser,
    output logic [31:0] success_cnt,
    output wppprefetch_rw_state_t wr_curr_state
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

(* preserve_for_debug *) wppprefetch_rw_state_t w_state, next_w_state;
logic [31:0] success_cnt_reg, new_success_cnt;
logic [63:0] awaddr_reg;
logic [511:0] wdata_reg;

assign success_cnt = success_cnt_reg;
assign wr_curr_state = w_state;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        w_state <= IDLE;
        success_cnt_reg <= '0;
        awaddr_reg <= '0;
        wdata_reg <= '0;
    end
    else begin
        w_state <= next_w_state;
        success_cnt_reg <= new_success_cnt;
        unique case(w_state)
            IDLE: begin
                if (wr_stage_in.push_valid) begin
                    awaddr_reg <= wr_stage_in.push_addr;
                    wdata_reg <= wr_stage_in.push_data;
                end
            end
				default:;
        endcase
    end
end

// state update
always_comb begin
    next_w_state = w_state;
    new_success_cnt = success_cnt_reg;
    unique case(w_state)
        IDLE: begin
            if (wr_stage_in.push_valid) begin
                next_w_state = NCP_WRITE;
            end
        end
        NCP_WRITE: begin
            if (awvalid & awready) begin
                next_w_state = NCP_WRITE_DATA;
            end
        end
        NCP_WRITE_DATA: begin
            if (wvalid & wready) begin
                new_success_cnt = success_cnt_reg + 32'd1;
                next_w_state = IDLE;
            end
        end
		  default:;
    endcase
end

// state signal
always_comb begin
    awvalid = 1'b0;
    wvalid = 1'b0;
    bready = 1'b1;
    wdata = '0;  
    awaddr = 'b0;
    awid = 'b0;
    awuser = 'b0; 
    wlast = 1'b0;
    wstrb = 64'h0;

    unique case(w_state)
        NCP_WRITE: begin
            awid = 12'h2;
            awuser = 7'b0100010; // NCP to host
            awvalid = '1;
            awaddr = awaddr_reg;// need address from stage input
        end
        NCP_WRITE_DATA: begin
            wvalid = '1;
            wdata = wdata_reg; // need data from stage input
            wstrb = 64'hFFFFFFFFFFFFFFFF;
            wlast = 1'b1;
        end
		  default:;
    endcase
end

endmodule
