// HPP = Hot Page Pusher

module auto_hot_page_push
import mig_params::*;
(

    input logic                             axi4_mm_clk,
    input logic                             axi4_mm_rst_n,

    // // Migration done incrementing counter
    input logic                             clst_invalidate,
    input logic  [5:0]                      clst_page_offset,           // assuming all special logic is handled outside, this is just page offset

    output logic[63:0]                      iafu_snp_page_addr,
    input logic                             iafu_snp_inv[4],
    input logic [5:0]                       iafu_snp_pg_off[4],
    input logic [$clog2(MIG_GRP_SIZE)-1:0]  iafu_snp_idx[4],

    output logic [63:0]                     mig_done_cnt,

    input logic [5:0]                       csr_aruser,
    input logic [5:0]                       csr_awuser,

    input logic [63:0]                      src_addr,               // hot addr from m5
    input logic [63:0]                      dst_addr,               // auto push data head, NEEDS to be different for each instance
    input logic                             new_addr_available,     
    // indicates dst_addr change as well (dst_addr can be common for each instance of pusher?)

    input logic [1:0]                       ack_sts,

// read address channel
    output logic [11:0]                     ahppb_arid,
    output logic [63:0]                     ahppb_araddr,
    output logic [5:0]                      ahppb_aruser,   // 4'b0000": non-cacheable, 4'b0001: cacheable shared, 4'b0010: cacheable owned
    output logic                            ahppb_arvalid,
    output logic                            ahppb_arvalid_intended,
    input                                   ahppb_arready,

// read response channel
    input [11:0]                            ahppb_rid,
    input [511:0]                           ahppb_rdata,  
    input [1:0]                             ahppb_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                                   ahppb_rlast,  // no use
    input                                   ahppb_ruser,  // no use
    input                                   ahppb_rvalid,
    output logic                            ahppb_rready,

// write address channel
    output logic [11:0]                     ahppb_awid,
    output logic [63:0]                     ahppb_awaddr, 
    output logic [5:0]                      ahppb_awuser,
    output logic                            ahppb_awvalid,
    input                                   ahppb_awready,

// write data channel
    output logic [511:0]                    ahppb_wdata,
    output logic [(512/8)-1:0]              ahppb_wstrb,
    output logic                            ahppb_wlast,
    output logic                            ahppb_wvalid,
    input                                   ahppb_wready,

// write response channel
    input [11:0]                            ahppb_bid,
    input [1:0]                             ahppb_bresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input [3:0]                             ahppb_buser,  // must be tied to 4'b0000
    input                                   ahppb_bvalid,
    output logic                            ahppb_bready,

    input logic [MIG_GRP_ID_SIZE:0]         pusher_pos,

    output logic                            ahppb_ack_wait
);

// FIFO: [517:512] == offset within page (page size is always 4096), [511:0] == actual pg data
// ARID-RID [11:0]:  [10] == read_type, [MIG_GRP_ID_SIZE + 6:6] == pg number, [5:0] = offset within page
// AWID-WID [11:0]:  ....               [MIG_GRP_ID_SIZE + 6:6] == pg number, [5:0] = offset within page

// read type:
// 1'b0 = cache-own read, issued during copy_type == '0 sequentially
// 1'b1 = non-cache read, issued during copy_type == '1 sequentially

