module hot_page_addr_handler
#(
    parameter MIG_GRP_SIZE = 16
)
(
    // HPPB DEBUGGING
        output logic [63:0] csr_hppb_test_mig_done_cnt,

    input logic                     axi4_mm_clk,
    input logic                     axi4_mm_rst_n,

    input logic [511:0]             hapb_wdata,
    input logic                     hapb_wvalid,
    input                           hapb_wready,
    output logic [63:0]             src_addr[MIG_GRP_SIZE/2],
    output logic [63:0]             src_addr1[MIG_GRP_SIZE/2],

    input logic [63:0]              dst_addr_buf_pAddr,      // Fixed after being set to something useful?
    input logic  [63:0]             dst_addr_valid_cnt,     // CSR based?
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

logic [63:0]    old_dst_addr_valid_cnt;

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n) begin
        state_rd <= STATE_RD_RESET;
        // src_addr_storage <= '0;
        dst_read_req_in_progress <= '0;

        old_dst_addr_valid_cnt <= '0;
        addr_pull_req_ptr <= '0;
    end else begin
        state_rd <= next_state_rd;
        // if (hapb_wvalid & hapb_wready) begin
        //     src_addr_storage <= hapb_wdata;
        // end
        if (hppb_dst_arready & hppb_dst_arvalid) begin
            dst_read_req_in_progress <= '1;
            addr_pull_req_ptr <= addr_pull_req_ptr + 1'b1;
        end
        if (hppb_dst_rvalid & hppb_dst_rready & addr_pull_rec_ptr == '1) begin
            dst_read_req_in_progress <= '0;
            old_dst_addr_valid_cnt <= dst_addr_valid_cnt;
        end
    end
end

always_comb begin
    next_state_rd = state_rd;
    unique case (state_rd)
        STATE_RD_RESET:
            if ((old_dst_addr_valid_cnt != dst_addr_valid_cnt && dst_addr_buf_pAddr != '0) && ~dst_read_req_in_progress) begin
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
            hppb_dst_araddr = dst_addr_buf_pAddr + (512*addr_pull_req_ptr)/8;       // byte aligned address
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
        end
    end
end

always_comb begin
    new_addr_available = '0;
    dst_addr = '{default: '0};
    src_addr = '{default: '0};
    src_addr1 = '{default: '0};
    dst_addr1 = '{default: '0};

    new_addr_available = (hppb_dst_rvalid & hppb_dst_rready & (addr_pull_rec_ptr == '1));
    if (new_addr_available) begin
        for (int i = 0; i < MIG_GRP_SIZE/2; i++) begin
            if (i % 2 == 0) begin
                src_addr[i/2] = {20'b0, addr_pull_storage[(i*2)*32 +: 32], 12'b0};
                dst_addr[i/2] = {20'b0, addr_pull_storage[((i*2)+1)*32 +: 32], 12'b0};
            end else begin
                src_addr1[(i-1)/2] <= {20'b0, addr_pull_storage[(i*2)*32 +: 32], 12'b0};
                dst_addr1[(i-1)/2] <= {20'b0, addr_pull_storage[((i*2)+1)*32 +: 32], 12'b0};
            end

            // if (hppb_dst_rdata[(i+1)*32 +: 32] == '0) src_addr[i] = '0;
        end

        for (int i = 0; i < 8; i++) begin       // hppb_dst_rdata last group, addr_pull_storage doesn't have this (save a cycle)
            if (i % 2 == 0) begin
                src_addr[(MIG_GRP_SIZE/8 - 1)*8/2 + i/2] <= {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
                dst_addr[(MIG_GRP_SIZE/8 - 1)*8/2 + i/2] <= {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
            end else begin
                src_addr1[(MIG_GRP_SIZE/8 - 1)*8/2 + (i-1)/2] <= {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
                dst_addr1[(MIG_GRP_SIZE/8 - 1)*8/2 + (i-1)/2] <= {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
            end
            
    //         src_addr1[i] <= {20'b0, hppb_dst_rdata[(i*2)*32 +: 32], 12'b0};
    //         dst_addr1[i] <= {20'b0, hppb_dst_rdata[((i*2)+1)*32 +: 32], 12'b0};
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