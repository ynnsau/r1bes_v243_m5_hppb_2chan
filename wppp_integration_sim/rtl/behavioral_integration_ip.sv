// Transaction-level model for the page-residency RAM used by page_tbl_update.
// Unwritten rows read as zero, which represents a page resident in CXL/device
// memory and therefore eligible for WPPP.
module bram_pgmap_table (
    input  logic [63:0] data,
    input  logic [15:0] address,
    input  logic        wren,
    input  logic        clock,
    output logic [63:0] q
);
    logic [63:0] mem [logic [15:0]];

    always_ff @(posedge clock) begin
        if (mem.exists(address)) begin
            q <= mem[address];
        end else begin
            q <= '0;
        end

        if (wren) begin
            mem[address] = data;
        end
    end

    task automatic clear_all();
        mem.delete();
        q = '0;
    endtask

    task automatic backdoor_write(
        input logic [15:0] row,
        input logic [63:0] value
    );
        mem[row] = value;
    endtask
endmodule
