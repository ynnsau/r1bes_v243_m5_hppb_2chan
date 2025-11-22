/* fsm design for ncp write */
module wppp_ncp
import wppprefetch_pkg::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

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
    input  logic                      awready,

    // write data channel
    output logic [511:0]              wdata,
    output logic [(512/8)-1:0]        wstrb,
    output logic                      wlast,
    output logic                      wuser,  // must tie to 1'b0
    output logic                      wvalid,
    input  logic                      wready,

    // write response channel
    input logic [11:0]                bid,    // no use
    input logic [1:0]                 bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic [3:0]                 buser,  // must tie to 4'b0000
    input logic                       bvalid,
    output logic                      bready,

    input wppprefetch_rw_pipe_t filter2ncp_pipe,
    output logic [31:0] success_count
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
assign  bready       = '1	; // always ready to accept write response

wppprefetch_rw_state_t ncp_state, next_ncp_state;
wppprefetch_rw_pipe_t pipe_in_reg;
logic [31:0] success_cnt_r;

assign success_count = success_cnt_r;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        ncp_state <= IDLE;
        pipe_in_reg <= '0;
        success_cnt_r <= '0;
    end
    else begin
        ncp_state <= next_ncp_state;
        unique case(ncp_state)
            IDLE: begin
                if (filter2ncp_pipe.push_valid) begin // if pipe from previous stage is valid
                    pipe_in_reg <= filter2ncp_pipe;
                end
            end
            NCP_WRITE_DATA: begin
                if (wready & wvalid) begin
                    success_cnt_r <= success_cnt_r + 1;
                end
            end
            default:;
        endcase
    end
end

/* state update */
always_comb begin
    next_ncp_state = ncp_state;
    unique case(ncp_state)
        IDLE: begin
            if (filter2ncp_pipe.push_valid) begin
                next_ncp_state = NCP_WRITE;
            end
        end
        NCP_WRITE: begin
            if (awready & awvalid) begin
                next_ncp_state = NCP_WRITE_DATA;
            end
        end
        NCP_WRITE_DATA: begin
            if (wready & wvalid) begin
                next_ncp_state = IDLE;
            end
        end
        default:;
    endcase
end


/* state output */
always_comb begin
    awvalid = '0;
    awuser = 7'b0100010; // NCP to host
    awid = '0;
    awaddr = '0;
    wvalid = '0;
    wstrb = 64'hFFFFFFFFFFFFFFFF; // all bytes valid
    wlast = 1'b1;
    wdata = '0;
    unique case(ncp_state)
        NCP_WRITE: begin
            awvalid = 1'b1;
            awid = pipe_in_reg.push_id;
            awaddr = pipe_in_reg.push_addr;
        end
        NCP_WRITE_DATA: begin
            wvalid = 1'b1;
            wdata = pipe_in_reg.push_data;
        end
        default:;
    endcase
end
endmodule

/* pipeline design for ncp write */
module wppp_ncp_pipe
import wppprefetch_pkg::*;
(    
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

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
    input  logic                      wready,

    // write response channel
    input logic [11:0]                bid,    // no use
    input logic [1:0]                 bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic [3:0]                 buser,  // must tie to 4'b0000
    input logic                       bvalid,
    output logic                      bready,

    input wppprefetch_rw_pipe_t filter2ncp_pipe
); // contain mini pipe

/* const */
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
assign  bready       = '1	; // always ready to accept write response

/* internal */
// for simplicity, discard pipe in if wready is begin back pressured

logic aw_lock, w_lock;
wppprefetch_rw_pipe_t pipe_in_reg, addr2data_pipe;

always_comb begin
    awid = pipe_in_reg.push_id;
    awaddr = pipe_in_reg.push_addr;
    awuser = 7'b0100010; // NCP to host
    awvalid = pipe_in_reg.push_valid;

    wlast = 1'b1;
    wstrb = 64'hFFFFFFFFFFFFFFFF; // all bytes valid
    wvalid = 1'b0;
    wdata = '0;
    if (w_lock) begin
        wvalid = 1'b1;
        wdata = addr2data_pipe.push_data;
    end
end

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        pipe_in_reg <= '0;
        addr2data_pipe <= '0;
        aw_lock <= 1'b0;
        w_lock <= 1'b0;
    end
    else begin
        if (awvalid & awready) begin
            aw_lock <= 1'b0; // release aw lock
            if (w_lock == 0) begin
                w_lock <= 1'b1;
                addr2data_pipe <= pipe_in_reg;
                pipe_in_reg <= '0; // clear pipe in reg
            end
        end
        else if (!aw_lock && filter2ncp_pipe.push_valid) begin // take new input if input is valid and not locked
            aw_lock <= 1'b1;
            pipe_in_reg <= filter2ncp_pipe;
        end

        if (wvalid & wready) begin
            w_lock <= 1'b0; // release w lock
            addr2data_pipe <= '0;
        end
    end
end
endmodule
