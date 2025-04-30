// TAGGING changes with FIXME when needing to switch back to HAPB
module auto_push_arbiter
import mig_params::*;
(
    input logic                      axi4_mm_clk,
    input logic                      axi4_mm_rst_n,

    input logic [511:0]              hapb_wdata,  // based on HAPB AXI writes
    input logic                      hapb_wvalid,
    input logic                      hapb_wready,

    output logic [63:0]              csr_ahppb_mig_start_cnt,
    output logic [63:0]              csr_ahppb_mig_done_cnt,
    input logic [63:0]               csr_batch_ack_cnt,
    input logic [63:0]               csr_ahppb_batch_info[MIG_GRP_SIZE],
    input logic [63:0]               csr_ahppb_src_addr[MIG_GRP_SIZE],

    output logic                     ahppb_mig_in_progress,
    output logic [63:0]              ahppb_src_addr[MIG_GRP_SIZE],
    output logic [63:0]              ahppb_dst_addr[MIG_GRP_SIZE],
    output logic [1:0]               ahppb_ack_sts[MIG_GRP_SIZE],   // 00 == wait, 01 == ack, 10 == nack
    output logic                     ahppb_new_addr_available,

    input logic                      clst_invalidate_common,
    input logic [71:0]               clst_page_offset_common,
    output logic                     clst_ready,
    output logic                     clst_invalidate[MIG_GRP_SIZE],
    output logic [5:0]               clst_page_offset[MIG_GRP_SIZE],

    input logic [63:0]               ahppb_mig_done_cnt[MIG_GRP_SIZE],
    output logic [63:0]              ahppb_total_mig_done_cnt,

// read ahppb
    input logic [11:0]               ahppb_arid[MIG_GRP_SIZE],
    input logic [63:0]               ahppb_araddr[MIG_GRP_SIZE],
    input logic [5:0]                ahppb_aruser[MIG_GRP_SIZE],   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    input logic                      ahppb_arvalid[MIG_GRP_SIZE],
    input logic                      ahppb_arvalid_intended[MIG_GRP_SIZE],
    output logic                     ahppb_arready[MIG_GRP_SIZE],

    output logic [11:0]              ahppb_rid[MIG_GRP_SIZE],
    output logic [511:0]             ahppb_rdata[MIG_GRP_SIZE],  
    output logic [1:0]               ahppb_rresp[MIG_GRP_SIZE],  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic                     ahppb_rlast[MIG_GRP_SIZE],  // no use
    output logic                     ahppb_ruser[MIG_GRP_SIZE],  // no use
    output logic                     ahppb_rvalid[MIG_GRP_SIZE],
    input logic                      ahppb_rready[MIG_GRP_SIZE],

// Write ahppb
    input logic [11:0]               ahppb_awid[MIG_GRP_SIZE],
    input logic [63:0]               ahppb_awaddr[MIG_GRP_SIZE], 
    input logic [5:0]                ahppb_awuser[MIG_GRP_SIZE],
    input logic                      ahppb_awvalid[MIG_GRP_SIZE],
    output logic                     ahppb_awready[MIG_GRP_SIZE],

    input logic [511:0]              ahppb_wdata[MIG_GRP_SIZE],
    input logic [(512/8)-1:0]        ahppb_wstrb[MIG_GRP_SIZE],
    input logic                      ahppb_wlast[MIG_GRP_SIZE],
    input logic                      ahppb_wvalid[MIG_GRP_SIZE],
    output logic                     ahppb_wready[MIG_GRP_SIZE],

    output logic [11:0]              ahppb_bid[MIG_GRP_SIZE],
    output logic [1:0]               ahppb_bresp[MIG_GRP_SIZE],  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    output logic [3:0]               ahppb_buser[MIG_GRP_SIZE],  // must tie to 4'b0000
    output logic                     ahppb_bvalid[MIG_GRP_SIZE],
    input logic                      ahppb_bready[MIG_GRP_SIZE],

// read hppb
    output logic [11:0]              hppb_arid,
    output logic [63:0]              hppb_araddr,
    output logic [5:0]               hppb_aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    output logic                     hppb_arvalid,
    input                            hppb_arready,

    input [11:0]                     hppb_rid,
    input [511:0]                    hppb_rdata,  
    input [1:0]                      hppb_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                            hppb_rlast,  // no use
    input                            hppb_ruser,  // no use
    input                            hppb_rvalid,
    output logic                     hppb_rready,

// write hppb
    output logic [11:0]              hppb_awid,
    output logic [63:0]              hppb_awaddr, 
    output logic [5:0]               hppb_awuser,
    output logic                     hppb_awvalid,
    input logic                      hppb_awready,

    output logic [511:0]             hppb_wdata,
    output logic [(512/8)-1:0]       hppb_wstrb,
    output logic                     hppb_wlast,
    output logic                     hppb_wvalid,
    input logic                      hppb_wready,

    input logic [11:0]               hppb_bid,
    input logic [1:0]                hppb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic [3:0]                hppb_buser,  // must tie to 4'b0000
    input logic                      hppb_bvalid,
    output logic                     hppb_bready,

// HOT PAGE PUSH 1 AXI WRITE: hppb1_
    output logic [11:0]               hppb1_awid,
    output logic [63:0]               hppb1_awaddr, 
    output logic [5:0]                hppb1_awuser,
    output logic                      hppb1_awvalid,
    input logic                     hppb1_awready,

    output logic [511:0]              hppb1_wdata,
    output logic [(512/8)-1:0]        hppb1_wstrb,
    output logic                      hppb1_wlast,
    output logic                      hppb1_wvalid,
    input logic                     hppb1_wready,

    input logic [11:0]              hppb1_bid,
    input logic [1:0]               hppb1_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic [3:0]               hppb1_buser,  // must tie to 4'b0000
    input logic                     hppb1_bvalid,
    output logic                      hppb1_bready,

// HOT PAGE PUSH 1 AXI READ: hppb1_
    output logic [11:0]               hppb1_arid,
    output logic [63:0]               hppb1_araddr,
    output logic                      hppb1_arvalid,
    output logic [5:0]                hppb1_aruser,
    input logic                     hppb1_arready,

    input logic [11:0]              hppb1_rid,
    input logic [511:0]             hppb1_rdata,  
    input logic [1:0]               hppb1_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input logic                     hppb1_rlast,  // no use
    input logic                     hppb1_ruser,  // no use
    input logic                     hppb1_rvalid,
    output logic                      hppb1_rready,

    output logic [63:0]              clst_ip_og_cnt[8],
    output logic [63:0]              clst_ip_fin_cnt[8],
    output logic [63:0]              clst_host_og_cnt[8],
    output logic [63:0]              clst_host_fin_cnt[8]

);

