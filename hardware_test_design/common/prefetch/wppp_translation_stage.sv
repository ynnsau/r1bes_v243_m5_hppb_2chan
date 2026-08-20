module wppp_translation_stage #(
    parameter bit LEGACY_DIRECT_MODE = 1'b0,
    parameter int CACHE_BANKS = 4,
    parameter int CACHE_SETS = 16384,
    parameter int CACHE_WAYS = 8,
    parameter int TRANSLATION_LATENCY = 128,
    parameter int HINT_FIFO_DEPTH = 32,
    parameter int MSHR_SETS = 32,
    parameter int MSHR_WAYS = 8,
    parameter int STATS_COUNT = 17,
    parameter int MAX_HINT_CACHELINES = 128
) (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        hint_valid_i,
    input  logic        hint_invalid_i,
    input  logic        hint_sel_i,
    input  logic [63:0] hint_address_i,
    input  logic [15:0] hint_count_i,

    input  logic [63:0] translation_offset_i,
    input  logic [63:0] pa_range_start_i,
    input  logic [63:0] pa_range_span_i,
    input  logic        flush_req_i,
    input  logic        engine0_ready_i,
    input  logic        engine1_ready_i,

    output logic        hint_valid_o,
    output logic        hint_sel_o,
    output logic [63:0] hint_address_o,
    output logic [15:0] hint_count_o,

    output logic        flush_busy_o,
    output logic [63:0] status_o,
    output logic [63:0] stats_o [0:STATS_COUNT-1]
);
    generate
        if (LEGACY_DIRECT_MODE) begin : LEGACY_DIRECT
            // This branch is intentionally transparent and contains no cache.
            // It exists only to preserve the established direct-PA regression.
            always_comb begin
                hint_valid_o = hint_valid_i && (hint_address_i != 0);
                hint_sel_o = hint_sel_i;
                hint_address_o = hint_address_i;
                hint_count_o = hint_count_i;
                flush_busy_o = 1'b0;
                status_o = 64'h1;
                for (int stat = 0; stat < STATS_COUNT; stat++) begin
                    stats_o[stat] = '0;
                end
            end
        end else begin : TRANSLATED
            localparam int VPN_WIDTH = 36;
            localparam int PPN_WIDTH = 40;
            localparam int MSHR_SET_W = $clog2(MSHR_SETS);
            localparam int MSHR_WAY_W = $clog2(MSHR_WAYS);
            localparam int MSHR_COUNT_W = $clog2(MSHR_SETS * MSHR_WAYS + 1);
            localparam int TIMER_PTR_W = $clog2(TRANSLATION_LATENCY);

            typedef enum logic [1:0] {
                HINT_IDLE,
                HINT_LOOKUP_REQ,
                HINT_LOOKUP_WAIT,
                HINT_EMIT
            } hint_state_t;

            logic [80:0] hint_fifo_data;
            logic [80:0] hint_fifo_q;
            logic [4:0] hint_fifo_usedw;
            logic [5:0] hint_fifo_occupancy;
            logic hint_fifo_full;
            logic hint_fifo_empty;
            logic hint_fifo_sclr;
            logic hint_fifo_full_d;
            logic hint_format_invalid;
            logic hint_push_req;
            logic hint_push;
            logic hint_pop;

            hint_state_t hint_state;
            logic current_sel;
            logic [63:0] current_va;
            logic [15:0] current_count;
            logic [6:0] lines_to_page_end;
            logic [15:0] fragment_count;
            logic [VPN_WIDTH-1:0] fragment_vpn;
            logic [63:0] fragment_next_va;
            logic [15:0] fragment_remaining;
            logic [63:0] emit_address;
            logic [15:0] emit_count;
            logic emit_engine_ready;

            logic cache_lookup_valid;
            logic cache_lookup_ready;
            logic cache_rsp_valid;
            logic cache_rsp_hit;
            logic [PPN_WIDTH-1:0] cache_rsp_ppn;
            logic cache_insert_valid;
            logic cache_insert_ready;
            logic cache_insert_commit;
            logic [VPN_WIDTH-1:0] cache_insert_vpn;
            logic [PPN_WIDTH-1:0] cache_insert_ppn;
            logic cache_flush_busy;
            logic cache_flush_done;
            logic flush_complete;

            logic [MSHR_SETS-1:0][MSHR_WAYS-1:0] mshr_valid;
            logic [VPN_WIDTH-1:0]
                mshr_vpn [MSHR_SETS][MSHR_WAYS];
            logic [PPN_WIDTH-1:0]
                mshr_ppn [MSHR_SETS][MSHR_WAYS];
            logic [MSHR_SET_W-1:0] mshr_lookup_set;
            logic [MSHR_WAYS-1:0] mshr_match_vec;
            logic [MSHR_WAYS-1:0] mshr_free_vec;
            logic mshr_match;
            logic mshr_free;
            logic [MSHR_WAY_W-1:0] mshr_free_way;
            logic [MSHR_COUNT_W-1:0] mshr_occupancy;
            logic [MSHR_COUNT_W-1:0] mshr_highwater;

            logic timer_valid [TRANSLATION_LATENCY];
            logic [MSHR_SET_W-1:0] timer_set [TRANSLATION_LATENCY];
            logic [MSHR_WAY_W-1:0] timer_way [TRANSLATION_LATENCY];
            logic [TIMER_PTR_W-1:0] timer_ptr;
            logic timer_due_valid;
            logic timer_slot_available;
            logic timer_full_d;

            logic miss_event;
            logic mshr_release_event;
            logic mshr_allocate_event;
            logic coalesce_event;
            logic mshr_drop_event;
            logic timer_drop_event;
            logic [51:0] translated_page_base;
            logic [51:0] translated_pa;
            logic translation_subtract_valid;
            logic [64:0] translated_start_ext;
            logic [64:0] translated_size_ext;
            logic [64:0] translated_end;
            logic [64:0] configured_pa_start;
            logic [64:0] configured_pa_end;
            logic pa_fragment_in_range;

            logic [7:0] aux_flush_index;

            logic [63:0] hit_count;
            logic [63:0] miss_count;
            logic [63:0] coalesced_miss_count;
            logic [63:0] unique_miss_count;
            logic [63:0] insertion_count;
            logic [63:0] pa_reject_count;
            logic [63:0] invalid_hint_count;
            logic [63:0] hint_fifo_drop_count;
            logic [63:0] mshr_admission_drop_count;
            logic [63:0] timer_drop_count;
            logic [63:0] flush_hint_drop_count;
            logic [63:0] mshr_flush_cancel_count;
            logic [63:0] hint_fifo_full_cycle_count;
            logic [63:0] timer_full_cycle_count;
            logic [63:0] hint_fifo_full_episode_count;
            logic [63:0] timer_full_episode_count;

            function automatic logic [MSHR_SET_W-1:0] mshr_hash(
                input logic [VPN_WIDTH-1:0] vpn
            );
                logic [MSHR_SET_W-1:0] hash;
                hash = '0;
                for (int bit_idx = 0; bit_idx < VPN_WIDTH; bit_idx++) begin
                    hash[bit_idx % MSHR_SET_W] =
                        hash[bit_idx % MSHR_SET_W] ^ vpn[bit_idx];
                end
                return hash;
            endfunction

            assign hint_fifo_data = {
                hint_sel_i, hint_address_i, hint_count_i
            };
            assign hint_fifo_occupancy = hint_fifo_full ?
                6'(HINT_FIFO_DEPTH) : {1'b0, hint_fifo_usedw};
            assign hint_fifo_sclr = !rst_n || cache_flush_busy || flush_req_i;
            assign hint_format_invalid = hint_invalid_i ||
                (hint_valid_i &&
                 (hint_count_i > 16'(MAX_HINT_CACHELINES)));
            assign hint_push_req = hint_valid_i && (hint_count_i != 0);
            assign hint_pop = (hint_state == HINT_IDLE) &&
                !hint_fifo_empty && !cache_flush_busy && !flush_req_i;
            assign hint_push = hint_push_req && !hint_format_invalid &&
                !cache_flush_busy && !flush_req_i &&
                !hint_fifo_full;

            // The IP is registered show-ahead: q is valid whenever empty is
            // low.  Its default full behavior rejects a write even when a
            // simultaneous read occurs, matching the specified drop-on-full
            // policy and its CSR accounting.
            fifo_81b_32d hint_fifo (
                .data(hint_fifo_data),
                .wrreq(hint_push),
                .rdreq(hint_pop),
                .clock(clk),
                .sclr(hint_fifo_sclr),
                .q(hint_fifo_q),
                .usedw(hint_fifo_usedw),
                .full(hint_fifo_full),
                .empty(hint_fifo_empty)
            );

            assign lines_to_page_end = 7'd64 - {1'b0, current_va[11:6]};
            assign fragment_count =
                (current_count <= {9'b0, lines_to_page_end}) ?
                    current_count : {9'b0, lines_to_page_end};
            assign fragment_vpn = current_va[47:12];
            assign fragment_next_va =
                current_va + ({48'b0, fragment_count} << 6);
            assign fragment_remaining = current_count - fragment_count;
            assign emit_engine_ready = current_sel ?
                engine1_ready_i : engine0_ready_i;

            assign cache_lookup_valid = hint_state == HINT_LOOKUP_REQ;
            assign miss_event = (hint_state == HINT_LOOKUP_WAIT) &&
                cache_rsp_valid && !cache_rsp_hit;
            assign mshr_lookup_set = mshr_hash(fragment_vpn);

            always_comb begin
                mshr_match_vec = '0;
                mshr_free_vec = '0;
                mshr_free_way = '0;
                for (int way = 0; way < MSHR_WAYS; way++) begin
                    mshr_match_vec[way] =
                        mshr_valid[mshr_lookup_set][way] &&
                        (mshr_vpn[mshr_lookup_set][way] == fragment_vpn);
                    mshr_free_vec[way] =
                        !mshr_valid[mshr_lookup_set][way];
                    if (mshr_free_vec[way]) begin
                        mshr_free_way = MSHR_WAY_W'(way);
                    end
                end
            end

            assign mshr_match = |mshr_match_vec;
            assign mshr_free = |mshr_free_vec;
            assign timer_due_valid = timer_valid[timer_ptr] &&
                !cache_flush_busy;
            assign cache_insert_valid = timer_due_valid;
            assign cache_insert_vpn =
                mshr_vpn[timer_set[timer_ptr]][timer_way[timer_ptr]];
            assign cache_insert_ppn =
                mshr_ppn[timer_set[timer_ptr]][timer_way[timer_ptr]];
            assign mshr_release_event =
                timer_due_valid && cache_insert_ready;
            assign timer_slot_available =
                !timer_valid[timer_ptr] || mshr_release_event;
            assign coalesce_event = miss_event &&
                translation_subtract_valid && mshr_match;
            assign mshr_allocate_event = miss_event &&
                translation_subtract_valid && !mshr_match &&
                mshr_free && timer_slot_available;
            assign mshr_drop_event =
                miss_event && translation_subtract_valid &&
                !mshr_match && !mshr_free;
            // The wheel has one slot per service cycle.  A collision means
            // finite timer capacity was exhausted; the miss is counted and
            // discarded without allocating an unreachable MSHR entry.
            assign timer_drop_event = miss_event &&
                translation_subtract_valid && !mshr_match &&
                mshr_free && !timer_slot_available;

            assign translation_subtract_valid =
                (translation_offset_i[63:52] == 0) &&
                ({4'b0, fragment_vpn, 12'b0} >=
                 translation_offset_i[51:0]);
            assign translated_page_base =
                {4'b0, fragment_vpn, 12'b0} -
                translation_offset_i[51:0];
            assign translated_pa = {cache_rsp_ppn, current_va[11:0]};
            assign translated_start_ext = {13'b0, translated_pa};
            assign translated_size_ext =
                ({49'b0, fragment_count} << 6);
            assign translated_end = translated_start_ext + translated_size_ext;
            assign configured_pa_start = {1'b0, pa_range_start_i};
            assign configured_pa_end = {1'b0, pa_range_start_i} +
                {1'b0, pa_range_span_i};
            assign pa_fragment_in_range =
                (translated_start_ext >= configured_pa_start) &&
                (translated_end <= configured_pa_end) &&
                !configured_pa_end[64] && (pa_range_span_i != 0);

            wppp_translation_cache #(
                .BANKS(CACHE_BANKS),
                .SETS(CACHE_SETS),
                .WAYS(CACHE_WAYS),
                .VPN_WIDTH(VPN_WIDTH),
                .PPN_WIDTH(PPN_WIDTH)
            ) cache_inst (
                .clk(clk),
                .rst_n(rst_n),
                .lookup_valid(cache_lookup_valid),
                .lookup_vpn(fragment_vpn),
                .lookup_ready(cache_lookup_ready),
                .lookup_rsp_valid(cache_rsp_valid),
                .lookup_rsp_hit(cache_rsp_hit),
                .lookup_rsp_ppn(cache_rsp_ppn),
                .insert_valid(cache_insert_valid),
                .insert_vpn(cache_insert_vpn),
                .insert_ppn(cache_insert_ppn),
                .insert_ready(cache_insert_ready),
                .insert_commit(cache_insert_commit),
                .flush_req(flush_req_i),
                .flush_busy(cache_flush_busy),
                .flush_done(cache_flush_done)
            );

            assign flush_busy_o = cache_flush_busy;

            always_comb begin
                status_o = '0;
                status_o[0] = !cache_flush_busy;
                status_o[1] = cache_flush_busy;
                status_o[2] = flush_complete;
                status_o[16:8] = 9'(mshr_occupancy);
                status_o[32:24] = 9'(mshr_highwater);

                stats_o[0] = hit_count;
                stats_o[1] = miss_count;
                stats_o[2] = coalesced_miss_count;
                stats_o[3] = unique_miss_count;
                stats_o[4] = insertion_count;
                stats_o[5] = pa_reject_count;
                stats_o[6] = invalid_hint_count;
                stats_o[7] = hint_fifo_drop_count;
                stats_o[8] = mshr_admission_drop_count;
                stats_o[9] = timer_drop_count;
                stats_o[10] = flush_hint_drop_count;
                stats_o[11] = mshr_flush_cancel_count;
                stats_o[12] = hint_fifo_full_cycle_count;
                stats_o[13] = timer_full_cycle_count;
                stats_o[14] = hint_fifo_full_episode_count;
                stats_o[15] = timer_full_episode_count;
                stats_o[16] = {
                    23'b0, mshr_highwater, 23'b0, mshr_occupancy
                };
            end

            always_ff @(posedge clk) begin
                if (!rst_n) begin
                    hint_fifo_full_d <= 1'b0;
                    hint_state <= HINT_IDLE;
                    current_sel <= 1'b0;
                    current_va <= '0;
                    current_count <= '0;
                    emit_address <= '0;
                    emit_count <= '0;
                    hint_valid_o <= 1'b0;
                    hint_sel_o <= 1'b0;
                    hint_address_o <= '0;
                    hint_count_o <= '0;

                    timer_ptr <= '0;
                    timer_full_d <= 1'b0;
                    aux_flush_index <= '0;
                    flush_complete <= 1'b0;
                    mshr_occupancy <= '0;
                    mshr_highwater <= '0;

                    hit_count <= '0;
                    miss_count <= '0;
                    coalesced_miss_count <= '0;
                    unique_miss_count <= '0;
                    insertion_count <= '0;
                    pa_reject_count <= '0;
                    invalid_hint_count <= '0;
                    hint_fifo_drop_count <= '0;
                    mshr_admission_drop_count <= '0;
                    timer_drop_count <= '0;
                    flush_hint_drop_count <= '0;
                    mshr_flush_cancel_count <= '0;
                    hint_fifo_full_cycle_count <= '0;
                    timer_full_cycle_count <= '0;
                    hint_fifo_full_episode_count <= '0;
                    timer_full_episode_count <= '0;

                    for (int set_idx = 0; set_idx < MSHR_SETS; set_idx++) begin
                        for (int way = 0; way < MSHR_WAYS; way++) begin
                            mshr_valid[set_idx][way] <= 1'b0;
                        end
                    end
                    for (int slot = 0; slot < TRANSLATION_LATENCY; slot++) begin
                        timer_valid[slot] <= 1'b0;
                    end
                end else begin
                    hint_valid_o <= 1'b0;

                    if (flush_req_i) begin
                        flush_complete <= 1'b0;
                    end else if (cache_flush_done) begin
                        flush_complete <= 1'b1;
                    end

                    if (hint_format_invalid) begin
                        invalid_hint_count <= invalid_hint_count + 1'b1;
                    end

                    if (cache_flush_busy || flush_req_i) begin
                        hint_state <= HINT_IDLE;
                        hint_fifo_full_d <= 1'b0;
                        timer_full_d <= 1'b0;
                        timer_ptr <= '0;

                        if (flush_req_i && !cache_flush_busy) begin
                            flush_hint_drop_count <= flush_hint_drop_count +
                                64'(hint_fifo_occupancy) +
                                ((hint_state == HINT_IDLE) ? 64'd0 : 64'd1) +
                                ((hint_push_req && !hint_format_invalid) ?
                                    64'd1 : 64'd0);
                            mshr_flush_cancel_count <=
                                mshr_flush_cancel_count + 64'(mshr_occupancy);
                            mshr_occupancy <= '0;
                            aux_flush_index <= '0;
                        end else begin
                            aux_flush_index <= aux_flush_index + 1'b1;
                        end

                        // The cache sweep is much longer than these auxiliary
                        // structures.  Clearing one entry per cycle avoids a
                        // high-fanout single-cycle CSR flush path.
                        mshr_valid[aux_flush_index[7:3]]
                                  [aux_flush_index[2:0]] <= 1'b0;
                        timer_valid[aux_flush_index[TIMER_PTR_W-1:0]] <= 1'b0;

                        if (hint_push_req && !hint_format_invalid &&
                            !(flush_req_i && !cache_flush_busy)) begin
                            flush_hint_drop_count <= flush_hint_drop_count + 1'b1;
                        end
                    end else begin
                        aux_flush_index <= '0;
                        hint_fifo_full_d <= hint_fifo_full;
                        timer_full_d <= timer_valid[timer_ptr] &&
                            !mshr_release_event;

                        if (hint_fifo_full) begin
                            hint_fifo_full_cycle_count <=
                                hint_fifo_full_cycle_count + 1'b1;
                        end
                        if (hint_fifo_full && !hint_fifo_full_d) begin
                            hint_fifo_full_episode_count <=
                                hint_fifo_full_episode_count + 1'b1;
                        end
                        if (timer_valid[timer_ptr] && !mshr_release_event) begin
                            timer_full_cycle_count <=
                                timer_full_cycle_count + 1'b1;
                        end
                        if (timer_valid[timer_ptr] && !mshr_release_event &&
                            !timer_full_d) begin
                            timer_full_episode_count <=
                                timer_full_episode_count + 1'b1;
                        end

                        if (!hint_push && hint_push_req &&
                            !hint_format_invalid) begin
                            hint_fifo_drop_count <=
                                hint_fifo_drop_count + 1'b1;
                        end

                        if (hint_pop) begin
                            current_sel <= hint_fifo_q[80];
                            current_va <= hint_fifo_q[79:16];
                            current_count <= hint_fifo_q[15:0];
                            hint_state <= HINT_LOOKUP_REQ;
                        end

                        if ((hint_state == HINT_LOOKUP_REQ) &&
                            cache_lookup_ready) begin
                            hint_state <= HINT_LOOKUP_WAIT;
                        end

                        if ((hint_state == HINT_LOOKUP_WAIT) &&
                            cache_rsp_valid) begin
                            if (cache_rsp_hit) begin
                                hit_count <= hit_count + 1'b1;
                                if (pa_fragment_in_range) begin
                                    emit_address <= {12'b0, translated_pa};
                                    emit_count <= fragment_count;
                                    hint_state <= HINT_EMIT;
                                end else begin
                                    pa_reject_count <= pa_reject_count + 1'b1;
                                    current_va <= fragment_next_va;
                                    current_count <= fragment_remaining;
                                    hint_state <= (fragment_remaining == 0) ?
                                        HINT_IDLE : HINT_LOOKUP_REQ;
                                end
                            end else begin
                                miss_count <= miss_count + 1'b1;
                                if (!translation_subtract_valid) begin
                                    pa_reject_count <= pa_reject_count + 1'b1;
                                end else if (coalesce_event) begin
                                    coalesced_miss_count <=
                                        coalesced_miss_count + 1'b1;
                                end else if (mshr_drop_event) begin
                                    mshr_admission_drop_count <=
                                        mshr_admission_drop_count + 1'b1;
                                end else if (timer_drop_event) begin
                                    timer_drop_count <= timer_drop_count + 1'b1;
                                end
                                current_va <= fragment_next_va;
                                current_count <= fragment_remaining;
                                hint_state <= (fragment_remaining == 0) ?
                                    HINT_IDLE : HINT_LOOKUP_REQ;
                            end
                        end

                        // A cache hit becomes owned pre-WPPP work.  Hold it
                        // until the selected engine FIFO advertises capacity;
                        // after this handshake the engine owns the fragment.
                        if ((hint_state == HINT_EMIT) && emit_engine_ready) begin
                            hint_valid_o <= 1'b1;
                            hint_sel_o <= current_sel;
                            hint_address_o <= emit_address;
                            hint_count_o <= emit_count;
                            current_va <= fragment_next_va;
                            current_count <= fragment_remaining;
                            hint_state <= (fragment_remaining == 0) ?
                                HINT_IDLE : HINT_LOOKUP_REQ;
                        end

                        if (mshr_allocate_event) begin
                            mshr_valid[mshr_lookup_set][mshr_free_way] <= 1'b1;
                            mshr_vpn[mshr_lookup_set][mshr_free_way] <=
                                fragment_vpn;
                            mshr_ppn[mshr_lookup_set][mshr_free_way] <=
                                translated_page_base[51:12];
                            timer_valid[timer_ptr] <= 1'b1;
                            timer_set[timer_ptr] <= mshr_lookup_set;
                            timer_way[timer_ptr] <= mshr_free_way;
                            unique_miss_count <= unique_miss_count + 1'b1;
                        end

                        if (mshr_release_event) begin
                            mshr_valid[timer_set[timer_ptr]]
                                      [timer_way[timer_ptr]] <= 1'b0;
                            timer_valid[timer_ptr] <= 1'b0;
                        end

                        case ({mshr_allocate_event, mshr_release_event})
                            2'b10: mshr_occupancy <= mshr_occupancy + 1'b1;
                            2'b01: mshr_occupancy <= mshr_occupancy - 1'b1;
                            default: begin end
                        endcase
                        if (mshr_allocate_event && !mshr_release_event &&
                            (mshr_occupancy + 1'b1 > mshr_highwater)) begin
                            mshr_highwater <= mshr_occupancy + 1'b1;
                        end

                        timer_ptr <= timer_ptr + 1'b1;
                        if (cache_insert_commit) begin
                            insertion_count <= insertion_count + 1'b1;
                        end
                    end
                end
            end

            // synthesis translate_off
            initial begin
                if (HINT_FIFO_DEPTH != 32) begin
                    $fatal(1, "WPPP generated hint FIFO depth is fixed at 32");
                end
                if ((1 << TIMER_PTR_W) != TRANSLATION_LATENCY) begin
                    $fatal(1, "WPPP TRANSLATION_LATENCY must be a power of two");
                end
                if ((MSHR_SETS != 32) || (MSHR_WAYS != 8)) begin
                    $fatal(1, "First-version WPPP MSHR geometry is 32x8");
                end
            end
            // synthesis translate_on
        end
    endgenerate
endmodule
