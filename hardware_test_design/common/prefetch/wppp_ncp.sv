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
    
    input logic [6:0] csr_awuser,
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
    awuser =  csr_awuser; // 7'b0100010; // NCP to host
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

    input logic [6:0] csr_awuser,

    input wppprefetch_rw_pipe_t filter2ncp_pipe,
    output logic [31:0] success_count
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
logic full, empty;
logic fifo_enq, fifo_deq;
(* preserve_for_debug *) logic [6:0] curr_fifo_size;
logic [31:0] success_cnt_r;
ncp_fifo_t ncp_fifo_in, ncp_fifo_out;
wppprefetch_rw_state_t ncp_state, next_ncp_state;

assign success_count = success_cnt_r;

fifo_128w_588d resp2ncp_fifo(
	.data(ncp_fifo_in),  //  fifo_input.datain,  Data input of the memory.The data port is required for all FIFO operation.
	.wrreq(fifo_enq), //            .wrreq,   wrreq input signal to request for write operation.The wrreq signal is required for all FIFO operation.
	.rdreq(fifo_deq), //            .rdreq,   rdreq input signal to request for read operation.The rdreq signal is required for all FIFO operation.
	.clock(axi4_mm_clk), //            .clk,     Positive-edge-triggered clock.
	.q(ncp_fifo_out),     // fifo_output.dataout, Data output of the memory. This port is required for all FIFO operation.
	.usedw(curr_fifo_size), //            .usedw,   Show the number of words stored in the FIFO.
	.full(full),  //            .full,    When full signal is asserted, the FIFO IP core is considered full. Do not perform write request operation when the FIFO IP core is full.
	.empty(empty)  //            .empty,   When empty signal is asserted, the FIFO IP core is considered empty.Do not perform read request operation when the FIFO IP core is empty.
);

// fifo enqueue drivers
always_comb begin
    fifo_enq = filter2ncp_pipe.push_valid & ~full;
    ncp_fifo_in.id = filter2ncp_pipe.push_id;
    ncp_fifo_in.addr = filter2ncp_pipe.push_addr;
    ncp_fifo_in.data = filter2ncp_pipe.push_data;
end

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        ncp_state <= NCP_WRITE;
        success_cnt_r <= '0;
    end
    else begin
        ncp_state <= next_ncp_state;
        unique case(ncp_state)
            NCP_WRITE_DATA: begin
                if (wready & wvalid) begin
                    success_cnt_r <= success_cnt_r + 1;
                end
            end
            default:;
        endcase
    end
end

/* state output */
always_comb begin
    awvalid = '0;
    // awuser = 7'b0100010; // NCP to host, default behavior
    awuser = csr_awuser; // user defined
    awid = '0;
    awaddr = '0;
    wvalid = '0;
    wstrb = 64'hFFFFFFFFFFFFFFFF; // all bytes valid
    wlast = 1'b1;
    wdata = '0;
    unique case(ncp_state)
        NCP_WRITE: begin
            awvalid = (~empty); // only valid when fifo is not empty
            awid = ncp_fifo_out.id;
            awaddr = ncp_fifo_out.addr;
        end
        NCP_WRITE_DATA: begin
            wvalid = 1'b1;
            wdata = ncp_fifo_out.data;
        end
        default:;
    endcase
end

/* state update */
always_comb begin
    next_ncp_state = ncp_state;
    fifo_deq = 1'b0;
    unique case(ncp_state)
        NCP_WRITE: begin
            if (awready & awvalid) begin
                next_ncp_state = NCP_WRITE_DATA;
            end
        end
        NCP_WRITE_DATA: begin
            if (wready & wvalid) begin
                fifo_deq = (~empty); // dequeue when fifo is not empty
                next_ncp_state = NCP_WRITE;
            end
        end
        default:;
    endcase
end

endmodule