// MIG_DONE
    logic [63:0]    old_mig_done_cnt [MIG_GRP_SIZE];
    logic           new_mig_cycle_done;
    always_ff @( posedge axi4_mm_clk ) begin
        if (~axi4_mm_rst_n) begin
            csr_ahppb_mig_done_cnt <= '0;
            old_mig_done_cnt <= '{default: '0};
            ahppb_total_mig_done_cnt <= '0;
        end else begin
            if (new_mig_cycle_done) begin       // until all folks 
                old_mig_done_cnt <= ahppb_mig_done_cnt; // array assignment  
                ahppb_total_mig_done_cnt <= ahppb_mig_done_cnt[0];  // first element should be good enough 

                csr_ahppb_mig_done_cnt <= csr_ahppb_mig_done_cnt + 1'b1;
            end
        end
    end

    // logic [63:0]    max_req_mig_done_cnt;
    // logic [63:0]    common_mig_done_cnt;
    logic all_same_mig_done_cnt, same_old_mig_done_cnt; 
    always_comb begin
        all_same_mig_done_cnt = '1;
        same_old_mig_done_cnt = ahppb_mig_done_cnt == old_mig_done_cnt;
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (ahppb_mig_done_cnt[i] != ahppb_mig_done_cnt[0]) begin
                all_same_mig_done_cnt = '0;
            end
        end
        new_mig_cycle_done = all_same_mig_done_cnt && ~same_old_mig_done_cnt;    // even same_old_mig_done_cnt is enough (old_mig_done_cnt is homogeneous always)

    end

