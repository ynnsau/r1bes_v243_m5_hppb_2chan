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

    typedef struct packed {
        logic [UNUSED_WIDTH-1:0] unused;
        logic                    valid;
        logic [TAG_WIDTH-1:0]    tag;
        logic [PPN_WIDTH-1:0]    ppn;
    } cache_entry_t;

    // One independently writable RAM per way preserves the remap TLB's
    // byte-enable behavior without requiring a 512-bit read/modify/write.
    // There is deliberately no reset loop: POR and CSR flush sweep one set
    // from every way on each cycle, retaining block-RAM inference.
    (* ramstyle = "M20K" *) cache_entry_t way_mem [WAYS][SETS];
    cache_entry_t lookup_q [WAYS];

    // The replacement pointer is per set as required.  It is sampled into
    // the one-cycle insertion pipeline.  Consecutive inserts to the same set
    // bypass the not-yet-written pointer and therefore still advance RR.
    (* ramstyle = "MLAB" *) logic [WAY_WIDTH-1:0] rr_mem [SETS];
    logic                    insert_pipe_valid;
    logic [INDEX_WIDTH-1:0]  insert_pipe_index;
    logic [TAG_WIDTH-1:0]    insert_pipe_tag;
    logic [PPN_WIDTH-1:0]    insert_pipe_ppn;
    logic [WAY_WIDTH-1:0]    insert_pipe_way;

    logic                    lookup_valid_r;
    logic [TAG_WIDTH-1:0]    lookup_tag_r;
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
    assign lookup_rsp_valid = lookup_valid_r;
    assign lookup_rsp_hit = |hit_vec;

    always_comb begin
        hit_vec = '0;
        lookup_rsp_ppn = '0;
        for (int way = 0; way < WAYS; way++) begin
            hit_vec[way] = lookup_valid_r && lookup_q[way].valid &&
                (lookup_q[way].tag == lookup_tag_r);
            if (hit_vec[way]) begin
                lookup_rsp_ppn = lookup_q[way].ppn;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            lookup_valid_r <= 1'b0;
            lookup_tag_r <= '0;
            insert_pipe_valid <= 1'b0;
            insert_pipe_index <= '0;
            insert_pipe_tag <= '0;
            insert_pipe_ppn <= '0;
            insert_pipe_way <= '0;
        end else if (flush_active) begin
            lookup_valid_r <= 1'b0;
            insert_pipe_valid <= 1'b0;
            rr_mem[flush_index] <= '0;
        end else begin
            lookup_valid_r <= lookup_valid;
            if (lookup_valid) begin
                lookup_tag_r <= lookup_tag;
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

    for (genvar way = 0; way < WAYS; way++) begin : WAY_RAM
        always_ff @(posedge clk) begin
            if (rst_n) begin
                if (flush_active) begin
                    way_mem[way][flush_index] <= '0;
                end else begin
                    if (lookup_valid) begin
                        lookup_q[way] <= way_mem[way][lookup_index];
                    end
                    if (insert_pipe_valid &&
                        (insert_pipe_way == WAY_WIDTH'(way))) begin
                        way_mem[way][insert_pipe_index] <= cache_entry_t'({
                            {UNUSED_WIDTH{1'b0}},
                            1'b1,
                            insert_pipe_tag,
                            insert_pipe_ppn
                        });
                    end
                end
            end
        end
    end

    // synthesis translate_off
    initial begin
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
