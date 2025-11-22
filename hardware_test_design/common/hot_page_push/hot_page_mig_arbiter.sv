// TODO
// Do we need to use a counter-based priority? otherwise one module might try to starve the other to even be able to send an AXI request if responses come back quickly
// Easy resolution for HAPB: buffer the bresp and send it after 64/256 AXI writes from the HPPB?


module hot_page_push_arbiter(
    input logic     axi4_mm_clk,
    input logic     axi4_mm_rst_n,


    axi_ports.ar_req                  axi0_r_ch,
    axi_ports.aw_req                  axi0_w_ch,

    axi_ports.ar_req                  axi1_r_ch,
    axi_ports.aw_req                  axi1_w_ch,

    axi_ports.aw_resp                 hapb_axi_w_ch,

    axi_ports.aw_resp                 hppb_axi0_w_ch,
    axi_ports.ar_resp                 hppb_axi0_r_ch,

    axi_ports.aw_resp                 hppb_axi1_w_ch,
    axi_ports.ar_resp                 hppb_axi1_r_ch,

    axi_ports.ar_resp                 hppb_addr_pair_axi_r_ch,

    axi_ports.aw_resp                 hppb_mig_done_axi_w_ch
);

function void set_wr_default();
    axi0_w_ch.awid = '0;
    axi0_w_ch.awaddr = '0;
    axi0_w_ch.awuser = '0;
    axi0_w_ch.awvalid = '0;

    axi0_w_ch.wdata = '0;
    axi0_w_ch.wstrb = '0;
    axi0_w_ch.wlast = '0;
    axi0_w_ch.wvalid = '0;
endfunction

// Tying Responses based on IDs: can use any bits
    // Using Bit 11 to indicate what interface: 0 == hppb, 1 == the other one

    // Write
    assign  axi0_w_ch.awlen        = '0   ;
    assign  axi0_w_ch.awsize       = 3'b110   ; // must tie to 3'b110
    assign  axi0_w_ch.awburst      = '0   ;
    assign  axi0_w_ch.awprot       = '0   ;
    assign  axi0_w_ch.awqos        = '0   ;
    assign  axi0_w_ch.awcache      = '0   ;
    assign  axi0_w_ch.awlock       = '0   ;
    assign  axi0_w_ch.awregion     = '0   ;
    assign  axi0_w_ch.awatop       = '0   ;
    assign  axi0_w_ch.wuser        = '0   ;

