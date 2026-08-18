module wppp_integration_top (
    input logic clk,
    input logic rst_n,

    // Host-originated CXL.mem traffic. The wrapper mirrors the production AFU
    // pass-through while observing channel-0 writes for the hint mechanism.
    axi_ports.ar_resp host_cxl_r_ch,
    axi_ports.aw_resp host_cxl_w_ch,
    axi_ports.ar_req  host_mc_r_ch,
    axi_ports.aw_req  host_mc_w_ch,

    // WPPP requests at the CXL-facing side of the final production arbiters.
    axi_ports.ar_req cxl_wppp0_r_ch,
    axi_ports.aw_req cxl_wppp0_w_ch,
    axi_ports.ar_req cxl_wppp1_r_ch,
    axi_ports.aw_req cxl_wppp1_w_ch,

    input logic [63:0] hint_mech_addr,
    input logic [63:0] cxl_start_pa,
    input logic [33:0] address_lower,
    input logic [33:0] address_span,
    input logic        enable_wppp,
    input logic        flush_lut,

    output logic [63:0] prefetch_ok_cnt_0,
    output logic [63:0] prefetch_ok_cnt_1,
    output logic        hppb_activity,
    output logic        hint_enq_sel_debug,
    output logic [63:0] hint_enq_address_debug,
    output logic [15:0] hint_enq_count_debug
);
    localparam int MIG_GRP_SIZE = 32;

    logic hint_enq_sel_i;
    logic [63:0] hint_enq_address_i;
    logic [15:0] hint_enq_num_of_cl_i;
    logic hint_enq_sel_o;
    logic [63:0] hint_enq_address_o;
    logic [15:0] hint_enq_num_of_cl_o;

    logic enqueue_valid_0;
    logic enqueue_valid_1;
    logic [63:0] hppb_src_addr [MIG_GRP_SIZE];
    logic [63:0] hppb_dst_addr [MIG_GRP_SIZE];

    axi_ports wppp_axi0_ports();
    axi_ports wppp_axi1_ports();
    axi_ports hppb_idle0_ports();
    axi_ports hppb_idle1_ports();

    axi_passthrough host_passthrough (
        .upstream_r(host_cxl_r_ch),
        .upstream_w(host_cxl_w_ch),
        .downstream_r(host_mc_r_ch),
        .downstream_w(host_mc_w_ch)
    );

    wppp_hint_snoop hint_snoop (
        .clk(clk),
        .rst_n(rst_n),
        .host_awvalid(host_cxl_w_ch.awvalid),
        .host_awaddr(host_cxl_w_ch.awaddr[51:0]),
        .host_wdata(host_cxl_w_ch.wdata),
        .hint_mech_addr(hint_mech_addr),
        .hint_enq_sel(hint_enq_sel_i),
        .hint_enq_address(hint_enq_address_i),
        .hint_enq_num_of_cl(hint_enq_num_of_cl_i)
    );

    for (genvar i = 0; i < MIG_GRP_SIZE; i++) begin : HPPB_INPUT_TIEOFF
        assign hppb_src_addr[i] = '0;
        assign hppb_dst_addr[i] = '0;
    end

    page_tbl_update #(
        .MIG_GRP_SIZE(MIG_GRP_SIZE)
    ) page_tbl_update_inst (
        .clk(clk),
        .rst_n(rst_n),
        .hppb_tbl_update(1'b0),
        .hppb_src_addr(hppb_src_addr),
        .hppb_dst_addr(hppb_dst_addr),
        .hint_enq_sel_i(hint_enq_sel_i),
        .hint_enq_address_i(hint_enq_address_i),
        .hint_enq_num_of_cl_i(hint_enq_num_of_cl_i),
        .hint_enq_sel_o(hint_enq_sel_o),
        .hint_enq_address_o(hint_enq_address_o),
        .hint_enq_num_of_cl_o(hint_enq_num_of_cl_o)
    );

    assign enqueue_valid_0 =
        (hint_enq_address_o != '0) && (hint_enq_sel_o == 1'b0);
    assign enqueue_valid_1 =
        (hint_enq_address_o != '0) && (hint_enq_sel_o == 1'b1);

    assign hint_enq_sel_debug = hint_enq_sel_o;
    assign hint_enq_address_debug = hint_enq_address_o;
    assign hint_enq_count_debug = hint_enq_num_of_cl_o;

    wppprefetch_rw_pipeline_v2 wppp_engine_0 (
        .axi4_mm_clk(clk),
        .axi4_mm_rst_n(rst_n),
        .wppp_axi_r_ch(wppp_axi0_ports.ar_req),
        .wppp_axi_w_ch(wppp_axi0_ports.aw_req),
        .csr_aruser(6'b0),
        .csr_awuser(7'b0),
        .start_address_i(cxl_start_pa),
        .enable_prefetch_i(enable_wppp),
        .address_lower_i(address_lower),
        .address_upper_i(address_span),
        .enqueue_valid_i(enqueue_valid_0),
        .enqueue_address_i(hint_enq_address_o),
        .enqueue_num_of_cl_i(hint_enq_num_of_cl_o),
        .clst_d1_tvalid(1'b0),
        .clst_d1_tdata('0),
        .csr_flush_lut(flush_lut),
        .prefetch_rw_curr_state(),
        .curr_working_address(),
        .addr_seen(1'b0),
        .abort_op(1'b0),
        .prefetch_abt_cnt(),
        .prefetch_ok_cnt(prefetch_ok_cnt_0),
        .addr_issued(),
        .get_next_addr(),
        .faraddr(),
        .farvalid(),
        .frvalid(1'b1),
        .frdata(1'b1)
    );

    wppprefetch_rw_pipeline_v2 wppp_engine_1 (
        .axi4_mm_clk(clk),
        .axi4_mm_rst_n(rst_n),
        .wppp_axi_r_ch(wppp_axi1_ports.ar_req),
        .wppp_axi_w_ch(wppp_axi1_ports.aw_req),
        .csr_aruser(6'b0),
        .csr_awuser(7'b0),
        .start_address_i(cxl_start_pa),
        .enable_prefetch_i(enable_wppp),
        .address_lower_i(address_lower),
        .address_upper_i(address_span),
        .enqueue_valid_i(enqueue_valid_1),
        .enqueue_address_i(hint_enq_address_o),
        .enqueue_num_of_cl_i(hint_enq_num_of_cl_o),
        .clst_d1_tvalid(1'b0),
        .clst_d1_tdata('0),
        .csr_flush_lut(flush_lut),
        .prefetch_rw_curr_state(),
        .curr_working_address(),
        .addr_seen(1'b0),
        .abort_op(1'b0),
        .prefetch_abt_cnt(),
        .prefetch_ok_cnt(prefetch_ok_cnt_1),
        .addr_issued(),
        .get_next_addr(),
        .faraddr(),
        .farvalid(),
        .frvalid(1'b1),
        .frdata(1'b1)
    );

    // Keep the production final arbitration layer in the verification path.
    // The HPPB client is explicitly inactive in this integration scope.
    axi_r_stub hppb_r_stub_0 (.axi_r_ch(hppb_idle0_ports.ar_req));
    axi_w_stub hppb_w_stub_0 (.axi_w_ch(hppb_idle0_ports.aw_req));
    axi_r_stub hppb_r_stub_1 (.axi_r_ch(hppb_idle1_ports.ar_req));
    axi_w_stub hppb_w_stub_1 (.axi_w_ch(hppb_idle1_ports.aw_req));

    axi_arbiter #(.ARB_BIT_POS(11)) final_arbiter_0 (
        .axi4_mm_clk(clk),
        .axi4_mm_rst_n(rst_n),
        .axi_r_ch(cxl_wppp0_r_ch),
        .axi_w_ch(cxl_wppp0_w_ch),
        .p0_axi_r_ch(wppp_axi0_ports.ar_resp),
        .p0_axi_w_ch(wppp_axi0_ports.aw_resp),
        .p1_axi_r_ch(hppb_idle0_ports.ar_resp),
        .p1_axi_w_ch(hppb_idle0_ports.aw_resp)
    );

    axi_arbiter #(.ARB_BIT_POS(11)) final_arbiter_1 (
        .axi4_mm_clk(clk),
        .axi4_mm_rst_n(rst_n),
        .axi_r_ch(cxl_wppp1_r_ch),
        .axi_w_ch(cxl_wppp1_w_ch),
        .p0_axi_r_ch(wppp_axi1_ports.ar_resp),
        .p0_axi_w_ch(wppp_axi1_ports.aw_resp),
        .p1_axi_r_ch(hppb_idle1_ports.ar_resp),
        .p1_axi_w_ch(hppb_idle1_ports.aw_resp)
    );

    always_comb begin
        hppb_activity = hppb_idle0_ports.arvalid ||
                        hppb_idle0_ports.awvalid ||
                        hppb_idle0_ports.wvalid ||
                        hppb_idle1_ports.arvalid ||
                        hppb_idle1_ports.awvalid ||
                        hppb_idle1_ports.wvalid;
    end

    always_ff @(posedge clk) begin
        if (rst_n && hppb_activity) begin
            $error("WPPP_INT_CHECK_ERROR: inactive HPPB client generated AXI traffic");
        end
    end
endmodule
