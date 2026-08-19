module wppp_translation_cache #(
    parameter int BANKS = 4,
    parameter int SETS = 16384,
    parameter int WAYS = 8,
    parameter int VPN_WIDTH = 36,
    parameter int PPN_WIDTH = 40,
    parameter int BANK_WIDTH = $clog2(BANKS),
    parameter int INDEX_WIDTH = $clog2(SETS),
    parameter int TAG_WIDTH = VPN_WIDTH - BANK_WIDTH - INDEX_WIDTH
) (
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 lookup_valid,
    input  logic [VPN_WIDTH-1:0] lookup_vpn,
    output logic                 lookup_ready,
    output logic                 lookup_rsp_valid,
    output logic                 lookup_rsp_hit,
    output logic [PPN_WIDTH-1:0] lookup_rsp_ppn,

    input  logic                 insert_valid,
    input  logic [VPN_WIDTH-1:0] insert_vpn,
    input  logic [PPN_WIDTH-1:0] insert_ppn,
    output logic                 insert_ready,
    output logic                 insert_commit,

    input  logic                 flush_req,
    output logic                 flush_busy,
    output logic                 flush_done
);
    logic [BANK_WIDTH-1:0] lookup_bank;
    logic [INDEX_WIDTH-1:0] lookup_index;
    logic [TAG_WIDTH-1:0] lookup_tag;
    logic [BANK_WIDTH-1:0] insert_bank;
    logic [INDEX_WIDTH-1:0] insert_index;
    logic [TAG_WIDTH-1:0] insert_tag;

    logic [BANKS-1:0] bank_lookup_valid;
    logic [BANKS-1:0] bank_lookup_conflict;
    logic [BANKS-1:0] bank_rsp_valid;
    logic [BANKS-1:0] bank_rsp_hit;
    logic [PPN_WIDTH-1:0] bank_rsp_ppn [BANKS];
    logic [BANKS-1:0] bank_insert_valid;
    logic [BANKS-1:0] bank_insert_commit;

    logic [INDEX_WIDTH-1:0] flush_index;

    assign lookup_bank = lookup_vpn[BANK_WIDTH-1:0];
    assign lookup_index =
        lookup_vpn[BANK_WIDTH +: INDEX_WIDTH];
    assign lookup_tag =
        lookup_vpn[BANK_WIDTH + INDEX_WIDTH +: TAG_WIDTH];
    assign insert_bank = insert_vpn[BANK_WIDTH-1:0];
    assign insert_index =
        insert_vpn[BANK_WIDTH +: INDEX_WIDTH];
    assign insert_tag =
        insert_vpn[BANK_WIDTH + INDEX_WIDTH +: TAG_WIDTH];

    assign lookup_ready = !flush_busy &&
        !bank_lookup_conflict[lookup_bank];
    assign insert_ready = !flush_busy;
    assign insert_commit = |bank_insert_commit;

    always_comb begin
        bank_lookup_valid = '0;
        bank_insert_valid = '0;
        lookup_rsp_valid = 1'b0;
        lookup_rsp_hit = 1'b0;
        lookup_rsp_ppn = '0;

        if (lookup_valid && lookup_ready) begin
            bank_lookup_valid[lookup_bank] = 1'b1;
        end
        if (insert_valid && insert_ready) begin
            bank_insert_valid[insert_bank] = 1'b1;
        end

        for (int bank = 0; bank < BANKS; bank++) begin
            if (bank_rsp_valid[bank]) begin
                lookup_rsp_valid = 1'b1;
                lookup_rsp_hit = bank_rsp_hit[bank];
                lookup_rsp_ppn = bank_rsp_ppn[bank];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // BRAM contents are not reset.  Holding busy high initiates the
            // mandatory power-on row sweep as soon as reset is released.
            flush_busy <= 1'b1;
            flush_done <= 1'b0;
            flush_index <= '0;
        end else begin
            flush_done <= 1'b0;
            if (flush_busy) begin
                if (flush_index == INDEX_WIDTH'(SETS - 1)) begin
                    flush_busy <= 1'b0;
                    flush_done <= 1'b1;
                    flush_index <= '0;
                end else begin
                    flush_index <= flush_index + 1'b1;
                end
            end else if (flush_req) begin
                flush_busy <= 1'b1;
                flush_index <= '0;
            end
        end
    end

    for (genvar bank = 0; bank < BANKS; bank++) begin : CACHE_BANK
        wppp_translation_cache_bank #(
            .SETS(SETS),
            .WAYS(WAYS),
            .TAG_WIDTH(TAG_WIDTH),
            .PPN_WIDTH(PPN_WIDTH),
            .INDEX_WIDTH(INDEX_WIDTH)
        ) bank_inst (
            .clk(clk),
            .rst_n(rst_n),
            .lookup_valid(bank_lookup_valid[bank]),
            .lookup_index(lookup_index),
            .lookup_tag(lookup_tag),
            .lookup_conflict(bank_lookup_conflict[bank]),
            .lookup_rsp_valid(bank_rsp_valid[bank]),
            .lookup_rsp_hit(bank_rsp_hit[bank]),
            .lookup_rsp_ppn(bank_rsp_ppn[bank]),
            .insert_valid(bank_insert_valid[bank]),
            .insert_index(insert_index),
            .insert_tag(insert_tag),
            .insert_ppn(insert_ppn),
            .insert_commit(bank_insert_commit[bank]),
            .flush_active(flush_busy),
            .flush_index(flush_index)
        );
    end

    // synthesis translate_off
    initial begin
        if ((1 << BANK_WIDTH) != BANKS) begin
            $fatal(1, "wppp_translation_cache BANKS must be a power of two");
        end
        if (TAG_WIDTH <= 0) begin
            $fatal(1, "wppp_translation_cache has invalid address geometry");
        end
    end
    // synthesis translate_on
endmodule
