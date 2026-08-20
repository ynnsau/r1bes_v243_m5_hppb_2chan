module wppp_translation_cache_bank #(
    parameter int SETS = 16384,
    parameter int WAYS = 8,
    parameter int TAG_WIDTH = 20,
    parameter int PPN_WIDTH = 40,
    parameter int INDEX_WIDTH = $clog2(SETS),
    parameter int WAY_WIDTH = $clog2(WAYS)
) (
    input  logic                   clk,
    input  logic                   rst_n,

    input  logic                   lookup_valid,
    input  logic [INDEX_WIDTH-1:0] lookup_index,
    input  logic [TAG_WIDTH-1:0]   lookup_tag,
    output logic                   lookup_conflict,
    output logic                   lookup_rsp_valid,
    output logic                   lookup_rsp_hit,
    output logic [PPN_WIDTH-1:0]   lookup_rsp_ppn,

    input  logic                   insert_valid,
    input  logic [INDEX_WIDTH-1:0] insert_index,
    input  logic [TAG_WIDTH-1:0]   insert_tag,
    input  logic [PPN_WIDTH-1:0]   insert_ppn,
    output logic                   insert_commit,

    input  logic                   flush_active,
    input  logic [INDEX_WIDTH-1:0] flush_index
);
    localparam int ENTRY_WIDTH = 64;
    localparam int UNUSED_WIDTH =
        ENTRY_WIDTH - 1 - TAG_WIDTH - PPN_WIDTH;

    localparam int WAY_BYTES = ENTRY_WIDTH / 8;
    localparam int VALID_BIT = PPN_WIDTH + TAG_WIDTH;

    // One 512-bit row contains all eight ways.  The generated RAM's 64 byte
    // enables let an insertion update one 64-bit way without a read/modify/
    // write, while a flush writes all eight ways in one cycle.
    logic [511:0] bram_data;
    logic [511:0] bram_q;
    logic [63:0]  bram_byteena;
    logic [13:0]  bram_wraddress;
    logic          bram_wren;

    // The replacement pointer is per set as required.  It is sampled into
    // the one-cycle insertion pipeline.  Consecutive inserts to the same set
    // bypass the not-yet-written pointer and therefore still advance RR.
    (* ramstyle = "MLAB" *) logic [WAY_WIDTH-1:0] rr_mem [SETS];
    logic                    insert_pipe_valid;
    logic [INDEX_WIDTH-1:0]  insert_pipe_index;
    logic [TAG_WIDTH-1:0]    insert_pipe_tag;
    logic [PPN_WIDTH-1:0]    insert_pipe_ppn;
    logic [WAY_WIDTH-1:0]    insert_pipe_way;

    logic                    lookup_valid_d1;
    logic                    lookup_valid_d2;
    logic [TAG_WIDTH-1:0]    lookup_tag_d1;
    logic [TAG_WIDTH-1:0]    lookup_tag_d2;
    logic [WAYS-1:0]         hit_vec;

    // Do not let a lookup observe the pre-fill row while an insertion for the
    // same set is either entering or occupying the write pipeline.  Without
    // the current-cycle term, a lookup coincident with a due fill can report a
    // stale miss and allocate redundant translation work one cycle before the
    // new entry becomes visible.
    assign lookup_conflict =
        (insert_valid && (insert_index == lookup_index)) ||
        (insert_pipe_valid && (insert_pipe_index == lookup_index));
    assign insert_commit = insert_pipe_valid && !flush_active;
    assign lookup_rsp_valid = lookup_valid_d2;
    assign lookup_rsp_hit = |hit_vec;

    always_comb begin
        hit_vec = '0;
        lookup_rsp_ppn = '0;
        for (int way = 0; way < WAYS; way++) begin
            hit_vec[way] = lookup_valid_d2 &&
                bram_q[(way * ENTRY_WIDTH) + VALID_BIT] &&
                (bram_q[(way * ENTRY_WIDTH) + PPN_WIDTH +: TAG_WIDTH] ==
                 lookup_tag_d2);
            if (hit_vec[way]) begin
                lookup_rsp_ppn =
                    bram_q[(way * ENTRY_WIDTH) +: PPN_WIDTH];
            end
        end
    end

    always_comb begin
        bram_data = '0;
        bram_byteena = '0;
        bram_wraddress = 14'(insert_pipe_index);
        bram_wren = 1'b0;

        if (flush_active) begin
            bram_wraddress = 14'(flush_index);
            bram_byteena = '1;
            bram_wren = 1'b1;
        end else if (insert_pipe_valid) begin
            bram_data[(insert_pipe_way * ENTRY_WIDTH) +: ENTRY_WIDTH] = {
                {UNUSED_WIDTH{1'b0}},
                1'b1,
                insert_pipe_tag,
                insert_pipe_ppn
            };
            bram_byteena[(insert_pipe_way * WAY_BYTES) +: WAY_BYTES] = '1;
            bram_wren = 1'b1;
        end
    end

    // The generated RAM registers both the read address and q.  Keep the
    // request tag and validity aligned with that two-edge response latency.
    bram_b512_d16384 cache_data_ram (
        .data(bram_data),
        .q(bram_q),
        .wraddress(bram_wraddress),
        .rdaddress(14'(lookup_index)),
        .wren(bram_wren),
        .clock(clk),
        .byteena_a(bram_byteena)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lookup_valid_d1 <= 1'b0;
            lookup_valid_d2 <= 1'b0;
            lookup_tag_d1 <= '0;
            lookup_tag_d2 <= '0;
            insert_pipe_valid <= 1'b0;
            insert_pipe_index <= '0;
            insert_pipe_tag <= '0;
            insert_pipe_ppn <= '0;
            insert_pipe_way <= '0;
        end else if (flush_active) begin
            lookup_valid_d1 <= 1'b0;
            lookup_valid_d2 <= 1'b0;
            insert_pipe_valid <= 1'b0;
            rr_mem[flush_index] <= '0;
        end else begin
            lookup_valid_d1 <= lookup_valid;
            lookup_valid_d2 <= lookup_valid_d1;
            if (lookup_valid) begin
                lookup_tag_d1 <= lookup_tag;
            end
            if (lookup_valid_d1) begin
                lookup_tag_d2 <= lookup_tag_d1;
            end

            insert_pipe_valid <= insert_valid;
            if (insert_valid) begin
                insert_pipe_index <= insert_index;
                insert_pipe_tag <= insert_tag;
                insert_pipe_ppn <= insert_ppn;
                if (insert_pipe_valid &&
                    (insert_pipe_index == insert_index)) begin
                    insert_pipe_way <= insert_pipe_way + 1'b1;
                end else begin
                    insert_pipe_way <= rr_mem[insert_index];
                end
            end

            if (insert_pipe_valid) begin
                rr_mem[insert_pipe_index] <= insert_pipe_way + 1'b1;
            end
        end
    end

    // synthesis translate_off
    initial begin
        if ((SETS != 16384) || (WAYS != 8) ||
            (INDEX_WIDTH != 14) || (ENTRY_WIDTH != 64)) begin
            $fatal(1,
                "WPPP generated cache RAM requires 8 ways x 16384 sets");
        end
        if ((1 << INDEX_WIDTH) != SETS) begin
            $fatal(1, "wppp_translation_cache_bank SETS must be a power of two");
        end
        if ((1 << WAY_WIDTH) != WAYS) begin
            $fatal(1, "wppp_translation_cache_bank WAYS must be a power of two");
        end
        if (UNUSED_WIDTH < 0) begin
            $fatal(1, "WPPP cache entry does not fit in 64 bits");
        end
    end
    // synthesis translate_on
endmodule
