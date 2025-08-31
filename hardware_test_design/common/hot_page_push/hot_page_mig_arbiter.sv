// TODO
// Do we need to use a counter-based priority? otherwise one module might try to starve the other to even be able to send an AXI request if responses come back quickly
// Easy resolution for HAPB: buffer the bresp and send it after 64/256 AXI writes from the HPPB?


module hot_page_push_arbiter(
    input logic     axi4_mm_clk,
    input logic     axi4_mm_rst_n,

// ACTUAL AXI SIGNALS
// read address channel
    output logic [11:0]               arid,
    output logic [63:0]               araddr,
    output logic [9:0]                arlen,    // must tie to 10'd0
    output logic [2:0]                arsize,   // must tie to 3'b110
    output logic [1:0]                arburst,  // must tie to 2'b00
    output logic [2:0]                arprot,   // must tie to 3'b000
    output logic [3:0]                arqos,    // must tie to 4'b0000
    output logic [5:0]                aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    output logic                      arvalid,
    output logic [3:0]                arcache,  // must tie to 4'b0000
    output logic [1:0]                arlock,   // must tie to 2'b00
    output logic [3:0]                arregion, // must tie to 4'b0000
    input                             arready,

// read response channel
    input [11:0]                      rid,
    input [511:0]                     rdata,  
    input [1:0]                       rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                             rlast,  // no use
    input                             ruser,  // no use
    input                             rvalid,
    output logic                      rready,

// write address channel
    output logic [11:0]               awid,
    output logic [63:0]               awaddr, 
    output logic [9:0]                awlen,    // must tie to 10'd0
    output logic [2:0]                awsize,   // must tie to 3'b110 (64B/T)
    output logic [1:0]                awburst,  // must tie to 2'b00            : CXL IP limitation
    output logic [2:0]                awprot,   // must tie to 3'b000
    output logic [3:0]                awqos,    // must tie to 4'b0000
    output logic [5:0]                awuser,
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
    input [11:0]                      bid,
    input [1:0]                       bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                       buser,  // must tie to 4'b0000
    input                             bvalid,
    output logic                      bready,

// ACTUAL AXI SIGNALS MM 0
// read address channel
    output logic [11:0]               arid1,
    output logic [63:0]               araddr1,
    output logic [9:0]                arlen1,    // must tie to 10'd0
    output logic [2:0]                arsize1,   // must tie to 3'b110
    output logic [1:0]                arburst1,  // must tie to 2'b00
    output logic [2:0]                arprot1,   // must tie to 3'b000
    output logic [3:0]                arqos1,    // must tie to 4'b0000
    output logic [5:0]                aruser1,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    output logic                      arvalid1,
    output logic [3:0]                arcache1,  // must tie to 4'b0000
    output logic [1:0]                arlock1,   // must tie to 2'b00
    output logic [3:0]                arregion1, // must tie to 4'b0000
    input                             arready1,

// read response channel
    input [11:0]                      rid1,
    input [511:0]                     rdata1,  
    input [1:0]                       rresp1,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                             rlast1,  // no use
    input                             ruser1,  // no use
    input                             rvalid1,
    output logic                      rready1,

// write address channel
    output logic [11:0]               awid1,
    output logic [63:0]               awaddr1, 
    output logic [9:0]                awlen1,    // must tie to 10'd0
    output logic [2:0]                awsize1,   // must tie to 3'b110 (64B/T)
    output logic [1:0]                awburst1,  // must tie to 2'b00            : CXL IP limitation
    output logic [2:0]                awprot1,   // must tie to 3'b000
    output logic [3:0]                awqos1,    // must tie to 4'b0000
    output logic [5:0]                awuser1,
    output logic                      awvalid1,
    output logic [3:0]                awcache1,  // must tie to 4'b0000
    output logic [1:0]                awlock1,   // must tie to 2'b00
    output logic [3:0]                awregion1, // must tie to 4'b0000
    output logic [5:0]                awatop1,   // must tie to 6'b000000
    input                             awready1,

// write data channel
    output logic [511:0]              wdata1,
    output logic [(512/8)-1:0]        wstrb1,
    output logic                      wlast1,
    output logic                      wuser1,  // must tie to 1'b0
    output logic                      wvalid1,
    input                             wready1,

// write response channel
    input [11:0]                      bid1,
    input [1:0]                       bresp1,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                       buser1,  // must tie to 4'b0000
    input                             bvalid1,
    output logic                      bready1,


// HOT ADDRESS PUSH AXI WRITE: hapb_
    input logic [11:0]               hapb_awid,
    input logic [63:0]               hapb_awaddr, 
    input logic [5:0]                hapb_awuser,
    input logic                      hapb_awvalid,
    output logic                     hapb_awready,

    input logic [511:0]              hapb_wdata,
    input logic [(512/8)-1:0]        hapb_wstrb,
    input logic                      hapb_wlast,
    input logic                      hapb_wvalid,
    output logic                     hapb_wready,

    output logic [11:0]              hapb_bid,
    output logic [1:0]               hapb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic [3:0]               hapb_buser,  // must tie to 4'b0000
    output logic                     hapb_bvalid,
    input logic                      hapb_bready,

// HOT PAGE PUSH AXI WRITE: hppb_
    input logic [11:0]               hppb_awid,
    input logic [63:0]               hppb_awaddr, 
    input logic [5:0]                hppb_awuser,
    input logic                      hppb_awvalid,
    output logic                     hppb_awready,

    input logic [511:0]              hppb_wdata,
    input logic [(512/8)-1:0]        hppb_wstrb,
    input logic                      hppb_wlast,
    input logic                      hppb_wvalid,
    output logic                     hppb_wready,

    output logic [11:0]              hppb_bid,
    output logic [1:0]               hppb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic [3:0]               hppb_buser,  // must tie to 4'b0000
    output logic                     hppb_bvalid,
    input logic                      hppb_bready,

// HOT PAGE PUSH AXI READ: hppb_
    input logic [11:0]               hppb_arid,
    input logic [63:0]               hppb_araddr,
    input logic                      hppb_arvalid,
    input logic [5:0]                hppb_aruser,
    output logic                     hppb_arready,

    output logic [11:0]              hppb_rid,
    output logic [511:0]             hppb_rdata,  
    output logic [1:0]               hppb_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic                     hppb_rlast,  // no use
    output logic                     hppb_ruser,  // no use
    output logic                     hppb_rvalid,
    input logic                      hppb_rready,


// HOT PAGE PUSH 1 AXI WRITE: hppb1_
    input logic [11:0]               hppb1_awid,
    input logic [63:0]               hppb1_awaddr, 
    input logic [5:0]                hppb1_awuser,
    input logic                      hppb1_awvalid,
    output logic                     hppb1_awready,

    input logic [511:0]              hppb1_wdata,
    input logic [(512/8)-1:0]        hppb1_wstrb,
    input logic                      hppb1_wlast,
    input logic                      hppb1_wvalid,
    output logic                     hppb1_wready,

    output logic [11:0]              hppb1_bid,
    output logic [1:0]               hppb1_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic [3:0]               hppb1_buser,  // must tie to 4'b0000
    output logic                     hppb1_bvalid,
    input logic                      hppb1_bready,

// HOT PAGE PUSH 1 AXI READ: hppb1_
    input logic [11:0]               hppb1_arid,
    input logic [63:0]               hppb1_araddr,
    input logic                      hppb1_arvalid,
    input logic [5:0]                hppb1_aruser,
    output logic                     hppb1_arready,

    output logic [11:0]              hppb1_rid,
    output logic [511:0]             hppb1_rdata,  
    output logic [1:0]               hppb1_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic                     hppb1_rlast,  // no use
    output logic                     hppb1_ruser,  // no use
    output logic                     hppb1_rvalid,
    input logic                      hppb1_rready,


// DST ADDRESS AXI READ: hppb_addr_pair_
    input logic [11:0]               hppb_addr_pair_arid,
    input logic [63:0]               hppb_addr_pair_araddr,
    input logic                      hppb_addr_pair_arvalid,
    input logic [5:0]                hppb_addr_pair_aruser,
    output logic                     hppb_addr_pair_arready,

    output logic [11:0]              hppb_addr_pair_rid,
    output logic [511:0]             hppb_addr_pair_rdata,  
    output logic [1:0]               hppb_addr_pair_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic                     hppb_addr_pair_rlast,  // no use
    output logic                     hppb_addr_pair_ruser,  // no use
    output logic                     hppb_addr_pair_rvalid,
    input logic                      hppb_addr_pair_rready,

// MIG DONE CNT AXI WRITE: hppb_mig_done_
    input logic [11:0]              hppb_mig_done_awid,
    input logic [63:0]              hppb_mig_done_awaddr, 
    input logic [5:0]               hppb_mig_done_awuser,
    input logic                     hppb_mig_done_awvalid,
    output logic                    hppb_mig_done_awready,

    // write data channel
    input logic [511:0]             hppb_mig_done_wdata,
    input logic [(512/8)-1:0]       hppb_mig_done_wstrb,
    input logic                     hppb_mig_done_wlast,
    input logic                     hppb_mig_done_wvalid,
    output logic                    hppb_mig_done_wready,

    // write response channel
    output logic [11:0]             hppb_mig_done_bid,
    output logic [1:0]              hppb_mig_done_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic [3:0]              hppb_mig_done_buser,  // must be tied to 4'b0000
    output logic                    hppb_mig_done_bvalid,
    input logic                     hppb_mig_done_bready

);