// ADDRESSES
    logic [63:0]      old_batch_ack_cnt;
    logic             stored_hapb_vld;
    logic [511:0]     stored_hapb_wdata;
    logic [63:0]      ahppb_src_addr_curr[MIG_GRP_SIZE];

    logic             new_dst_available;

    always_ff @( posedge axi4_mm_clk ) begin
        if (~axi4_mm_rst_n) begin
            csr_ahppb_mig_start_cnt <= '0;

            ahppb_mig_in_progress <= '0;
            stored_hapb_vld <= '0;
            stored_hapb_wdata <= '0;
            ahppb_src_addr_curr = '{default: '0};

            old_batch_ack_cnt <= '1;
            new_dst_available <= '0;

            ahppb_ack_sts <= '{default: '0};
        end else begin

            ahppb_ack_sts <= '{default: '0};    // only need to raise ACK/NACK for one cycle TODO:: check if this works

            if (hapb_wready && hapb_wvalid) begin
                stored_hapb_vld <= '1;
                stored_hapb_wdata <= hapb_wdata;
            end

            if (ahppb_new_addr_available) begin
                csr_ahppb_mig_start_cnt <= csr_ahppb_mig_start_cnt + 1'b1;

                ahppb_mig_in_progress <= '1;
                stored_hapb_vld <= '0;

                ahppb_src_addr_curr <= ahppb_src_addr;
                new_dst_available <= '0;
            end

            if (new_mig_cycle_done) begin
                ahppb_mig_in_progress <= '0;
                ahppb_ack_sts <= '{default: '0};
            end

            if (old_batch_ack_cnt != csr_batch_ack_cnt) begin
                new_dst_available <= '1;
                old_batch_ack_cnt <= csr_batch_ack_cnt;
                for (int i = 0; i < MIG_GRP_SIZE; i++) begin
                    ahppb_ack_sts[i] <= csr_ahppb_batch_info[i][63:62];
                end
            end

        end
    end

    always_comb begin
        ahppb_src_addr = '{default:'0};
        ahppb_dst_addr = '{default:'0};

        // FIXME
        // ahppb_new_addr_available = ~ahppb_mig_in_progress && (stored_hapb_vld || (hapb_wready && hapb_wvalid)) && (new_dst_available);
        ahppb_new_addr_available = ~ahppb_mig_in_progress && /*(stored_hapb_vld || (hapb_wready && hapb_wvalid)) &&*/ (new_dst_available);

        if (ahppb_new_addr_available) begin
            for (int i = 0; i < MIG_GRP_SIZE; i++) begin
                ahppb_src_addr[i] = csr_ahppb_src_addr[i];
                ahppb_dst_addr[i] = {20'b0, csr_ahppb_batch_info[i][31:0], 12'b0};
                /*
                ahppb_dst_addr[i] = dst_addr_base + dst_base_offset*4096*MIG_GRP_SIZE + i*4096;
                ahppb_src_addr[i] = {20'b0, stored_hapb_wdata[i*32 +: 31], 13'b0};
                if (hapb_wready && hapb_wvalid) begin
                    ahppb_src_addr[i] = {20'b0, hapb_wdata[i*32 +: 31], 13'b0}; // can we add we switch to control who does this?
                end
                */
            end
        end
    end

// CLST::: 
// TODO :::: 
//      Because all pages are separated in their own modules and they now have their own ports:
//      CLST_ready might cause CLST to get queued up for a while: Take care of this scenario

    logic using_clst_invalidate;
    logic matching_clst;
    always_comb begin
        clst_invalidate = '{default: '0};//clst_invalidate_reg;
        clst_page_offset = '{default: '0};
        // clst_inv_idx = clst_inv_idx_reg;

        using_clst_invalidate = '0;
        matching_clst = '0;
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (/*csr_ahppb_clst_en != '0 &&*/ clst_invalidate_common && (clst_page_offset_common[51:12] == ahppb_src_addr_curr[i][51:12])) begin
                // clst_invalidate[i] = '1; // TODO   
                // clst_page_offset[i] = clst_page_offset_common[11:6];
                // using_clst_invalidate = '1;      // TODO
                matching_clst = '1;
                break;
            end
        end

        clst_ready = '1;
    end

always_ff @( posedge axi4_mm_clk ) begin
    if (!axi4_mm_rst_n) begin
        clst_ip_og_cnt <= '{default: '0};
        clst_ip_fin_cnt <= '{default: '0};
        clst_host_og_cnt <= '{default: '0};
        clst_host_fin_cnt <= '{default: '0};
    end else begin
        if (matching_clst) begin
            clst_ip_og_cnt[clst_page_offset_common[55:52]] <= clst_ip_og_cnt[clst_page_offset_common[55:52]] + 1'b1;
            clst_ip_fin_cnt[clst_page_offset_common[59:56]] <= clst_ip_fin_cnt[clst_page_offset_common[59:56]] + 1'b1;
            clst_host_og_cnt[clst_page_offset_common[63:60]] <= clst_host_og_cnt[clst_page_offset_common[63:60]] + 1'b1;
            clst_host_fin_cnt[clst_page_offset_common[67:64]] <= clst_host_fin_cnt[clst_page_offset_common[67:64]] + 1'b1;
        end
    end
