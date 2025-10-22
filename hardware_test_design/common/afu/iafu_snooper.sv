module iafu_snooper

import ed_cxlip_top_pkg::*;
import ed_mc_axi_if_pkg::*;
import mig_params::*;
(
    input  logic                                             afu_clk,
    input  logic                                             afu_rstn,
    input  ed_mc_axi_if_pkg::t_to_mc_axi4    [MC_CHANNEL-1:0] cxlip2iafu_to_mc_axi4,
    input  ed_mc_axi_if_pkg::t_from_mc_axi4  [MC_CHANNEL-1:0] mc2iafu_from_mc_axi4,

    input logic[63:0]                               iafu_snp_page_addr[MIG_GRP_SIZE],
    output logic                                    iafu_snp_inv[4],
    output logic [5:0]                              iafu_snp_pg_off[4],
    output logic [$clog2(MIG_GRP_SIZE)-1:0]         iafu_snp_idx[4]//,

    // input logic[63:0]   other_signals[TBD] 
);


logic[63:0] c0_ar_addr, c1_ar_addr, c0_aw_addr, c1_aw_addr;
logic[511:0] c0_wd_data, c1_wd_data;
logic c0_ar_ready, c0_ar_valid, c1_ar_ready, c1_ar_valid;
logic c0_aw_ready, c0_aw_valid, c1_aw_ready, c1_aw_valid;
logic c0_wd_ready, c0_wd_valid, c1_wd_ready, c1_wd_valid;

assign c0_ar_addr = cxlip2iafu_to_mc_axi4[0].araddr;
assign c0_ar_valid = cxlip2iafu_to_mc_axi4[0].arvalid;
assign c0_ar_ready = mc2iafu_from_mc_axi4[0].arready;
assign c1_ar_addr = cxlip2iafu_to_mc_axi4[1].araddr;
assign c1_ar_valid = cxlip2iafu_to_mc_axi4[1].arvalid;
assign c1_ar_ready = mc2iafu_from_mc_axi4[1].arready;

assign c0_aw_addr = cxlip2iafu_to_mc_axi4[0].awaddr;
assign c0_aw_valid = cxlip2iafu_to_mc_axi4[0].awvalid;
assign c0_aw_ready = mc2iafu_from_mc_axi4[0].awready;
assign c1_aw_addr = cxlip2iafu_to_mc_axi4[1].awaddr;
assign c1_aw_valid = cxlip2iafu_to_mc_axi4[1].awvalid;
assign c1_aw_ready = mc2iafu_from_mc_axi4[1].awready;

assign c0_wd_data = cxlip2iafu_to_mc_axi4[0].wdata;
assign c0_wd_valid = cxlip2iafu_to_mc_axi4[0].wvalid;
assign c0_wd_ready = mc2iafu_from_mc_axi4[0].wready;
assign c1_wd_data = cxlip2iafu_to_mc_axi4[1].wdata;
assign c1_wd_valid = cxlip2iafu_to_mc_axi4[1].wvalid;
assign c1_wd_ready = mc2iafu_from_mc_axi4[1].wready;


// Page snoop logic
always_ff @( posedge afu_clk ) begin 
    if ( !afu_rstn ) begin
        iafu_snp_inv <= '{default: '0};
        iafu_snp_pg_off <= '{default: '0};
        iafu_snp_idx <= '{default: '0};
    end else begin
        iafu_snp_inv <= '{default: '0};
        iafu_snp_pg_off <= '{default: '0};
        iafu_snp_idx <= '{default: '0};

        for (int i = 0; i < MIG_GRP_SIZE; i++) begin
            if (c0_ar_valid & c0_ar_ready & c0_ar_addr[51:12] == iafu_snp_page_addr[i][51:12]) begin
                iafu_snp_inv[0] <= 1'b1;
                iafu_snp_pg_off[0] <= c0_ar_addr[11:6];
                iafu_snp_idx[0] <= i;
            end
            else if (c1_ar_valid & c1_ar_ready & c1_ar_addr[51:12] == iafu_snp_page_addr[i][51:12]) begin
                iafu_snp_inv[1] <= 1'b1;
                iafu_snp_pg_off[1] <= c1_ar_addr[11:6];
                iafu_snp_idx[1] <= i;
            end
            else if (c0_aw_valid & c0_aw_ready & c0_aw_addr[51:12] == iafu_snp_page_addr[i][51:12]) begin
                iafu_snp_inv[2] <= 1'b1;
                iafu_snp_pg_off[2] <= c0_aw_addr[11:6];
                iafu_snp_idx[2] <= i;
            end
            else if (c1_aw_valid & c1_aw_ready & c1_aw_addr[51:12] == iafu_snp_page_addr[i][51:12]) begin
                iafu_snp_inv[3] <= 1'b1;
                iafu_snp_pg_off[3] <= c1_aw_addr[11:6];
                iafu_snp_idx[3] <= i;
            end
        end
    end
end

endmodule