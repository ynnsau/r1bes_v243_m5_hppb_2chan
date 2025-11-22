module wppp_lut
#(
    parameter ID_WIDTH = 10,
    parameter LUT_DEPTH = 1 << ID_WIDTH
)
(
    input  logic          axi4_mm_clk,
    input  logic          axi4_mm_rst_n,
    input  logic          flush_lut,
    input  logic          write_lut, // update enable for LUT when load an addr
    input  logic          read_lut,  // update enable for LUT when read an addr
    input  logic [ID_WIDTH-1:0]   curr_arid, // id to write the LUT entry
    input  logic [63:0]   curr_araddr, // addr to write the LUT entry
    input  logic [ID_WIDTH-1:0]   curr_rid, // id to read the LUT entry
    // input  logic          req_rden,
    // input  logic          resp_rden,
    output logic          lut_valid, // indicate if the LUT entry is valid
    output logic          lut_in_use, // indicate if the LUT entry is being used
    output logic [63:0]   push_page_addr_r // addr read from the LUT
);


/* id to address valid LUT */
logic [LUT_DEPTH - 1:0] id2addr_valids;
assign lut_valid = id2addr_valids[curr_rid];
assign lut_in_use = id2addr_valids[curr_arid];

always_ff @(posedge axi4_mm_clk) begin
    if (!axi4_mm_rst_n || flush_lut) begin
        id2addr_valids <= '0;
    end
    else begin
        if (write_lut) begin // writing to LUT
            id2addr_valids[curr_arid] <= 1'b1;
        end
        if (read_lut) begin // reading from LUT
            id2addr_valids[curr_rid] <= 1'b0;
        end
    end
end

// shrink BRAM later
w4096_d64 id2addr_lut (
    .data_a    (curr_araddr),    //   input,  width = 64,    data_a.datain_a
    .q_a       (),       //  output,  width = 64,       q_a.dataout_a
    .data_b    (),    //   input,  width = 64,    data_b.datain_b
    .q_b       (push_page_addr_r),       //  output,  width = 64,       q_b.dataout_b
    .address_a ({2'b0, curr_arid}), //   input,  width = 12, address_a.address_a
    .address_b ({2'b0, curr_rid}), //   input,  width = 12, address_b.address_b
    .wren_a    (write_lut),    //   input,   width = 1,    wren_a.wren_a
    .wren_b    ('0),    //   input,   width = 1,    wren_b.wren_b
    .clock     (axi4_mm_clk),     //   input,   width = 1,     clock.clk
    .rden_a    ('0),
    .rden_b    ('1)
);

endmodule