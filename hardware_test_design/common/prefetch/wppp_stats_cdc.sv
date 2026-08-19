module wppp_stats_cdc #(
    parameter int STATS_COUNT = 26,
    parameter int SNAPSHOT_LOG2_CYCLES = 6
) (
    input  logic src_clk,
    input  logic src_rst_n,
    input  logic [63:0] src_stats [0:STATS_COUNT-1],

    input  logic dst_clk,
    input  logic dst_rst_n,
    output logic [63:0] dst_stats [0:STATS_COUNT-1]
);
    logic [SNAPSHOT_LOG2_CYCLES-1:0] snapshot_div;
    logic [63:0] snapshot_hold [0:STATS_COUNT-1];
    logic request_toggle;
    logic acknowledge_toggle;
    logic acknowledge_sync_1;
    logic acknowledge_sync_2;
    logic request_sync_1;
    logic request_sync_2;

    // The source copies all counters into a held snapshot at one instant.  It
    // does not modify that bus again until the destination acknowledges it,
    // which makes the multi-bit transfer coherent instead of 64 independent
    // two-flop samples that could tear.
    always_ff @(posedge src_clk) begin
        if (!src_rst_n) begin
            snapshot_div <= '0;
            request_toggle <= 1'b0;
            acknowledge_sync_1 <= 1'b0;
            acknowledge_sync_2 <= 1'b0;
            for (int stat = 0; stat < STATS_COUNT; stat++) begin
                snapshot_hold[stat] <= '0;
            end
        end else begin
            acknowledge_sync_1 <= acknowledge_toggle;
            acknowledge_sync_2 <= acknowledge_sync_1;
            snapshot_div <= snapshot_div + 1'b1;

            if ((snapshot_div == 0) &&
                (acknowledge_sync_2 == request_toggle)) begin
                for (int stat = 0; stat < STATS_COUNT; stat++) begin
                    snapshot_hold[stat] <= src_stats[stat];
                end
                request_toggle <= ~request_toggle;
            end
        end
    end

    always_ff @(posedge dst_clk) begin
        if (!dst_rst_n) begin
            request_sync_1 <= 1'b0;
            request_sync_2 <= 1'b0;
            acknowledge_toggle <= 1'b0;
            for (int stat = 0; stat < STATS_COUNT; stat++) begin
                dst_stats[stat] <= '0;
            end
        end else begin
            request_sync_1 <= request_toggle;
            request_sync_2 <= request_sync_1;

            if (request_sync_2 != acknowledge_toggle) begin
                for (int stat = 0; stat < STATS_COUNT; stat++) begin
                    dst_stats[stat] <= snapshot_hold[stat];
                end
                acknowledge_toggle <= request_sync_2;
            end
        end
    end
endmodule
