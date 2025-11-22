module axi_arbiter
#(
    parameter ARB_BIT_POS = 11
)
(
    input logic                       axi4_mm_clk,
    input logic                       axi4_mm_rst_n,

    axi_ports.ar_req                  axi_r_ch,
    axi_ports.aw_req                  axi_w_ch,

    axi_ports.ar_resp                 p0_axi_r_ch,
    axi_ports.aw_resp                 p0_axi_w_ch,

    axi_ports.ar_resp                 p1_axi_r_ch,
    axi_ports.aw_resp                 p1_axi_w_ch
);

function void set_wr_default();
    axi_w_ch.awid = '0;
    axi_w_ch.awaddr = '0;
    axi_w_ch.awuser = '0;
    axi_w_ch.awvalid = '0;

    axi_w_ch.wdata = '0;
    axi_w_ch.wstrb = '0;
    axi_w_ch.wlast = '0;
    axi_w_ch.wvalid = '0;
endfunction

// Tying Responses based on IDs: can use any bits
    // Using Bit 11 to indicate what interface: 0 == hppb, 1 == the other one

    // Write
    assign  axi_w_ch.awlen        = '0   ;
    assign  axi_w_ch.awsize       = 3'b110   ; // must tie to 3'b110
    assign  axi_w_ch.awburst      = '0   ;
    assign  axi_w_ch.awprot       = '0   ;
    assign  axi_w_ch.awqos        = '0   ;
    assign  axi_w_ch.awcache      = '0   ;
    assign  axi_w_ch.awlock       = '0   ;
    assign  axi_w_ch.awregion     = '0   ;
    assign  axi_w_ch.awatop       = '0   ;
    assign  axi_w_ch.wuser        = '0   ;

