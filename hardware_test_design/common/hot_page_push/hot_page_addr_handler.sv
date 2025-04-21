module hot_page_addr_handler
#(
    parameter MIG_GRP_SIZE = 16,
    parameter ADDR_NUM_PAIRS = 512  // huge page
)
(
    // HPPB DEBUGGING
    output logic [63:0]             csr_hppb_test_mig_done_cnt,

    input logic                     axi4_mm_clk,
    input logic                     axi4_mm_rst_n,

    input logic [511:0]             hapb_wdata,
    input logic                     hapb_wvalid,
    input                           hapb_wready,
    output logic [63:0]             src_addr[MIG_GRP_SIZE/2],
    output logic [63:0]             src_addr1[MIG_GRP_SIZE/2],

    input logic [63:0]              addr_pair_buf_pAddr,
    input logic [63:0]              addr_pair_vld_cnt,
    input logic [63:0]              huge_pg_addr_pair,
    output logic [63:0]             dst_addr[MIG_GRP_SIZE/2],
    output logic [63:0]             dst_addr1[MIG_GRP_SIZE/2],
    output logic                    new_addr_available,

    input logic [5:0]               csr_aruser,


    output logic [11:0]             hppb_dst_arid,
    output logic [63:0]             hppb_dst_araddr,
    output logic                    hppb_dst_arvalid,
    output logic [5:0]              hppb_dst_aruser,
    input                           hppb_dst_arready,

    input [11:0]                    hppb_dst_rid,
    input [511:0]                   hppb_dst_rdata,  
    input [1:0]                     hppb_dst_rresp,  // no use: 2'b00: OKAY, 2'b01: EXOKAY, 2'b10: SLVERR
    input                           hppb_dst_rlast,  // no use
    input                           hppb_dst_ruser,  // no use
    input                           hppb_dst_rvalid,
    output logic                    hppb_dst_rready,

    input logic [63:0]              mig_done_cnt        // real mig_done_cnt

);

// Send multiple address requests: 64 addresses (MIG_GRP_SIZE), 8 src-dst pairs => 64/8 = 8 requests
logic [$clog2(MIG_GRP_SIZE/8) - 1:0]     addr_pull_req_ptr, addr_pull_rec_ptr;
logic [(MIG_GRP_SIZE*64) -1 : 0]         addr_pull_storage;

enum logic {
    STATE_RD_RESET,
    STATE_RD_ADDR
} state_rd, next_state_rd;

function void set_rd_default();
    hppb_dst_arvalid = 1'b0;
    hppb_dst_arid = 'b0;
    hppb_dst_araddr = 'b0;
    hppb_dst_aruser = 'b0;

    hppb_dst_rready = 1'b1;      // always receive from rresp channel
endfunction


logic           dst_read_req_in_progress;

// logic [511:0]   src_addr_storage;

logic [63:0]    old_addr_pair_vld_cnt;
logic [63:0]    old_mig_done_cnt;
logic [63:0]    hppb_addr_buf_offset;
logic [63:0]    batch_size;
logic [$clog2(ADDR_NUM_PAIRS/MIG_GRP_SIZE)-1:0]   huge_pg_addr_offset;
logic huge_pg_mig_active;