function void set_wr_default();
    awid = '0;
    awaddr = '0;
    awuser = '0;
    awvalid = '0;

    wdata = '0;
    wstrb = '0;
    wlast = '0;
    wvalid = '0;
endfunction

// Tying Responses based on IDs: can use any bits
    // Using Bit 11 to indicate what interface: 0 == hppb, 1 == the other one

    // Write
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

// Tying Requests
    logic ongoing_wreq;

    // 10 indicates mig_done_cnt, 01 indicates hapb, 00 indicates hppb
    logic [1:0] wreq_id, wreq_id_reg;        
    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_wreq <= '0;
            wreq_id_reg <= '0;
        end else begin
            if (awvalid & awready) begin
                ongoing_wreq <= '1;
            end else if (wvalid & wready) begin
                ongoing_wreq <= '0;
            end
            wreq_id_reg <= wreq_id;
        end
    end

    always_comb begin
        set_wr_default();

        hppb_mig_done_awready = '0;
        hppb_mig_done_wready = '0;

        hapb_awready = '0;
        hapb_wready = '0;

        hppb_awready = '0;
        hppb_wready = '0;

        wreq_id = wreq_id_reg;

        if (~ongoing_wreq) begin
            awid = {2'b11, hppb_mig_done_awid[9:0]};
            awaddr = hppb_mig_done_awaddr; 
            awuser = hppb_mig_done_awuser;
            awvalid = hppb_mig_done_awvalid;
            hppb_mig_done_awready = awready & hppb_mig_done_awvalid;
            wreq_id = 2'b10;
            if (~hppb_mig_done_awvalid) begin
                awid = {2'b10, hapb_awid[9:0]};
                awaddr = hapb_awaddr; 
                awuser = hapb_awuser;
                awvalid = hapb_awvalid;
                hapb_awready = awready & hapb_awvalid;
                wreq_id = 2'b01;
            end 
            if (~hppb_mig_done_awvalid && ~hapb_awvalid) begin
                // send hppb requests
                awid = {1'b0, hppb_awid[10:0]};
                awaddr = hppb_awaddr; 
                awuser = hppb_awuser;
                awvalid = hppb_awvalid;
                hppb_awready = awready;
                wreq_id = 2'b00;
            end
        end
        if (ongoing_wreq) begin
            if (wreq_id == 2'b10) begin
                wdata = hppb_mig_done_wdata;
                wstrb = hppb_mig_done_wstrb;
                wlast = hppb_mig_done_wlast;
                wvalid = hppb_mig_done_wvalid;
                hppb_mig_done_wready = wready;
            end else if (wreq_id == 2'b01) begin
                wdata = hapb_wdata;
                wstrb = hapb_wstrb;
                wlast = hapb_wlast;
                wvalid = hapb_wvalid;
                hapb_wready = wready;
            end else begin
                wdata = hppb_wdata;
                wstrb = hppb_wstrb;
                wlast = hppb_wlast;
                wvalid = hppb_wvalid;
                hppb_wready = wready;
            end
        end
    end

// Tying responses
    // TODO: Assuming hapb_bready and hppb_bready will be active at the time:::::::
    always_comb begin
        bready = '1;

        hppb_mig_done_bvalid = bvalid & bid[11:10] == 2'b11;
        hapb_bvalid = bvalid & bid[11:10] == 2'b10;
        hppb_bvalid = bvalid & bid[11] == 1'b0;

        hppb_mig_done_bid = {1'b0, bid[10:0]};
        hppb_mig_done_bresp = bresp;
        hppb_mig_done_buser = buser;

        hapb_bid = {1'b0, bid[10:0]};
        hapb_bresp = bresp;
        hapb_buser = buser;

        hppb_bid = {1'b0, bid[10:0]};
        hppb_bresp = bresp;
        hppb_buser = buser;

    end


// READ
function void set_rd_default();
    arid = '0;
    araddr = '0;
    aruser = '0;
    arvalid = '0;
endfunction


    assign  arlen        = '0   ;
    assign  arsize       = 3'b110   ; // must tie to 3'b110
    assign  arburst      = '0   ;
    assign  arprot       = '0   ;
    assign  arqos        = '0   ;
    assign  arcache      = '0   ;
    assign  arlock       = '0   ;
    assign  arregion     = '0   ;

// Tying Requests
    always_comb begin
        set_rd_default();

        hppb_addr_pair_arready = '0;
        hppb_arready = '0;

        arid = {1'b1, hppb_addr_pair_arid[10:0]};
        araddr = hppb_addr_pair_araddr; 
        aruser = hppb_addr_pair_aruser;
        arvalid = hppb_addr_pair_arvalid;
        hppb_addr_pair_arready = arready;

        if (~hppb_addr_pair_arvalid) begin
            // send hppb requests
            arid = {1'b0, hppb_arid[10:0]};
            araddr = hppb_araddr; 
            aruser = hppb_aruser;
            arvalid = hppb_arvalid;
            hppb_arready = arready;
        end
    end


// Tying responses
    // TODO: Assuming hppb_addr_pair_rready and hppb_rready will be active at the time:::::::
    always_comb begin
        rready = '1;

        hppb_addr_pair_rvalid = rvalid & rid[11] == 1'b1;
        hppb_rvalid = rvalid & rid[11] == 1'b0;

        hppb_addr_pair_rid = {1'b0, rid[10:0]};
        hppb_addr_pair_rresp = rresp;
        hppb_addr_pair_ruser = ruser;
        hppb_addr_pair_rlast = rlast;
        hppb_addr_pair_rdata = rdata;

        hppb_rid = {1'b0, rid[10:0]};
        hppb_rresp = rresp;
        hppb_ruser = ruser;
        hppb_rlast = rlast;
        hppb_rdata = rdata;
    end



// AXI MM 0 interface

    assign  awlen1        = '0   ;
    assign  awsize1       = 3'b110   ; // must tie to 3'b110
    assign  awburst1      = '0   ;
    assign  awprot1       = '0   ;
    assign  awqos1        = '0   ;
    assign  awcache1      = '0   ;
    assign  awlock1       = '0   ;
    assign  awregion1     = '0   ;
    assign  awatop1       = '0   ;
    assign  wuser1        = '0   ;

    assign  arlen1        = '0   ;
    assign  arsize1       = 3'b110   ; // must tie to 3'b110
    assign  arburst1      = '0   ;
    assign  arprot1       = '0   ;
    assign  arqos1        = '0   ;
    assign  arcache1      = '0   ;
    assign  arlock1       = '0   ;
    assign  arregion1     = '0   ;

function void set_wr1_default();
    awid1 = '0;
    awaddr1 = '0;
    awuser1 = '0;
    awvalid1 = '0;

    wdata1 = '0;
    wstrb1 = '0;
    wlast1 = '0;
    wvalid1 = '0;
endfunction

always_comb begin
    rready1 = '1;
    hppb1_rvalid = rvalid1 & rid1[11] == 1'b0;
    hppb1_rid = {1'b0, rid1[10:0]};
    hppb1_rresp = rresp1;
    hppb1_ruser = ruser1;
    hppb1_rlast = rlast1;
    hppb1_rdata = rdata1;

    bready1 = '1;
    hppb1_bvalid = bvalid1 & bid1[11] == 1'b0;
    hppb1_bid = {1'b0, bid1[10:0]};
    hppb1_bresp = bresp1;
    hppb1_buser = buser1;
end

always_comb begin
    arid1 = {1'b0, hppb1_arid[10:0]};
    araddr1 = hppb1_araddr; 
    aruser1 = hppb1_aruser;
    arvalid1 = hppb1_arvalid;
    hppb1_arready = arready1;

end



// Tying Requests
    logic ongoing_w1req;
    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_w1req <= '0;
        end else begin
            if (awvalid1 & awready1) begin
                ongoing_w1req <= '1;
            end else if (wvalid1 & wready1) begin
                ongoing_w1req <= '0;
            end
        end
    end

    always_comb begin
        set_wr1_default();

        hppb1_awready = '0;
        hppb1_wready = '0;

        if (~ongoing_w1req) begin
            awid1 = {1'b0, hppb1_awid[10:0]};
            awaddr1 = hppb1_awaddr; 
            awuser1 = hppb1_awuser;
            awvalid1 = hppb1_awvalid;
            hppb1_awready = awready1;
        end
        if (ongoing_w1req) begin
            wdata1 = hppb1_wdata;
            wstrb1 = hppb1_wstrb;
            wlast1 = hppb1_wlast;
            wvalid1 = hppb1_wvalid;
            hppb1_wready = wready1;
        end
    end

// 2 AXI write arbiter: 
//     priorites (1 highest)
//         2. hot address push
//         3. hot page push

// 2 AXI read arbiter:
//     priorities (1 highest)
//         1. fetch destination (0 is the magic value for ignorable destinations)
//         2. hot page push


// Base the arbitration simply on
//     awready and arready to control who gets to use the AXI bus
//     AWID and ARID corresponding to requests from a specific kind of interface: 
//         certain bits correspond to certain stimulus on BID and RID channels



endmodule