// HPPB FIFO
    logic                               fifo_wrreq, fifo_rdreq, fifo_full, fifo_empty;
    logic [517:0]                       fifo_rdata, fifo_wdata; // page_offset, data
    logic                               nack_raised;
    logic                               ack_raised;

    enum logic {
        STATE_RD_RESET,
        STATE_RD_ADDR
    } state_rd, next_state_rd;
    
    typedef enum bit {
        cache_own_rd_code  = 1'b0,
        non_cache_rd_code  = 1'b1
    } read_code_type;

    logic                               mig_done_cnt_incr;
    logic                               mig_is_ongoing;

    logic [1:0]                         old_ack_sts;
    logic                               just_started_rd;

    logic [63:0]                        src_addr_base;
    logic [5:0]                         rd_pg_offset;

    logic                               do_axi_read_work;
    logic [511:0]                       ahppb_rdata_reg1, ahppb_rdata_reg2, bram_rdata;
    logic [11:0]                        ahppb_rid_reg1, ahppb_rid_reg2;
    logic                               ahppb_rvld_reg1, ahppb_rvld_reg2;
    logic                               update_bram;
    logic [PG_NUM_ENTRIES - 1:0]        local_data_array_vld;
    logic [PG_NUM_ENTRIES - 1:0]        data_array_dirty;

    logic                               copy_type;   // 0 == initial, 1 == post-ack
    logic                               new_data_in_bram, stale_data_in_bram;

    enum logic [1:0] {
        STATE_WR_RESET,
        STATE_WR_ADDR,
        STATE_WR_DATA
    } state_wr, next_state_wr;

    logic                               do_axi_write_work;
    logic [511:0]                       axi_wdata_stored;
    logic [63:0]                        dst_addr_base;

    logic [63:0]                        curr_wreq_cnt;
    logic [63:0]                        curr_rreq_cnt;
    logic                               wait_for_outgoing_req_to_die;       // if NACK happens randomly

    (* preserve_for_debug *) logic      ack_sts_change /* synthesis keep */;

    logic rd_pg_offset_non_zero;

    fifo_ahppb fifo_ahppb_data (
        .aclr (~axi4_mm_rst_n || nack_raised),
        .data  (fifo_wdata),    //   input,  width = 518,  fifo_input.datain
        .wrreq (fifo_wrreq),    //   input,    width = 1,            .wrreq
        .rdreq (fifo_rdreq),    //   input,    width = 1,            .rdreq
        .clock (axi4_mm_clk),   //   input,    width = 1,            .clk
        .q     (fifo_rdata),    //   output, width = 518, fifo_output.dataout
        .full  (fifo_full),     //   output,   width = 1,            .full
        .empty (fifo_empty)     //   output,   width = 1,            .empty
    );

    assign ack_sts_change = old_ack_sts != ack_sts;
    assign  ack_raised  = mig_is_ongoing && (old_ack_sts != ack_sts) && (ack_sts == 2'b01);   // TODO assumes that sts only changes once per batch
    assign  nack_raised = mig_is_ongoing && (old_ack_sts != ack_sts) && (ack_sts == 2'b10);

/* ---------------------------------
    AXI Read
-----------------------------------*/

	bram_ahppb bram_ahppb (
		.data      (stale_data_in_bram ? ahppb_rdata_reg2 : ahppb_rdata),      //   input,  width = 512,      data.datain
		.q         (bram_rdata),         //  output,  width = 512,         q.dataout
		.wraddress (ahppb_rid[5:0]), //   input,    width = 6, wraddress.wraddress
		.rdaddress (ahppb_rid[5:0]), //   input,    width = 6, rdaddress.rdaddress
		.wren      (update_bram),      //   input,    width = 1,      wren.wren
		.clock     (axi4_mm_clk)      //   input,    width = 1,     clock.clk
	);


    assign  update_bram =  mig_is_ongoing & (~nack_raised) & 
                            (new_data_in_bram || stale_data_in_bram);
    assign new_data_in_bram = (ahppb_rready & ahppb_rvalid & (copy_type == 1'b0));      // basically when the data is really "new"
    assign stale_data_in_bram = (ahppb_rvld_reg2 && copy_type == 1'b1 
                                && ahppb_rid_reg2[10] == non_cache_rd_code 
                                && (local_data_array_vld[ahppb_rid_reg2[5:0]] == '0 
                                    || bram_rdata != ahppb_rdata_reg2));    // no need to "update the bram data" itself in this case

    function void set_rd_default();
        ahppb_arvalid = 1'b0;
        ahppb_arid = 'b0;
        ahppb_araddr = 'b0;
        ahppb_aruser = 'b0;

        ahppb_rready = 1'b0;
    endfunction


    assign debug_signal_3 = ~fifo_full & mig_is_ongoing & ~nack_raised;
    assign debug_signal_4 = src_addr_base != '0;
    assign debug_signal_5 = just_started_rd || (rd_pg_offset != '0);
    assign do_axi_read_work =   ~fifo_full & (src_addr_base != '0) & mig_is_ongoing & ~nack_raised 
                                & (just_started_rd || (rd_pg_offset_non_zero));


    always_ff @( posedge axi4_mm_clk ) begin
        if (!axi4_mm_rst_n) begin
            state_rd <= STATE_RD_RESET;
            rd_pg_offset <= '0;
            rd_pg_offset_non_zero <= '0;
            src_addr_base <= '0;
            copy_type <= 1'b0;
            just_started_rd <= '0;

            local_data_array_vld <= '{default: '0};
            data_array_dirty <= '{default: '0};
            old_ack_sts <= '0;

            ahppb_rdata_reg1 <= '0;
            ahppb_rid_reg1 <= '0;
            ahppb_rvld_reg1 <= '0;
            ahppb_rdata_reg2 <= '0;
            ahppb_rid_reg2 <= '0;
            ahppb_rvld_reg2 <= '0;
            iafu_snp_page_addr <= '0;

        end else begin
            state_rd <= next_state_rd;
            old_ack_sts <= ack_sts;

            ahppb_rdata_reg1 <= ahppb_rdata;
            ahppb_rid_reg1 <= ahppb_rid;
            ahppb_rvld_reg1 <= ahppb_rready & ahppb_rvalid;
            ahppb_rdata_reg2 <= ahppb_rdata_reg1;
            ahppb_rid_reg2 <= ahppb_rid_reg1;
            ahppb_rvld_reg2 <= ahppb_rvld_reg1;

            if (new_addr_available) begin       // assuming the src addr can't change until the dst is for sure done
                src_addr_base <= src_addr;
                just_started_rd <= src_addr != '0;
            end

            if (ahppb_arready & (state_rd == STATE_RD_ADDR && do_axi_read_work)) begin
                rd_pg_offset <= rd_pg_offset + 1'b1;        // gets overwritten to 0 if ACK/NACK happened
                just_started_rd <= '0;
                if (rd_pg_offset == '0) begin
                    rd_pg_offset_non_zero <= '1;
                end else if (rd_pg_offset == '1) begin
                    rd_pg_offset_non_zero <= '0;
                end
            end
            if (update_bram) begin
                if (new_data_in_bram) begin
                    local_data_array_vld[ahppb_rid[5:0]] <= '1;
                end else if (stale_data_in_bram) begin
                    local_data_array_vld[ahppb_rid_reg2[5:0]] <= '1;
                end
            end

            if (ack_raised) begin
                copy_type <= 1'b1;
                rd_pg_offset <= '0;
                rd_pg_offset_non_zero <= '0;
                just_started_rd <= '1;
            end

            if (mig_is_ongoing) begin
                iafu_snp_page_addr <= src_addr_base;       // byte aligned address
                for (int i = 0; i < 4; i++) begin
                    if (iafu_snp_idx[i] == pusher_pos && iafu_snp_inv[i]) begin
                        data_array_dirty[iafu_snp_pg_off[i]] <= '1;
                    end
                end
            end

            if (mig_done_cnt_incr || nack_raised) begin  // mig_is_done only if copy_type == 1
                iafu_snp_page_addr <= '0;
                old_ack_sts <= '0;
                copy_type <= 1'b0;
                rd_pg_offset <= '0;
                rd_pg_offset_non_zero <= '0;
                just_started_rd <= '0;
                src_addr_base <= '0;
                local_data_array_vld <= '{default: '0};     // important, otherwise we might be breaking fifo_wrreq assumptions if data is repeated b/w pages
                data_array_dirty <= '{default: '0};
            end
        end
    end

// FSM Reads
    always_comb begin
        next_state_rd = state_rd;
        unique case(state_rd)
            STATE_RD_RESET: begin
                if (do_axi_read_work) begin
                    next_state_rd = STATE_RD_ADDR;
                end
            end
            STATE_RD_ADDR: begin
                if (~do_axi_read_work/* && ahppb_arready*/) begin
                    next_state_rd = STATE_RD_RESET;
                end
            end
            default:;
        endcase
    end

// Reads AXI signals + FIFO enqueue
    always_comb begin
        ahppb_arvalid_intended = '0;
        set_rd_default();
        ahppb_rready = 1'b1;// always receive from rresp channel
        unique case(state_rd)
            STATE_RD_ADDR: begin
                ahppb_arvalid_intended = do_axi_read_work;
                ahppb_arvalid = do_axi_read_work & (~local_data_array_vld[rd_pg_offset] | data_array_dirty[rd_pg_offset]);
                ahppb_araddr = src_addr_base + rd_pg_offset * 512/8;       // byte aligned address
                if (copy_type == 1'b0) begin
                    ahppb_arid = {1'b0, cache_own_rd_code, {(4 - (MIG_GRP_ID_SIZE + 1)){1'b0}}, pusher_pos, rd_pg_offset};
                    ahppb_aruser = {1'b1, 1'b0, 4'b0010};
                end else begin
                    ahppb_arid = {1'b0, non_cache_rd_code, {(4 - (MIG_GRP_ID_SIZE + 1)){1'b0}}, pusher_pos, rd_pg_offset};
                    ahppb_aruser = {1'b1, 1'b0, 4'b0000};
                end
            end
            default:;
        endcase

        fifo_wdata = {ahppb_rid[5:0], ahppb_rdata};
        fifo_wrreq = update_bram && new_data_in_bram;

        if (copy_type == 1'b1) begin
            fifo_wdata = {ahppb_rid_reg2[5:0], ahppb_rdata_reg2};
            fifo_wrreq = update_bram && stale_data_in_bram;
        end


    end

    

/* ---------------------------------
    AXI Write
-----------------------------------*/

    function void set_wr_default();
        ahppb_awvalid = 1'b0;
        ahppb_awaddr = 'b0;
        ahppb_awid = 'b0;
        ahppb_awuser = 'b0; 

        ahppb_wvalid = 1'b0;
        ahppb_wlast = 1'b1;
        ahppb_wstrb = 64'hffffffffffffffff;

        ahppb_bready = 1'b1;      // always receive from bresp channel
    endfunction


    // as long as the fifo has even one element, this should start
    assign do_axi_write_work = ~fifo_empty && (dst_addr_base != '0);

    always_ff @(posedge axi4_mm_clk) begin
        if (!axi4_mm_rst_n) begin
            state_wr <= STATE_WR_RESET;
            dst_addr_base <= '{default: '0};
            axi_wdata_stored <= '1;
        end

        else begin
            state_wr <= next_state_wr;
            if (mig_done_cnt_incr || nack_raised) begin
                dst_addr_base <= '0;        // not needed, just for safety
            end
            if (new_addr_available) begin
                dst_addr_base <= dst_addr;
            end
            if (fifo_rdreq) begin
                axi_wdata_stored <= fifo_rdata[511:0];
            end

        end
    end

// FSM Writes
    always_comb begin
        next_state_wr = state_wr;
        unique case(state_wr)
            STATE_WR_RESET: begin
                if (do_axi_write_work) begin
                    next_state_wr = STATE_WR_ADDR;
                end
            end
            STATE_WR_ADDR: begin
                if (ahppb_awvalid & ahppb_awready & ~(ahppb_wvalid & ahppb_wready)) begin
                    next_state_wr = STATE_WR_DATA;
                end else if (~do_axi_write_work) begin  // should never even trigger, the only way WR is in STATE_WR_ADDR is if the FIFO wasn't empty in the previous cycle
                    next_state_wr = STATE_WR_RESET;
                end
            end
            STATE_WR_DATA: begin
                if (ahppb_wvalid & ahppb_wready) begin
                    next_state_wr = do_axi_write_work ? STATE_WR_ADDR : STATE_WR_RESET;
                end
            end

            default:;
        endcase
    end

// Writes AXI signals + FIFO dequeue
    always_comb begin
        set_wr_default();
        fifo_rdreq = '0;
        // this is basically the "data from the top", fifo_rd == popping this data (only works because this fifo's reads are configured combinational)
        ahppb_wdata = axi_wdata_stored; 
        unique case(state_wr)
            STATE_WR_ADDR: begin
                // can't expect to move anything if there's nothing to move or if the page is at address zero: second condition is handled by src already
                ahppb_awvalid = ~fifo_empty;
                ahppb_awuser = csr_awuser; 
                ahppb_awid = {1'b0, pusher_pos, fifo_rdata[517:512]};
                ahppb_awaddr = dst_addr_base + fifo_rdata[517:512] * 512/8;       // byte aligned address

                // fifo_rdreq only happens once when handshake occurs
                fifo_rdreq = ahppb_awready & ahppb_awvalid;

                ahppb_wvalid = fifo_rdreq;
            end
            STATE_WR_DATA: begin
                ahppb_wvalid = 1'b1;
            end

            default:;
        endcase
    end


    assign ahppb_ack_wait = ~mig_is_ongoing || ((~do_axi_read_work && ~do_axi_write_work) 
                            && (copy_type == 1'b0) && ~ack_raised && ~nack_raised);

// MIGRATION DONE LOGIC
    always_ff @(posedge axi4_mm_clk) begin : blockName
        if (~axi4_mm_rst_n) begin
            curr_rreq_cnt <= '0;
            curr_wreq_cnt <= '0;

            mig_done_cnt <= '0;
            mig_is_ongoing <= '0;
            wait_for_outgoing_req_to_die <= '0;
        end else begin
            if (((ahppb_arvalid & ahppb_arready) & ~(ahppb_rvalid & ahppb_rready))) begin     // XOR
                curr_rreq_cnt <= curr_rreq_cnt + 1'b1;
            end else if ((~(ahppb_arvalid & ahppb_arready) & (ahppb_rvalid & ahppb_rready))) begin
                curr_rreq_cnt <= curr_rreq_cnt - 1'b1;
            end

            if (((ahppb_wvalid & ahppb_wready) & ~(ahppb_bvalid & ahppb_bready))) begin     // XOR
                curr_wreq_cnt <= curr_wreq_cnt + 1'b1;
            end else if ((~(ahppb_wvalid & ahppb_wready) & (ahppb_bvalid & ahppb_bready))) begin
                curr_wreq_cnt <= curr_wreq_cnt - 1'b1;
            end

            if (new_addr_available) begin
                mig_is_ongoing <= src_addr != '0 && dst_addr != '0;
            end
            if  (nack_raised && (curr_wreq_cnt != '0 || curr_rreq_cnt != '0)) begin
                wait_for_outgoing_req_to_die <= '1;
            end
            if (curr_rreq_cnt == '0 && curr_wreq_cnt == '0) begin
                wait_for_outgoing_req_to_die <= '0;
            end
            if (mig_done_cnt_incr || (nack_raised && curr_wreq_cnt == '0 && curr_rreq_cnt == '0)) begin
                mig_done_cnt <= mig_done_cnt + 1'b1;        // only adds a 1 to mig_done_cnt
                mig_is_ongoing <= '0;
            end
        end
    end
    always_comb begin
        mig_done_cnt_incr = (   mig_is_ongoing && (copy_type == 1'b1 && ~just_started_rd) && 
                                (curr_rreq_cnt == '0 && ~do_axi_read_work) && (curr_wreq_cnt == '0 && ~do_axi_write_work))
                            || (wait_for_outgoing_req_to_die && curr_rreq_cnt == '0 && curr_wreq_cnt == '0) // this allows inflight requests to be responded to, only works if a NACK happened at some point
                            || (new_addr_available && (src_addr == '0 || dst_addr == '0)); // this is to allow fine-grained pusher control
    end                      // if src/dst == 0, then mig_done_cnt will be incremented


endmodule
