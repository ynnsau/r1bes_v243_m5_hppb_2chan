module wppp_hint_snoop #(
    // The production format is {6'b0, count[15:0], VA[47:6]}.
    // Legacy mode exists only for the pre-translation integration regression,
    // whose stimulus is {count[13:0], direct_PA[49:0]}.
    parameter bit LEGACY_HINT_FORMAT = 1'b0,
    parameter int MAX_HINT_CACHELINES = 128
) (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         host_awvalid,
    input  logic [51:0]  host_awaddr,
    input  logic [511:0] host_wdata,
    input  logic [63:0]  hint_mech_addr,

    output logic         hint_enq_sel,
    output logic [63:0]  hint_enq_address,
    output logic [15:0]  hint_enq_num_of_cl,
    output logic         hint_enq_invalid,

    output logic [63:0]  hint_line_drop_count,
    output logic [63:0]  hint_line_full_cycle_count,
    output logic [63:0]  hint_line_full_episode_count
);
    logic [$clog2(512/64)-1:0] hint_mech_data_ptr;
    logic                       hint_mech_valid;
    logic [511:0]               hint_mech_data;
    logic                       wppp_sel;
    logic [63:0]                active_hint_word;
    logic [15:0]                active_hint_count;
    logic                       hint_page_write;

    // Project integration contract: the host presents and handshakes AW and W
    // synchronously for writes observed by this snoop. Consequently the active
    // production logic qualifies the capture with AWVALID and samples WDATA in
    // that cycle; it does not independently pair AXI AW and W transactions.
    assign hint_enq_sel = wppp_sel;
    assign active_hint_word =
        hint_mech_data[(hint_mech_data_ptr * 64) +: 64];
    assign active_hint_count = LEGACY_HINT_FORMAT ?
        {2'b0, active_hint_word[63:50]} : active_hint_word[57:42];
    assign hint_page_write = host_awvalid &&
        (hint_mech_addr[51:12] == host_awaddr[51:12]);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hint_mech_data_ptr <= '0;
            hint_mech_valid <= 1'b0;
            hint_mech_data <= '0;
            wppp_sel <= 1'b1;
            hint_line_drop_count <= '0;
            hint_line_full_cycle_count <= '0;
            hint_line_full_episode_count <= '0;
        end else begin
            if (hint_mech_valid) begin
                hint_mech_data_ptr <= hint_mech_data_ptr + 1'b1;
                wppp_sel <= ~wppp_sel;
                hint_line_full_cycle_count <=
                    hint_line_full_cycle_count + 1'b1;
            end

            if (hint_mech_data_ptr == '1) begin
                hint_mech_valid <= 1'b0;
            end

            // The configured address identifies a 4 KiB hint page. Any write
            // within that page carries eight packed 64-bit hint entries.
            if (hint_page_write) begin
                if (!hint_mech_valid) begin
                    hint_mech_data_ptr <= '0;
                    hint_mech_valid <= 1'b1;
                    hint_mech_data <= host_wdata;
                    wppp_sel <= ~wppp_sel;
                    hint_line_full_episode_count <=
                        hint_line_full_episode_count + 1'b1;
                end else begin
                    // The first version intentionally has one line of ingress
                    // storage.  A host write that arrives while it is occupied
                    // is discarded as one complete hint line.
                    hint_line_drop_count <= hint_line_drop_count + 1'b1;
                end
            end
        end
    end

    always_comb begin
        hint_enq_address = '0;
        hint_enq_num_of_cl = '0;
        hint_enq_invalid = 1'b0;
        if (hint_mech_valid) begin
            if (LEGACY_HINT_FORMAT) begin
                hint_enq_address = {14'b0, active_hint_word[49:0]};
                hint_enq_num_of_cl = active_hint_count;
            end else begin
                hint_enq_invalid =
                    (active_hint_count != 0) &&
                    ((active_hint_word[63:58] != 0) ||
                     (active_hint_count > 16'(MAX_HINT_CACHELINES)));
                if (!hint_enq_invalid) begin
                    hint_enq_address = {16'b0, active_hint_word[41:0], 6'b0};
                    hint_enq_num_of_cl = active_hint_count;
                end
            end
        end
    end
endmodule