// Tying Requests
    logic ongoing_wreq;
    logic wreq_id, wreq_id_reg;        
    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_wreq <= '0;
            wreq_id_reg <= '0;
        end else begin
            if (axi_w_ch.awvalid & axi_w_ch.awready) begin
                ongoing_wreq <= '1;
            end else if (axi_w_ch.wvalid & axi_w_ch.wready) begin
                ongoing_wreq <= '0;
            end
            wreq_id_reg <= wreq_id;
        end
    end

    always_comb begin
        set_wr_default();

        p0_axi_w_ch.awready = '0;
        p0_axi_w_ch.wready = '0;

        p1_axi_w_ch.awready = '0;
        p1_axi_w_ch.wready = '0;

        wreq_id = wreq_id_reg;

        if (~ongoing_wreq) begin
            axi_w_ch.awid = '0;
            axi_w_ch.awid[ARB_BIT_POS:0] = {1'b0, p0_axi_w_ch.awid[ARB_BIT_POS-1:0]};
            axi_w_ch.awaddr = p0_axi_w_ch.awaddr; 
            axi_w_ch.awuser = p0_axi_w_ch.awuser;
            axi_w_ch.awvalid = p0_axi_w_ch.awvalid;
            p0_axi_w_ch.awready = axi_w_ch.awready & p0_axi_w_ch.awvalid;
            wreq_id = 1'b0;

            if (~p0_axi_w_ch.awvalid) begin
                axi_w_ch.awid = '0;
                axi_w_ch.awid[ARB_BIT_POS:0] = {1'b1, p1_axi_w_ch.awid[ARB_BIT_POS-1:0]};
                axi_w_ch.awaddr = p1_axi_w_ch.awaddr; 
                axi_w_ch.awuser = p1_axi_w_ch.awuser;
                axi_w_ch.awvalid = p1_axi_w_ch.awvalid;
                p1_axi_w_ch.awready = axi_w_ch.awready;
                wreq_id = 1'b1;
            end
        end
        if (ongoing_wreq) begin
            if (wreq_id == 1'b0) begin
                axi_w_ch.wdata = p0_axi_w_ch.wdata;
                axi_w_ch.wstrb = p0_axi_w_ch.wstrb;
                axi_w_ch.wlast = p0_axi_w_ch.wlast;
                axi_w_ch.wvalid = p0_axi_w_ch.wvalid;
                p0_axi_w_ch.wready = axi_w_ch.wready;
            end else begin
                axi_w_ch.wdata = p1_axi_w_ch.wdata;
                axi_w_ch.wstrb = p1_axi_w_ch.wstrb;
                axi_w_ch.wlast = p1_axi_w_ch.wlast;
                axi_w_ch.wvalid = p1_axi_w_ch.wvalid;
                p1_axi_w_ch.wready = axi_w_ch.wready;
            end
        end
    end

// Tying responses
    always_comb begin
        axi_w_ch.bready = '1;

        p0_axi_w_ch.bvalid = axi_w_ch.bvalid & axi_w_ch.bid[ARB_BIT_POS] == 1'b0;
        p1_axi_w_ch.bvalid = axi_w_ch.bvalid & axi_w_ch.bid[ARB_BIT_POS] == 1'b1;

        p0_axi_w_ch.bid = '0;
        p0_axi_w_ch.bid[ARB_BIT_POS-1:0] = axi_w_ch.bid[ARB_BIT_POS-1:0];
        p0_axi_w_ch.bresp = axi_w_ch.bresp;
        p0_axi_w_ch.buser = axi_w_ch.buser;

        p1_axi_w_ch.bid = '0;
        p1_axi_w_ch.bid[ARB_BIT_POS-1:0] = axi_w_ch.bid[ARB_BIT_POS-1:0];
        p1_axi_w_ch.bresp = axi_w_ch.bresp;
        p1_axi_w_ch.buser = axi_w_ch.buser;
    end


// READ
function void set_rd_default();
    axi_r_ch.arid = '0;
    axi_r_ch.araddr = '0;
    axi_r_ch.aruser = '0;
    axi_r_ch.arvalid = '0;
endfunction

    assign  axi_r_ch.arlen        = '0   ;
    assign  axi_r_ch.arsize       = 3'b110   ; // must tie to 3'b110
    assign  axi_r_ch.arburst      = '0   ;
    assign  axi_r_ch.arprot       = '0   ;
    assign  axi_r_ch.arqos        = '0   ;
    assign  axi_r_ch.arcache      = '0   ;
    assign  axi_r_ch.arlock       = '0   ;
    assign  axi_r_ch.arregion     = '0   ;

// Tying Requests
    always_comb begin
        set_rd_default();

        p0_axi_r_ch.arready = '0;
        p1_axi_r_ch.arready = '0;

        axi_r_ch.arid = '0;
        axi_r_ch.arid[ARB_BIT_POS:0] = {1'b0, p0_axi_r_ch.arid[ARB_BIT_POS-1:0]};
        axi_r_ch.araddr = p0_axi_r_ch.araddr; 
        axi_r_ch.aruser = p0_axi_r_ch.aruser;
        axi_r_ch.arvalid = p0_axi_r_ch.arvalid;
        p0_axi_r_ch.arready = axi_r_ch.arready;

        if (~p0_axi_r_ch.arvalid) begin
            axi_r_ch.arid = '0;
            axi_r_ch.arid[ARB_BIT_POS:0] = {1'b1, p1_axi_r_ch.arid[ARB_BIT_POS-1:0]};
            axi_r_ch.araddr = p1_axi_r_ch.araddr; 
            axi_r_ch.aruser = p1_axi_r_ch.aruser;
            axi_r_ch.arvalid = p1_axi_r_ch.arvalid;
            p1_axi_r_ch.arready = axi_r_ch.arready;
        end
    end


// Tying responses
    always_comb begin
        axi_r_ch.rready = '1;

        p0_axi_r_ch.rvalid = axi_r_ch.rvalid & axi_r_ch.rid[ARB_BIT_POS] == 1'b0;
        p1_axi_r_ch.rvalid = axi_r_ch.rvalid & axi_r_ch.rid[ARB_BIT_POS] == 1'b1;

        p0_axi_r_ch.rid = '0;
        p0_axi_r_ch.rid[ARB_BIT_POS-1:0] = axi_r_ch.rid[ARB_BIT_POS-1:0];
        p0_axi_r_ch.rresp = axi_r_ch.rresp;
        p0_axi_r_ch.ruser = axi_r_ch.ruser;
        p0_axi_r_ch.rlast = axi_r_ch.rlast;
        p0_axi_r_ch.rdata = axi_r_ch.rdata;

        p1_axi_r_ch.rid = '0;
        p1_axi_r_ch.rid[ARB_BIT_POS-1:0] = axi_r_ch.rid[ARB_BIT_POS-1:0];
        p1_axi_r_ch.rresp = axi_r_ch.rresp;
        p1_axi_r_ch.ruser = axi_r_ch.ruser;
        p1_axi_r_ch.rlast = axi_r_ch.rlast;
        p1_axi_r_ch.rdata = axi_r_ch.rdata;
    end

endmodule
