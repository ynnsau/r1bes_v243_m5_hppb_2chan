/*
Module: hot_page_pusher
Version: 0.0
Last Modified: July 18, 2024
Description: TODO
Workflow: 
    TODO
*/


// HPP = Hot Page Pusher

module hot_page_push
#(
  // common parameter
  parameter ADDR_SIZE = 33,
  parameter MIG_GRP_SIZE = 16
    // Cannot work if MIG_GRP_SIZE >= 64
    // max MIG_GRP_SIZE = 32
    // min MIG_GRP_SIZE = 2
)
(

    input logic axi4_mm_clk,
    input logic axi4_mm_rst_n,

    // Which page to migrate, this page's data (AXI read)
    input logic [63:0]                  src_addr[MIG_GRP_SIZE],

    // Where to migrate the page (AXI write)
    input logic                         new_addr_available,     // based on response to hppb_dst_addr AXI read requests
    input logic [63:0]                  dst_addr[MIG_GRP_SIZE],

    // Migration done incrementing counter
    output logic [63:0]                 mig_done_cnt,

    input logic [5:0] csr_aruser,
    input logic [5:0] csr_awuser,

    // for address pushing to move forward
    output logic                        atleast_one_valid_src,

    output logic [63:0]    min_mig_time,
    output logic [63:0]    max_mig_time,
    output logic [63:0]    total_curr_mig_time,
    output logic [63:0]    min_pg0_mig_time,
    output logic [63:0]    max_pg0_mig_time,
    output logic [63:0]    min_pgn_mig_time,
    output logic [63:0]    max_pgn_mig_time,
    output logic [63:0]    max_fifo_full_cnt,
    output logic [63:0]    max_fifo_empty_cnt,
    output logic [63:0]    max_total_read_cnt,
    output logic [63:0]    max_total_write_cnt,
    output logic [63:0]    hppb_rresp_err_cnt,
    output logic [63:0]    hppb_bresp_err_cnt,
    output logic [63:0]    max_outstanding_rreq_cnt,
    output logic [63:0]    max_outstanding_wreq_cnt,


// read address channel
    output logic [11:0]               hppb_arid,
    output logic [63:0]               hppb_araddr,
    output logic [5:0]                hppb_aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    output logic                      hppb_arvalid,
    input                             hppb_arready,

// read response channel
    input [11:0]                      hppb_rid,
    input [511:0]                     hppb_rdata,  
    input [1:0]                       hppb_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                             hppb_rlast,  // no use
    input                             hppb_ruser,  // no use
    input                             hppb_rvalid,
    output logic                      hppb_rready,

// write address channel
    output logic [11:0]               hppb_awid,
    output logic [63:0]               hppb_awaddr, 
    output logic [5:0]                hppb_awuser,
    output logic                      hppb_awvalid,
    input                             hppb_awready,

// write data channel
    output logic [511:0]              hppb_wdata,
    output logic [(512/8)-1:0]        hppb_wstrb,
    output logic                      hppb_wlast,
    output logic                      hppb_wvalid,
    input                             hppb_wready,

// write response channel
    input [11:0]                      hppb_bid,
    input [1:0]                       hppb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                       hppb_buser,  // must be tied to 4'b0000
    input                             hppb_bvalid,
    output logic                      hppb_bready
);


// TODO:    Assuming that if src addr is new, dst addr is new (will we have enough time to synchronize? Involves going through the full FIFO....)
//          Solution: Change dst addr before src ALWAYS

// 64 = (4 kB page = 4 * 1024 * 8 bits) / (512 AXI bits)
localparam PG_NUM_ENTRIES = 64;
logic [63:0]    curr_outstanding_rreq_cnt;
logic [63:0]    curr_outstanding_wreq_cnt;

// [($clog2(MIG_GRP_SIZE)-1) + 518:518] == pg number, [517:512] == offset within page (page size is always 4096), [511:0] == actual pg data
// ARID-RID, AWID-WID [11:0]: [($clog2(MIG_GRP_SIZE)-1) + 6:6] == pg number, [5:0] = offset within page, 

// HPPB FIFO
    logic fifo_wrreq, fifo_rdreq, fifo_full, fifo_empty;
    logic [($clog2(MIG_GRP_SIZE)-1) + 518:0] fifo_rdata, fifo_wdata;

    fifo_hppb fifo_hppb_data (
        .data  (fifo_wdata),  //   input,  width = 520,  fifo_input.datain
        .wrreq (fifo_wrreq), //   input,    width = 1,            .wrreq
        .rdreq (fifo_rdreq), //   input,    width = 1,            .rdreq
        .clock (axi4_mm_clk), //   input,    width = 1,            .clk
        .q     (fifo_rdata),     //  output,  width = 520, fifo_output.dataout
        .full  (fifo_full),  //  output,    width = 1,            .full
        .empty (fifo_empty)  //  output,    width = 1,            .empty
    );