end

// WRITE

    function void set_wr_default();
        hppb_awid = '0;
        hppb_awaddr = '0;
        hppb_awuser = '0;
        hppb_awvalid = '0;

        hppb_wdata = '0;
        hppb_wstrb = '0;
        hppb_wlast = '0;
        hppb_wvalid = '0;

        hppb1_awid = '0;
        hppb1_awaddr = '0;
        hppb1_awuser = '0;
        hppb1_awvalid = '0;

        hppb1_wdata = '0;
        hppb1_wstrb = '0;
        hppb1_wlast = '0;
        hppb1_wvalid = '0;
    endfunction

    logic [($clog2(MIG_GRP_SIZE)-1):0] chosen_aw_pg, chosen_aw_pg_reg, chosen_aw_pg1, chosen_aw_pg1_reg;
    logic ongoing_wreq, ongoing_wreq1;
    // Tying Requests

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            ongoing_wreq <= '0;
            ongoing_wreq1 <= '0;
            chosen_aw_pg_reg <= '0;
            chosen_aw_pg1_reg <= (MIG_GRP_SIZE/2);
        end else begin
            if ((hppb_awvalid & hppb_awready) & ~(hppb_wvalid & hppb_wready)) begin
                ongoing_wreq <= '1;
            end 
            if (hppb_wvalid & hppb_wready) begin
                ongoing_wreq <= '0;
            end
            chosen_aw_pg_reg <= chosen_aw_pg;

            if ((hppb1_awvalid & hppb1_awready) & ~(hppb1_wvalid & hppb1_wready)) begin
                ongoing_wreq1 <= '1;
            end 
            if (hppb1_wvalid & hppb1_wready) begin
                ongoing_wreq1 <= '0;
            end
            chosen_aw_pg1_reg <= chosen_aw_pg1;

        end
    end

    always_comb begin
        set_wr_default();

        ahppb_awready = '{default: '0};
        ahppb_wready = '{default: '0};

        chosen_aw_pg = chosen_aw_pg_reg;

        if (~ongoing_wreq) begin
            chosen_aw_pg = '0;
            for (int i = MIG_GRP_SIZE/2 - 1; i >= 0; i--) begin
                if (ahppb_awvalid[i]) begin
                    chosen_aw_pg = i;
                end
            end
            // send hppb requests
            hppb_awid = {1'b0, ahppb_awid[chosen_aw_pg][10:0]};
            hppb_awaddr = ahppb_awaddr[chosen_aw_pg]; 
            hppb_awuser = ahppb_awuser[chosen_aw_pg];
            hppb_awvalid = ahppb_awvalid[chosen_aw_pg];
            ahppb_awready[chosen_aw_pg] = hppb_awready;
        end
        hppb_wdata = ahppb_wdata[chosen_aw_pg];
        hppb_wstrb = ahppb_wstrb[chosen_aw_pg];
        hppb_wlast = ahppb_wlast[chosen_aw_pg];
        hppb_wvalid = ahppb_wvalid[chosen_aw_pg] & (ongoing_wreq || hppb_awvalid);
        ahppb_wready[chosen_aw_pg] = hppb_wready;


        chosen_aw_pg1 = chosen_aw_pg1_reg;

        if (~ongoing_wreq1) begin
            chosen_aw_pg1 = (MIG_GRP_SIZE/2);
            for (int i = MIG_GRP_SIZE - 1; i >= MIG_GRP_SIZE/2; i--) begin
                if (ahppb_awvalid[i]) begin
                    chosen_aw_pg1 = i;
                end
            end
            // send hppb requests
            hppb1_awid = {1'b0, ahppb_awid[chosen_aw_pg1][10:0]};
            hppb1_awaddr = ahppb_awaddr[chosen_aw_pg1]; 
            hppb1_awuser = ahppb_awuser[chosen_aw_pg1];
            hppb1_awvalid = ahppb_awvalid[chosen_aw_pg1];
            ahppb_awready[chosen_aw_pg1] = hppb1_awready;
        end
        hppb1_wdata = ahppb_wdata[chosen_aw_pg1];
        hppb1_wstrb = ahppb_wstrb[chosen_aw_pg1];
        hppb1_wlast = ahppb_wlast[chosen_aw_pg1];
        hppb1_wvalid = ahppb_wvalid[chosen_aw_pg1] & (ongoing_wreq1 || hppb1_awvalid);
        ahppb_wready[chosen_aw_pg1] = hppb1_wready;

    end

    // Tying responses
    always_comb begin
        hppb_bready = '1;
        for (int i = 0; i < MIG_GRP_SIZE/2; i++) begin
            ahppb_bvalid[i] = hppb_bvalid & hppb_bid[11] == 1'b0 & (i[MIG_GRP_ID_SIZE:0] == hppb_bid[MIG_GRP_ID_SIZE + 6:6]);
            ahppb_bid[i] = {1'b0, hppb_bid[10:0]};
            ahppb_bresp[i] = hppb_bresp;
            ahppb_buser[i] = hppb_buser;
        end

        hppb1_bready = '1;
        for (int i = MIG_GRP_SIZE/2; i < MIG_GRP_SIZE; i++) begin
            ahppb_bvalid[i] = hppb1_bvalid & hppb1_bid[11] == 1'b0 & (i[MIG_GRP_ID_SIZE:0] == hppb1_bid[MIG_GRP_ID_SIZE + 6:6]);
            ahppb_bid[i] = {1'b0, hppb1_bid[10:0]};
            ahppb_bresp[i] = hppb1_bresp;
            ahppb_buser[i] = hppb1_buser;
        end
    end


// READ
    function void set_rd_default();
        hppb_arid = '0;
        hppb_araddr = '0;
        hppb_aruser = '0;
        hppb_arvalid = '0;

        hppb1_arid = '0;
        hppb1_araddr = '0;
        hppb1_aruser = '0;
        hppb1_arvalid = '0;
    endfunction

    logic [($clog2(MIG_GRP_SIZE)-1):0] chosen_ar_pg, chosen_ar_pg1;
    // Tying Requests
    always_comb begin
        set_rd_default();

        ahppb_arready = '{default: '0};
        chosen_ar_pg = '0;
        for (int i = MIG_GRP_SIZE/2 - 1; i >= 0; i--) begin
            if (ahppb_arvalid_intended[i]) begin     // 0th page has the highest priority
                chosen_ar_pg = i;
            end
        end
        // send hppb requests
        hppb_arid = {1'b0, ahppb_arid[chosen_ar_pg][10:0]};
        hppb_araddr = ahppb_araddr[chosen_ar_pg]; 
        hppb_aruser = ahppb_aruser[chosen_ar_pg];
        hppb_arvalid = ahppb_arvalid[chosen_ar_pg];

        ahppb_arready[chosen_ar_pg] = hppb_arready;

        chosen_ar_pg1 = (MIG_GRP_SIZE/2);
        for (int i = MIG_GRP_SIZE - 1; i >= MIG_GRP_SIZE/2; i--) begin
            if (ahppb_arvalid_intended[i]) begin     // 0th page has the highest priority
                chosen_ar_pg1 = i;
            end
        end
        // send hppb requests
        hppb1_arid = {1'b0, ahppb_arid[chosen_ar_pg1][10:0]};
        hppb1_araddr = ahppb_araddr[chosen_ar_pg1]; 
        hppb1_aruser = ahppb_aruser[chosen_ar_pg1];
        hppb1_arvalid = ahppb_arvalid[chosen_ar_pg1];

        ahppb_arready[chosen_ar_pg1] = hppb1_arready;

    end


    // Tying responses
    always_comb begin
        hppb_rready = '1;

        for (int i = 0; i < MIG_GRP_SIZE/2; i++) begin
            ahppb_rresp[i] = hppb_rresp;
            ahppb_ruser[i] = hppb_ruser;
            ahppb_rlast[i] = hppb_rlast;
            ahppb_rdata[i] = hppb_rdata;
            ahppb_rid[i] = hppb_rid;

            ahppb_rvalid[i] = hppb_rvalid & hppb_rid[11] == 1'b0 & (i[MIG_GRP_ID_SIZE:0] == hppb_rid[MIG_GRP_ID_SIZE + 6:6]);
        end

        hppb1_rready = '1;
        for (int i = MIG_GRP_SIZE/2; i < MIG_GRP_SIZE; i++) begin
            ahppb_rresp[i] = hppb1_rresp;
            ahppb_ruser[i] = hppb1_ruser;
            ahppb_rlast[i] = hppb1_rlast;
            ahppb_rdata[i] = hppb1_rdata;
            ahppb_rid[i] = hppb1_rid;

            ahppb_rvalid[i] = hppb1_rvalid & hppb1_rid[11] == 1'b0 & (i[MIG_GRP_ID_SIZE:0] == hppb1_rid[MIG_GRP_ID_SIZE + 6:6]);
        end
    end


endmodule