assign huge_pg_mig_active = addr_pair_vld_cnt[63];

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        state_rd <= STATE_RD_RESET;
        // src_addr_storage <= '0;
        dst_read_req_in_progress <= '0;

        old_addr_pair_vld_cnt <= '0;
        old_mig_done_cnt <= '0;

        addr_pull_req_ptr <= '0;
        hppb_addr_buf_offset <= '0;
        batch_size <= '0;
    end else begin
        state_rd <= next_state_rd;
        old_mig_done_cnt <= mig_done_cnt;
        // if (hapb_wvalid & hapb_wready) begin
        //     src_addr_storage <= hapb_wdata;
        // end
        if (hppb_dst_arready & hppb_dst_arvalid) begin
            dst_read_req_in_progress <= '1;
            addr_pull_req_ptr <= addr_pull_req_ptr + 1'b1;
        end
        if (hppb_dst_rvalid & hppb_dst_rready & addr_pull_rec_ptr == '1) begin
            dst_read_req_in_progress <= '0;
            old_addr_pair_vld_cnt <= addr_pair_vld_cnt;
            hppb_addr_buf_offset <= hppb_addr_buf_offset + 1'b1;
        end
        if (huge_pg_mig_active && new_addr_available) begin
            old_addr_pair_vld_cnt <= addr_pair_vld_cnt;
        end

        if (old_addr_pair_vld_cnt[62:0] != addr_pair_vld_cnt[62:0]) begin
            batch_size <= (addr_pair_vld_cnt - old_addr_pair_vld_cnt);
        end 

        if (hppb_addr_buf_offset == batch_size) begin
            hppb_addr_buf_offset <= '0;
            batch_size <= '0;
        end
    end
end

always_comb begin
    next_state_rd = state_rd;
    unique case (state_rd)
        STATE_RD_RESET:
            if ((( (old_addr_pair_vld_cnt != addr_pair_vld_cnt) 
                || (old_mig_done_cnt != mig_done_cnt && hppb_addr_buf_offset != batch_size) )
                && addr_pair_buf_pAddr != '0)
                && ~dst_read_req_in_progress
                && ~huge_pg_mig_active) begin
                next_state_rd = STATE_RD_ADDR;
            end
        STATE_RD_ADDR:
            if (hppb_dst_arready & hppb_dst_arvalid && addr_pull_req_ptr == '1) begin
                next_state_rd = STATE_RD_RESET;
            end
        default:;
    endcase
end

always_comb begin
    set_rd_default();
    unique case(state_rd)
        STATE_RD_ADDR: begin
            hppb_dst_arvalid = '1;
            hppb_dst_arid = addr_pull_req_ptr;      // Arbiter differentiates
            hppb_dst_aruser = csr_aruser;           // TODO based upon buffer location
            hppb_dst_araddr = addr_pair_buf_pAddr + (512*addr_pull_req_ptr)/8 + (32*16*(hppb_addr_buf_offset*(MIG_GRP_SIZE/8)))/8;       // byte aligned address
        end
        default:;
    endcase
end


always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        addr_pull_rec_ptr <= '0;
    end
    else begin
        if (hppb_dst_rvalid & hppb_dst_rready) begin
            addr_pull_storage[addr_pull_rec_ptr * 512 +: 512] <= hppb_dst_rdata;
            addr_pull_rec_ptr <= addr_pull_rec_ptr + 1'b1;
        end
        if (new_addr_available) begin
            addr_pull_storage <= '0;
            if (huge_pg_mig_active) begin
                huge_pg_addr_offset <= huge_pg_addr_offset + 1'b1;
            end
        end
    end
end

always_comb begin
    new_addr_available = '0;
    dst_addr = '{default: '0};
    src_addr = '{default: '0};
    src_addr1 = '{default: '0};
    dst_addr1 = '{default: '0};

    if (~huge_pg_mig_active) begin
        new_addr_available = (hppb_dst_rvalid & hppb_dst_rready & (addr_pull_rec_ptr == '1));
        if (new_addr_available) begin
            for (int i = 0; i < MIG_GRP_SIZE - 8; i++) begin
                if (i % 2 == 0) begin
                    src_addr[i/2] = {20'b0, addr_pull_storage[(i*2)*32 +: 32], 12'b0};
                    dst_addr[i/2] = {20'b0, addr_pull_storage[((i*2)+1)*32 +: 32], 12'b0};
                end else begin
                    src_addr1[(i-1)/2] = {20'b0, addr_pull_storage[(i*2)*32 +: 32], 12'b0};
                    dst_addr1[(i-1)/2] = {20'b0, addr_pull_storage[((i*2)+1)*32 +: 32], 12'b0};
                end

                // if (hppb_dst_rdata[(i+1)*32 +: 32] == '0) src_addr[i] = '0;
            end

            for (int i = 0; i < 8; i++) begin       // hppb_dst_rdata last group, addr_pull_storage doesn't have this (save a cycle)
                if (i % 2 == 0) begin
                    src_addr[(MIG_GRP_SIZE/8 - 1)*8/2 + i/2] = {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
                    dst_addr[(MIG_GRP_SIZE/8 - 1)*8/2 + i/2] = {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
                end else begin
                    src_addr1[(MIG_GRP_SIZE/8 - 1)*8/2 + (i-1)/2] = {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
                    dst_addr1[(MIG_GRP_SIZE/8 - 1)*8/2 + (i-1)/2] = {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
                end
                
        //         src_addr1[i] <= {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
        //         dst_addr1[i] <= {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
            end
        end
    end else begin
        new_addr_available = (old_addr_pair_vld_cnt[62:0] != addr_pair_vld_cnt[62:0]) || (old_mig_done_cnt != mig_done_cnt && huge_pg_addr_offset != '0);
        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (i % 2 == 0) begin
                src_addr[i/2] = {20'b0, huge_pg_addr_pair[31:0], 12'b0} + i*4096 + huge_pg_addr_offset*MIG_GRP_SIZE*4096;
                dst_addr[i/2] = {20'b0, huge_pg_addr_pair[63:32], 12'b0} + i*4096 + huge_pg_addr_offset*MIG_GRP_SIZE*4096;
            end else begin
                src_addr1[(i-1)/2] = {20'b0, huge_pg_addr_pair[31:0], 12'b0} + i*4096 + huge_pg_addr_offset*MIG_GRP_SIZE*4096;
                dst_addr1[(i-1)/2] = {20'b0, huge_pg_addr_pair[63:32], 12'b0} + i*4096 + huge_pg_addr_offset*MIG_GRP_SIZE*4096;
            end
        end
    end
end


// DEBUGGING/TEST
always_ff @( posedge axi4_mm_clk ) begin
    if (~axi4_mm_rst_n) begin 
        csr_hppb_test_mig_done_cnt <= '0;
    end else begin
        csr_hppb_test_mig_done_cnt <= mig_done_cnt;
    end
end


endmodule