logic    mig_done_cnt_incr;
/* ---------------------------------
    AXI Read
-----------------------------------*/

    enum logic {
        STATE_RD_RESET,
        STATE_RD_ADDR
    } state_rd, next_state_rd;

    logic [MIG_GRP_SIZE-1:0] src_addr_new;
    logic [63:0]    src_addr_base[MIG_GRP_SIZE];

    logic rd_pg_num_change, new_rd_pg;
    logic [$clog2(MIG_GRP_SIZE)-1:0] rd_pg_num, new_rd_pg_num;
    logic [5:0] rd_pg_offset;

    logic do_axi_read_work;

    function void set_rd_default();
        hppb_arvalid = 1'b0;
        hppb_arid = 'b0;
        hppb_araddr = 'b0;
        hppb_aruser = 'b0;

        hppb_rready = 1'b1;      // always receive from rresp channel
    endfunction


    assign do_axi_read_work = (~fifo_full) & (rd_pg_num_change || new_rd_pg || (rd_pg_offset != '0));    // to stop the read until the dst finishes transferring this page?    

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            state_rd <= STATE_RD_RESET;
            src_addr_base <= '{default: '0};

            rd_pg_offset <= '0;
            src_addr_new <= '0;
            new_rd_pg <= '0;
        end else begin
            state_rd <= next_state_rd;

            for (int i = 0; i < MIG_GRP_SIZE; i++) begin
                if (mig_done_cnt_incr) begin
                    src_addr_base[i] <= '0;
                end
                if (/*(src_addr_base[i] != src_addr[i]) &*/ new_addr_available) begin       // assuming the src addr can't change until the dst is for sure done
                    src_addr_new[i] <= (src_addr[i] != '0);
                    src_addr_base[i] <= src_addr[i];
                end
            end

            if (rd_pg_num_change) begin
                src_addr_new[new_rd_pg_num] <= 1'b0;
                rd_pg_num <= new_rd_pg_num;
                new_rd_pg <= '1;
            end

            if (hppb_arready & hppb_arvalid & ~rd_pg_num_change) begin
                rd_pg_offset <= rd_pg_offset + 1'b1;
                new_rd_pg <= '0; // new as long as no reads have been accepted (non-zero value indicates rd_pg_offset == '0)
            end
        end
    end


    always_comb begin
        next_state_rd = state_rd;
        unique case(state_rd)
            STATE_RD_RESET: begin
                if (do_axi_read_work) begin
                    next_state_rd = STATE_RD_ADDR;
                end
            end
            STATE_RD_ADDR: begin
                if (~do_axi_read_work && hppb_arready) begin //|| (hppb_arready & hppb_arvalid)) begin
                    next_state_rd = STATE_RD_RESET;
                end
            end
            default:;
        endcase
    end

    always_comb begin
        rd_pg_num_change = (rd_pg_offset == '0) & (~new_rd_pg) & (src_addr_new != '0);
        new_rd_pg_num = '0;
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin                // TODO: Migrates in reverse order = is that okay?
            if (src_addr_new[i] == 1'b1) begin
                new_rd_pg_num = ($clog2(MIG_GRP_SIZE))'(i);
            end
        end

        set_rd_default();
        fifo_wrreq = '0;
        unique case(state_rd)
            STATE_RD_ADDR: begin
                hppb_arvalid = do_axi_read_work & ~rd_pg_num_change & (curr_outstanding_rreq_cnt < 256);  // only a valid request as long as the migration isn't stale (non-zero offset or new page), and there are spots
                hppb_arid = {1'b0, rd_pg_num, rd_pg_offset};
                hppb_aruser = {1'b1, csr_aruser[4:0]}; 
                hppb_araddr = src_addr_base[rd_pg_num] + rd_pg_offset * 512/8;       // byte aligned address
            end
            default:;
        endcase
        fifo_wdata = {hppb_rid[($clog2(MIG_GRP_SIZE)-1) + 6:0], hppb_rdata};
        if (hppb_rready & (hppb_rvalid & hppb_rlast)) begin        // Assuming only one packet at a time, rlast?
            fifo_wrreq = '1;
        end

    end

    

/* ---------------------------------
    AXI Write
-----------------------------------*/

    enum logic [1:0] {
        STATE_WR_RESET,
        STATE_WR_ADDR,
        STATE_WR_DATA
    } state_wr, next_state_wr;

    logic do_axi_write_work;
    logic [511:0] axi_wdata_stored;
    logic [$clog2(PG_NUM_ENTRIES)-1:0] w_req_tracker[MIG_GRP_SIZE];        // FIFO Depth
    logic w_req_tracker_valid[MIG_GRP_SIZE];

    logic [63:0]    dst_addr_base[MIG_GRP_SIZE];

    logic    atleast_one_valid_dst;

    function void set_wr_default();
        hppb_awvalid = 1'b0;
        hppb_awaddr = 'b0;
        hppb_awid = 'b0;
        hppb_awuser = 'b0; 

        hppb_wvalid = 1'b0;
        hppb_wlast = 1'b0;
        hppb_wstrb = 64'h0;

        hppb_bready = 1'b1;      // always receive from bresp channel
    endfunction


    // as long as the fifo has even one element, this should start
    assign do_axi_write_work = ~fifo_empty;

    always_ff @(posedge axi4_mm_clk) begin
        if (!axi4_mm_rst_n) begin
            state_wr <= STATE_WR_RESET;
            dst_addr_base <= '{default: '0};

            // dst_mig_done <= '{default: '0};
            w_req_tracker <= '{default: '0};
            w_req_tracker_valid <= '{default: '0};
            axi_wdata_stored <= '1;

            mig_done_cnt <= '0;
        end

        else begin
            state_wr <= next_state_wr;

            if (hppb_bvalid & hppb_bready) begin
                w_req_tracker[hppb_bid[($clog2(MIG_GRP_SIZE)-1) + 6:6]] <= w_req_tracker[hppb_bid[($clog2(MIG_GRP_SIZE)-1) + 6:6]] + 1'b1;
                w_req_tracker_valid[hppb_bid[($clog2(MIG_GRP_SIZE)-1) + 6:6]] <= '1;
            end

            for (int i = 0; i < MIG_GRP_SIZE; i++) begin
                if (mig_done_cnt_incr) begin
                    mig_done_cnt <= mig_done_cnt + 1'b1;        // only adds a 1 to mig_done_cnt
                    w_req_tracker[i] <= '0;
                    w_req_tracker_valid[i] <= '0;
                    dst_addr_base[i] <= '0;
                end
                if (new_addr_available) begin
                    dst_addr_base[i] <= dst_addr[i];
                end
            end

            if (fifo_rdreq) axi_wdata_stored <= fifo_rdata[511:0];

        end
    end

    always_comb begin
        next_state_wr = state_wr;
        unique case(state_wr)
            STATE_WR_RESET: begin
                if (do_axi_write_work) begin
                    next_state_wr = STATE_WR_ADDR;
                end
            end
            STATE_WR_ADDR: begin
                if (hppb_awvalid & hppb_awready & ~(hppb_wvalid & hppb_wready)) begin
                    next_state_wr = STATE_WR_DATA;
                end else if (~do_axi_write_work) begin  // should never even trigger, the only way WR is in STATE_WR_ADDR is if the FIFO wasn't empty in the previous cycle
                    next_state_wr = STATE_WR_RESET;
                end
            end
            STATE_WR_DATA: begin
                if (hppb_wvalid & hppb_wready) begin
                    next_state_wr = do_axi_write_work ? STATE_WR_ADDR : STATE_WR_RESET;
                end
            end

            default:;
        endcase
    end

    always_comb begin
        set_wr_default();
        fifo_rdreq = '0;
        hppb_wdata = axi_wdata_stored;
        unique case(state_wr)
            STATE_WR_ADDR: begin
                // can't expect to move anything if there's nothing to move or if the page is at address zero: second condition is handled by src already
                hppb_awvalid = ~fifo_empty & (dst_addr_base[fifo_rdata[($clog2(MIG_GRP_SIZE)-1) + 518:518]] != '0);
                hppb_awuser = csr_awuser; 
                hppb_awid = {1'b0, fifo_rdata[($clog2(MIG_GRP_SIZE)-1) + 518:512]};
                hppb_awaddr = dst_addr_base[fifo_rdata[($clog2(MIG_GRP_SIZE)-1) + 518:518]] + fifo_rdata[517:512] * 512/8;       // byte aligned address

                // fifo_rdreq only happens once when handshake occurs
                fifo_rdreq = hppb_awready & ~fifo_empty;

                hppb_wvalid = fifo_rdreq;
                hppb_wlast = 1'b1;
                hppb_wstrb = 64'hffffffffffffffff;

            end
            STATE_WR_DATA: begin
                hppb_wvalid = 1'b1;
                hppb_wlast = 1'b1;
                hppb_wstrb = 64'hffffffffffffffff;
            end

            default:;
        endcase


        mig_done_cnt_incr = '1;
        atleast_one_valid_dst = '0;
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (dst_addr_base[i] != '0) begin
                atleast_one_valid_dst = '1;
            end
        end
        mig_done_cnt_incr = atleast_one_valid_dst;
        // TODO: This might become critical path
        for (int i = 0; (i < MIG_GRP_SIZE); i++) begin
            if (~((w_req_tracker[i] == '0 && w_req_tracker_valid[i] == '1) || dst_addr_base[i] == '0 || src_addr_base[i] == '0)) begin
                mig_done_cnt_incr = '0;     // if anything is not ready, can't increment bro
            end
        end

        atleast_one_valid_src = '0;
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (src_addr_base[i] != '0) begin
                atleast_one_valid_src = '1;
            end
        end
    end


// <--------------------------------------------------------------------------------------------------------------------------------------------------->
// <----------------------------------------------------------------Performance counters--------------------------------------------------------------->
// <--------------------------------------------------------------------------------------------------------------------------------------------------->

    // Full batch based
    // logic [63:0]    min_mig_time;
    // logic [63:0]    max_mig_time;
    logic [63:0]    curr_mig_time;

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            min_mig_time <= '1;
            max_mig_time <= '0;
            curr_mig_time <= '0;
            total_curr_mig_time <= '0;
        end else begin
            if (curr_mig_time > max_mig_time) begin
                max_mig_time <= curr_mig_time;
            end

            if ((src_addr_new != '0) || (curr_mig_time != '0)) begin
                curr_mig_time <= curr_mig_time + 1'b1;
            end
            if (mig_done_cnt_incr) begin
                curr_mig_time <= '0;
                if (curr_mig_time < min_mig_time) begin
                    min_mig_time <= curr_mig_time;
                end
                total_curr_mig_time <= curr_mig_time;
            end
        end
    end

    // page wise
    logic [63:0]    min_mig_page_time[MIG_GRP_SIZE];
    logic [63:0]    max_mig_page_time[MIG_GRP_SIZE];
    logic [63:0]    curr_mig_page_time[MIG_GRP_SIZE];

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            min_mig_page_time <= '{default: '1};
            max_mig_page_time <= '{default: '0};
            curr_mig_page_time <= '{default: '0};
        end else begin
            for (int i = 0; i < MIG_GRP_SIZE; i++) begin
                if (curr_mig_page_time[i] > max_mig_page_time[i]) begin
                    max_mig_page_time[i] <= curr_mig_page_time[i];
                end

                if (src_addr_new[i]) begin
                    curr_mig_page_time[i] <= curr_mig_page_time[i] + 1'b1;
                end
                if (curr_mig_page_time[i] != '0) begin
                    curr_mig_page_time[i] <= curr_mig_page_time[i] + 1'b1;
                end

                if (w_req_tracker[i] == '1 && (dst_addr_base[i] != '0 && src_addr_base[i] != '0)) begin
                    curr_mig_page_time[i] <= '0;
                    if (curr_mig_page_time[i] < min_mig_page_time[i]) begin
                        min_mig_page_time[i] <= curr_mig_page_time[i];
                    end
                end
            end

        end
    end

    assign min_pg0_mig_time = min_mig_page_time[0];
    assign max_pg0_mig_time = max_mig_page_time[0];
    assign min_pgn_mig_time = min_mig_page_time[MIG_GRP_SIZE-1];
    assign max_pgn_mig_time = max_mig_page_time[MIG_GRP_SIZE-1];


    logic [63:0]    curr_fifo_full_cnt;
    // logic [63:0]    max_fifo_full_cnt;
    logic [63:0]    curr_fifo_empty_cnt;
    // logic [63:0]    max_fifo_empty_cnt;

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            max_fifo_full_cnt <= '0;
            curr_fifo_full_cnt <= '0;
            max_fifo_empty_cnt <= '0;
            curr_fifo_empty_cnt <= '0;
        end else begin
            if (curr_fifo_full_cnt > max_fifo_full_cnt) begin
                max_fifo_full_cnt <= curr_fifo_full_cnt;
            end
            if (curr_fifo_empty_cnt > max_fifo_empty_cnt) begin
                max_fifo_empty_cnt <= curr_fifo_empty_cnt;
            end

            if (fifo_full) begin
                curr_fifo_full_cnt <= curr_fifo_full_cnt + 1'b1;
            end

            if (fifo_empty && atleast_one_valid_dst && atleast_one_valid_src) begin
                curr_fifo_empty_cnt <= curr_fifo_empty_cnt + 1'b1;
            end

            if (mig_done_cnt_incr) begin
                curr_fifo_full_cnt <= '0;
                curr_fifo_empty_cnt <= '0;
            end
        end
    end

    logic [63:0]    curr_total_read_cnt;
    // logic [63:0]    max_total_read_cnt;
    logic [63:0]    curr_total_write_cnt;
    // logic [63:0]    max_total_write_cnt;

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            max_total_read_cnt <= '0;
            curr_total_read_cnt <= '0;
            max_total_write_cnt <= '0;
            curr_total_write_cnt <= '0;
        end else begin
            if (curr_total_read_cnt > max_total_read_cnt) begin
                max_total_read_cnt <= curr_total_read_cnt;
            end
            if (src_addr_new != 0) begin
                curr_total_read_cnt <= curr_total_read_cnt + 1'b1;
            end
            if (curr_total_read_cnt != '0) begin
                curr_total_read_cnt <= curr_total_read_cnt + 1'b1;
            end
            if (~(rd_pg_num_change || new_rd_pg || (rd_pg_offset != '0))) begin     // if no further work is needed on read side (do_axi_read_work will be off)
                curr_total_read_cnt <= '0;
            end


            if (curr_total_write_cnt > max_total_write_cnt) begin
                max_total_write_cnt <= curr_total_write_cnt;
            end
            if (~fifo_empty) begin  // from the time the first read response comes
                curr_total_write_cnt <= curr_total_write_cnt + 1'b1;
            end
            if (curr_total_write_cnt != '0) begin
                curr_total_write_cnt <= curr_total_write_cnt + 1'b1;
            end
            if (mig_done_cnt_incr) begin
                curr_total_write_cnt <= '0;
            end
        end
    end

    // logic [63:0]    hppb_rresp_err_cnt;
    // logic [63:0]    hppb_bresp_err_cnt;
    // logic [63:0]    max_outstanding_rreq_cnt;
    // logic [63:0]    max_outstanding_wreq_cnt;

    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            hppb_rresp_err_cnt <= '0;
            hppb_bresp_err_cnt <= '0;
            curr_outstanding_rreq_cnt <= '0;
            max_outstanding_rreq_cnt <= '0;
            curr_outstanding_wreq_cnt <= '0;
            max_outstanding_wreq_cnt <= '0;
        end
        else begin
            if (curr_outstanding_rreq_cnt > max_outstanding_rreq_cnt) begin
                max_outstanding_rreq_cnt <= curr_outstanding_rreq_cnt;
            end
            if (((hppb_arvalid & hppb_arready) & ~(hppb_rvalid & hppb_rready))) begin     // XOR
                curr_outstanding_rreq_cnt <= curr_outstanding_rreq_cnt + 1'b1;
            end
            if ((~(hppb_arvalid & hppb_arready) & (hppb_rvalid & hppb_rready))) begin
                curr_outstanding_rreq_cnt <= curr_outstanding_rreq_cnt - 1'b1;
            end

            if (curr_outstanding_wreq_cnt > max_outstanding_wreq_cnt) begin
                max_outstanding_wreq_cnt <= curr_outstanding_wreq_cnt;
            end
            if (((hppb_awvalid & hppb_awready) & ~(hppb_wvalid & hppb_wready))) begin     // XOR
                curr_outstanding_wreq_cnt <= curr_outstanding_wreq_cnt + 1'b1;
            end
            if ((~(hppb_awvalid & hppb_awready) & (hppb_wvalid & hppb_wready))) begin
                curr_outstanding_wreq_cnt <= curr_outstanding_wreq_cnt - 1'b1;
            end

            if (hppb_bresp != '0) begin
                hppb_bresp_err_cnt  <= hppb_bresp_err_cnt + 1'b1;
            end
            if (hppb_rresp != '0) begin
                hppb_rresp_err_cnt  <= hppb_rresp_err_cnt + 1'b1;
            end

        end
    end


endmodule
