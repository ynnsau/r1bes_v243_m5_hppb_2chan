module func_offload_mem
import func_offload_params::*;
(
    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    input logic [5:0]               csr_aruser,
    input logic [5:0]               csr_awuser,

    input logic                     rreq_valid,
    input logic [63:0]              rreq_addr,
    output logic [511:0]            rreq_data, 
    output logic                    rreq_complete,

    input logic                     wreq_valid,
    input logic [63:0]              wreq_addr,
    input logic [511:0]             wreq_data, 
    output logic                    wreq_complete,
    
// ACTUAL AXI SIGNALS
    axi_ports.ar_req r_ch,
    axi_ports.aw_req w_ch

);

/* ---------------------------------
    AXI Read
-----------------------------------*/

    enum logic [1:0] {
        STATE_RD_RESET,
        STATE_RD_ADDR,
        STATE_RD_RESP
    } state_rd, next_state_rd;

    function void set_rd_default();
        r_ch.arvalid = 1'b0;
        r_ch.arid = 'b0;
        r_ch.araddr = 'b0;
        r_ch.aruser = 'b0;

        r_ch.rready = 1'b0;
    endfunction

    assign  r_ch.arlen        = '0   ;
    assign  r_ch.arsize       = 3'b110   ; // must tie to 3'b110
    assign  r_ch.arburst      = '0   ;
    assign  r_ch.arprot       = '0   ;
    assign  r_ch.arqos        = '0   ;
    assign  r_ch.arcache      = '0   ;
    assign  r_ch.arlock       = '0   ;
    assign  r_ch.arregion     = '0   ;

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            state_rd <= STATE_RD_RESET;
        end else begin
            state_rd <= next_state_rd;
        end
    end

    always_comb begin
        next_state_rd = state_rd;
        unique case(state_rd)
            STATE_RD_RESET: begin
                if (rreq_valid) begin
                    next_state_rd = STATE_RD_ADDR;
                end
            end
            STATE_RD_ADDR: begin
                if (r_ch.arvalid && r_ch.arready) begin
                    next_state_rd = STATE_RD_RESP;
                end
            end
            STATE_RD_RESP: begin
                if (r_ch.rvalid & r_ch.rready & r_ch.rlast) begin
                    next_state_rd = STATE_RD_RESET;
                end
            end
            default:;
        endcase
    end

    always_comb begin
        set_rd_default();
        rreq_complete = 1'b0;
        rreq_data = '0;
        unique case(state_rd)
            STATE_RD_ADDR: begin 
                r_ch.arvalid = '1;
                r_ch.arid = 11'b0;
                r_ch.aruser = csr_aruser; 
                r_ch.araddr = rreq_addr;       // byte aligned address
            end
            STATE_RD_RESP: begin
                r_ch.rready = 1'b1;
                if (r_ch.rvalid & r_ch.rready & r_ch.rlast) begin
                    rreq_complete = 1'b1;
                    rreq_data = r_ch.rdata;
                end
            end
            default:;
        endcase

    end

    

/* ---------------------------------
    AXI Write
-----------------------------------*/

    enum logic [1:0] {
        STATE_WR_RESET,
        STATE_WR_ADDR,
        STATE_WR_DATA,
        STATE_WR_RESP
    } state_wr, next_state_wr;

    function void set_wr_default();
        w_ch.awvalid = 1'b0;
        w_ch.awaddr = 'b0;
        w_ch.awid = 'b0;
        w_ch.awuser = 'b0; 

        w_ch.wdata = '0;
        w_ch.wvalid = 1'b0;
        w_ch.wlast = 1'b1;
        w_ch.wstrb = 64'hffffffffffffffff;

        w_ch.bready = 1'b0;
    endfunction

    // Write
    assign  w_ch.awlen        = '0   ;
    assign  w_ch.awsize       = 3'b110   ; // must tie to 3'b110
    assign  w_ch.awburst      = '0   ;
    assign  w_ch.awprot       = '0   ;
    assign  w_ch.awqos        = '0   ;
    assign  w_ch.awcache      = '0   ;
    assign  w_ch.awlock       = '0   ;
    assign  w_ch.awregion     = '0   ;
    assign  w_ch.awatop       = '0   ;
    assign  w_ch.wuser        = '0   ;


    always_ff @(posedge axi4_mm_clk) begin
        if (!axi4_mm_rst_n) begin
            state_wr <= STATE_WR_RESET;
        end
        else begin
            state_wr <= next_state_wr;
        end
    end

    always_comb begin
        next_state_wr = state_wr;
        unique case(state_wr)
            STATE_WR_RESET: begin
                if (wreq_valid) begin
                    next_state_wr = STATE_WR_ADDR;
                end
            end
            STATE_WR_ADDR: begin
                if (w_ch.awvalid & w_ch.awready) begin
                    next_state_wr = STATE_WR_DATA;
                end
            end
            STATE_WR_DATA: begin
                if (w_ch.wvalid & w_ch.wready) begin
                    next_state_wr = STATE_WR_RESP;
                end
            end
            STATE_WR_RESP: begin
                if (w_ch.bvalid & w_ch.bready) begin
                    next_state_wr = STATE_WR_RESET;
                end
            end

            default:;
        endcase
    end

    always_comb begin
        set_wr_default();
        wreq_complete = 1'b0;
        unique case(state_wr)
            STATE_WR_ADDR: begin
                w_ch.awvalid = '1;
                w_ch.awuser = csr_awuser; 
                w_ch.awid = '0;
                w_ch.awaddr = wreq_addr;       // byte aligned address
            end
            STATE_WR_DATA: begin
                w_ch.wvalid = 1'b1;
                w_ch.wdata = wreq_data;
            end

            STATE_WR_RESP: begin
                w_ch.bready = 1'b1;
                if (w_ch.bvalid & w_ch.bready) begin
                    wreq_complete = 1'b1;
                end
            end
            default:;
        endcase

    end

endmodule