// Tying Requests
    logic ongoing_wreq;

    // 10 indicates mig_done_cnt, 01 indicates hapb, 00 indicates hppb
    logic [1:0] wreq_id, wreq_id_reg;        
    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_wreq <= '0;
            wreq_id_reg <= '0;
        end else begin
            if (axi0_w_ch.awvalid & axi0_w_ch.awready) begin
                ongoing_wreq <= '1;
            end else if (axi0_w_ch.wvalid & axi0_w_ch.wready) begin
                ongoing_wreq <= '0;
            end
            wreq_id_reg <= wreq_id;
        end
    end

    always_comb begin
        set_wr_default();

        hppb_mig_done_axi_w_ch.awready = '0;
        hppb_mig_done_axi_w_ch.wready = '0;

        hapb_axi_w_ch.awready = '0;
        hapb_axi_w_ch.wready = '0;

        hppb_axi0_w_ch.awready = '0;
        hppb_axi0_w_ch.wready = '0;

        wreq_id = wreq_id_reg;

        if (~ongoing_wreq) begin
            axi0_w_ch.awid = {2'b11, hppb_mig_done_axi_w_ch.awid[9:0]};
            axi0_w_ch.awaddr = hppb_mig_done_axi_w_ch.awaddr; 
            axi0_w_ch.awuser = hppb_mig_done_axi_w_ch.awuser;
            axi0_w_ch.awvalid = hppb_mig_done_axi_w_ch.awvalid;
            hppb_mig_done_axi_w_ch.awready = axi0_w_ch.awready & hppb_mig_done_axi_w_ch.awvalid;
            wreq_id = 2'b10;
            if (~hppb_mig_done_axi_w_ch.awvalid) begin
                axi0_w_ch.awid = {2'b10, hapb_axi_w_ch.awid[9:0]};
                axi0_w_ch.awaddr = hapb_axi_w_ch.awaddr; 
                axi0_w_ch.awuser = hapb_axi_w_ch.awuser;
                axi0_w_ch.awvalid = hapb_axi_w_ch.awvalid;
                hapb_axi_w_ch.awready = axi0_w_ch.awready & hapb_axi_w_ch.awvalid;
                wreq_id = 2'b01;
            end 
            if (~hppb_mig_done_axi_w_ch.awvalid && ~hapb_axi_w_ch.awvalid) begin
                // send hppb requests
                axi0_w_ch.awid = {1'b0, hppb_axi0_w_ch.awid[10:0]};
                axi0_w_ch.awaddr = hppb_axi0_w_ch.awaddr; 
                axi0_w_ch.awuser = hppb_axi0_w_ch.awuser;
                axi0_w_ch.awvalid = hppb_axi0_w_ch.awvalid;
                hppb_axi0_w_ch.awready = axi0_w_ch.awready;
                wreq_id = 2'b00;
            end
        end
        if (ongoing_wreq) begin
            if (wreq_id == 2'b10) begin
                axi0_w_ch.wdata = hppb_mig_done_axi_w_ch.wdata;
                axi0_w_ch.wstrb = hppb_mig_done_axi_w_ch.wstrb;
                axi0_w_ch.wlast = hppb_mig_done_axi_w_ch.wlast;
                axi0_w_ch.wvalid = hppb_mig_done_axi_w_ch.wvalid;
                hppb_mig_done_axi_w_ch.wready = axi0_w_ch.wready;
            end else if (wreq_id == 2'b01) begin
                axi0_w_ch.wdata = hapb_axi_w_ch.wdata;
                axi0_w_ch.wstrb = hapb_axi_w_ch.wstrb;
                axi0_w_ch.wlast = hapb_axi_w_ch.wlast;
                axi0_w_ch.wvalid = hapb_axi_w_ch.wvalid;
                hapb_axi_w_ch.wready = axi0_w_ch.wready;
            end else begin
                axi0_w_ch.wdata = hppb_axi0_w_ch.wdata;
                axi0_w_ch.wstrb = hppb_axi0_w_ch.wstrb;
                axi0_w_ch.wlast = hppb_axi0_w_ch.wlast;
                axi0_w_ch.wvalid = hppb_axi0_w_ch.wvalid;
                hppb_axi0_w_ch.wready = axi0_w_ch.wready;
            end
        end
    end

// Tying responses
    // TODO: Assuming hapb_axi_w_ch.bready and hppb_axi0_w_ch.bready will be active at the time:::::::
    always_comb begin
        axi0_w_ch.bready = '1;

        hppb_mig_done_axi_w_ch.bvalid = axi0_w_ch.bvalid & axi0_w_ch.bid[11:10] == 2'b11;
        hapb_axi_w_ch.bvalid = axi0_w_ch.bvalid & axi0_w_ch.bid[11:10] == 2'b10;
        hppb_axi0_w_ch.bvalid = axi0_w_ch.bvalid & axi0_w_ch.bid[11] == 1'b0;

        hppb_mig_done_axi_w_ch.bid = {1'b0, axi0_w_ch.bid[10:0]};
        hppb_mig_done_axi_w_ch.bresp = axi0_w_ch.bresp;
        hppb_mig_done_axi_w_ch.buser = axi0_w_ch.buser;

        hapb_axi_w_ch.bid = {1'b0, axi0_w_ch.bid[10:0]};
        hapb_axi_w_ch.bresp = axi0_w_ch.bresp;
        hapb_axi_w_ch.buser = axi0_w_ch.buser;

        hppb_axi0_w_ch.bid = {1'b0, axi0_w_ch.bid[10:0]};
        hppb_axi0_w_ch.bresp = axi0_w_ch.bresp;
        hppb_axi0_w_ch.buser = axi0_w_ch.buser;

    end


// READ
function void set_rd_default();
    axi0_r_ch.arid = '0;
    axi0_r_ch.araddr = '0;
    axi0_r_ch.aruser = '0;
    axi0_r_ch.arvalid = '0;
endfunction


    assign  axi0_r_ch.arlen        = '0   ;
    assign  axi0_r_ch.arsize       = 3'b110   ; // must tie to 3'b110
    assign  axi0_r_ch.arburst      = '0   ;
    assign  axi0_r_ch.arprot       = '0   ;
    assign  axi0_r_ch.arqos        = '0   ;
    assign  axi0_r_ch.arcache      = '0   ;
    assign  axi0_r_ch.arlock       = '0   ;
    assign  axi0_r_ch.arregion     = '0   ;

// Tying Requests
    always_comb begin
        set_rd_default();

        hppb_addr_pair_axi_r_ch.arready = '0;
        hppb_axi0_r_ch.arready = '0;

        axi0_r_ch.arid = {1'b1, hppb_addr_pair_axi_r_ch.arid[10:0]};
        axi0_r_ch.araddr = hppb_addr_pair_axi_r_ch.araddr; 
        axi0_r_ch.aruser = hppb_addr_pair_axi_r_ch.aruser;
        axi0_r_ch.arvalid = hppb_addr_pair_axi_r_ch.arvalid;
        hppb_addr_pair_axi_r_ch.arready = axi0_r_ch.arready;

        if (~hppb_addr_pair_axi_r_ch.arvalid) begin
            // send hppb requests
            axi0_r_ch.arid = {1'b0, hppb_axi0_r_ch.arid[10:0]};
            axi0_r_ch.araddr = hppb_axi0_r_ch.araddr; 
            axi0_r_ch.aruser = hppb_axi0_r_ch.aruser;
            axi0_r_ch.arvalid = hppb_axi0_r_ch.arvalid;
            hppb_axi0_r_ch.arready = axi0_r_ch.arready;
        end
    end


// Tying responses
    // TODO: Assuming hppb_addr_pair_axi_r_ch.rready and hppb_axi0_r_ch.rready will be active at the time:::::::
    always_comb begin
        axi0_r_ch.rready = '1;

        hppb_addr_pair_axi_r_ch.rvalid = axi0_r_ch.rvalid & axi0_r_ch.rid[11] == 1'b1;
        hppb_axi0_r_ch.rvalid = axi0_r_ch.rvalid & axi0_r_ch.rid[11] == 1'b0;

        hppb_addr_pair_axi_r_ch.rid = {1'b0, axi0_r_ch.rid[10:0]};
        hppb_addr_pair_axi_r_ch.rresp = axi0_r_ch.rresp;
        hppb_addr_pair_axi_r_ch.ruser = axi0_r_ch.ruser;
        hppb_addr_pair_axi_r_ch.rlast = axi0_r_ch.rlast;
        hppb_addr_pair_axi_r_ch.rdata = axi0_r_ch.rdata;

        hppb_axi0_r_ch.rid = {1'b0, axi0_r_ch.rid[10:0]};
        hppb_axi0_r_ch.rresp = axi0_r_ch.rresp;
        hppb_axi0_r_ch.ruser = axi0_r_ch.ruser;
        hppb_axi0_r_ch.rlast = axi0_r_ch.rlast;
        hppb_axi0_r_ch.rdata = axi0_r_ch.rdata;
    end



// AXI MM 0 interface

    assign  axi1_w_ch.awlen        = '0   ;
    assign  axi1_w_ch.awsize       = 3'b110   ; // must tie to 3'b110
    assign  axi1_w_ch.awburst      = '0   ;
    assign  axi1_w_ch.awprot       = '0   ;
    assign  axi1_w_ch.awqos        = '0   ;
    assign  axi1_w_ch.awcache      = '0   ;
    assign  axi1_w_ch.awlock       = '0   ;
    assign  axi1_w_ch.awregion     = '0   ;
    assign  axi1_w_ch.awatop       = '0   ;
    assign  axi1_w_ch.wuser        = '0   ;

    assign  axi1_r_ch.arlen        = '0   ;
    assign  axi1_r_ch.arsize       = 3'b110   ; // must tie to 3'b110
    assign  axi1_r_ch.arburst      = '0   ;
    assign  axi1_r_ch.arprot       = '0   ;
    assign  axi1_r_ch.arqos        = '0   ;
    assign  axi1_r_ch.arcache      = '0   ;
    assign  axi1_r_ch.arlock       = '0   ;
    assign  axi1_r_ch.arregion     = '0   ;

function void set_wr1_default();
    axi1_w_ch.awid = '0;
    axi1_w_ch.awaddr = '0;
    axi1_w_ch.awuser = '0;
    axi1_w_ch.awvalid = '0;

    axi1_w_ch.wdata = '0;
    axi1_w_ch.wstrb = '0;
    axi1_w_ch.wlast = '0;
    axi1_w_ch.wvalid = '0;
endfunction

always_comb begin
    axi1_r_ch.rready = '1;
    hppb_axi1_r_ch.rvalid = axi1_r_ch.rvalid & axi1_r_ch.rid[11] == 1'b0;
    hppb_axi1_r_ch.rid = {1'b0, axi1_r_ch.rid[10:0]};
    hppb_axi1_r_ch.rresp = axi1_r_ch.rresp;
    hppb_axi1_r_ch.ruser = axi1_r_ch.ruser;
    hppb_axi1_r_ch.rlast = axi1_r_ch.rlast;
    hppb_axi1_r_ch.rdata = axi1_r_ch.rdata;

    axi1_w_ch.bready = '1;
    hppb_axi1_w_ch.bvalid = axi1_w_ch.bvalid & axi1_w_ch.bid[11] == 1'b0;
    hppb_axi1_w_ch.bid = {1'b0, axi1_w_ch.bid[10:0]};
    hppb_axi1_w_ch.bresp = axi1_w_ch.bresp;
    hppb_axi1_w_ch.buser = axi1_w_ch.buser;
end

always_comb begin
    axi1_r_ch.arid = {1'b0, hppb_axi1_r_ch.arid[10:0]};
    axi1_r_ch.araddr = hppb_axi1_r_ch.araddr; 
    axi1_r_ch.aruser = hppb_axi1_r_ch.aruser;
    axi1_r_ch.arvalid = hppb_axi1_r_ch.arvalid;
    hppb_axi1_r_ch.arready = axi1_r_ch.arready;

end



// Tying Requests
    logic ongoing_w1req;
    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_w1req <= '0;
        end else begin
            if (axi1_w_ch.awvalid & axi1_w_ch.awready) begin
                ongoing_w1req <= '1;
            end else if (axi1_w_ch.wvalid & axi1_w_ch.wready) begin
                ongoing_w1req <= '0;
            end
        end
    end

    always_comb begin
        set_wr1_default();

        hppb_axi1_w_ch.awready = '0;
        hppb_axi1_w_ch.wready = '0;

        if (~ongoing_w1req) begin
            axi1_w_ch.awid = {1'b0, hppb_axi1_w_ch.awid[10:0]};
            axi1_w_ch.awaddr = hppb_axi1_w_ch.awaddr; 
            axi1_w_ch.awuser = hppb_axi1_w_ch.awuser;
            axi1_w_ch.awvalid = hppb_axi1_w_ch.awvalid;
            hppb_axi1_w_ch.awready = axi1_w_ch.awready;
        end
        if (ongoing_w1req) begin
            axi1_w_ch.wdata = hppb_axi1_w_ch.wdata;
            axi1_w_ch.wstrb = hppb_axi1_w_ch.wstrb;
            axi1_w_ch.wlast = hppb_axi1_w_ch.wlast;
            axi1_w_ch.wvalid = hppb_axi1_w_ch.wvalid;
            hppb_axi1_w_ch.wready = axi1_w_ch.wready;
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
