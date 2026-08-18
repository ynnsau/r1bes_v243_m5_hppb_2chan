module wppp_hint_snoop (
    input  logic         clk,
    input  logic         rst_n,

    input  logic         host_awvalid,
    input  logic [51:0]  host_awaddr,
    input  logic [511:0] host_wdata,
    input  logic [63:0]  hint_mech_addr,

    output logic         hint_enq_sel,
    output logic [63:0]  hint_enq_address,
    output logic [15:0]  hint_enq_num_of_cl
);
    logic [$clog2(512/64)-1:0] hint_mech_data_ptr;
    logic                       hint_mech_valid;
    logic [511:0]               hint_mech_data;
    logic                       wppp_sel;

    // Project integration contract: the host presents and handshakes AW and W
    // synchronously for writes observed by this snoop. Consequently the active
    // production logic qualifies the capture with AWVALID and samples WDATA in
    // that cycle; it does not independently pair AXI AW and W transactions.
    assign hint_enq_sel = wppp_sel;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hint_mech_data_ptr <= '0;
            hint_mech_valid <= 1'b0;
            hint_mech_data <= '0;
            wppp_sel <= 1'b1;
        end else begin
            if (hint_mech_valid) begin
                hint_mech_data_ptr <= hint_mech_data_ptr + 1'b1;
                wppp_sel <= ~wppp_sel;
            end

            if (hint_mech_data_ptr == '1) begin
                hint_mech_valid <= 1'b0;
            end

            // The configured address identifies a 4 KiB hint page. Any write
            // within that page carries eight packed 64-bit hint entries.
            if (host_awvalid &&
                (hint_mech_addr[51:12] == host_awaddr[51:12])) begin
                hint_mech_data_ptr <= '0;
                hint_mech_valid <= 1'b1;
                hint_mech_data <= host_wdata;
                wppp_sel <= ~wppp_sel;
            end
        end
    end

    always_comb begin
        hint_enq_address = '0;
        hint_enq_num_of_cl = '0;
        if (hint_mech_valid) begin
            hint_enq_address =
                hint_mech_data[(hint_mech_data_ptr * 64) +: 50];
            hint_enq_num_of_cl =
                hint_mech_data[((hint_mech_data_ptr * 64) + 50) +: 14];
        end
    end
endmodule
