// Behavioral stand-ins for the three generated Altera IP blocks used by the
// active WPPP path. These models intentionally implement only the ports and
// timing contracts exercised by the standalone simulation. Quartus continues
// to use the generated IP selected by cxltyp2_ed.qsf.

module fifo_32w_73d (
    input  logic [72:0] data,
    input  logic        wrreq,
    input  logic        rdreq,
    input  logic        clock,
    output logic [72:0] q,
    output logic [4:0]  usedw,
    output logic        full,
    output logic        empty
);
    localparam int DEPTH = 256;
    logic [72:0] storage [0:DEPTH-1];
    logic [7:0] read_pointer;
    logic [7:0] write_pointer;
    logic [8:0] count;

    assign empty = (count == 0);
    assign full = (count == DEPTH);
    assign q = empty ? '0 : storage[read_pointer];
    // The production RTL keeps the historical five-bit debug connection even
    // though the current IP metadata requests 256 entries.
    assign usedw = count[4:0];

    initial begin
        read_pointer = '0;
        write_pointer = '0;
        count = '0;
    end

    always @(posedge clock) begin
        unique case ({wrreq && !full, rdreq && !empty})
            2'b10: begin
                storage[write_pointer] <= data;
                write_pointer <= write_pointer + 1'b1;
                count <= count + 1'b1;
            end
            2'b01: begin
                read_pointer <= read_pointer + 1'b1;
                count <= count - 1'b1;
            end
            2'b11: begin
                storage[write_pointer] <= data;
                write_pointer <= write_pointer + 1'b1;
                read_pointer <= read_pointer + 1'b1;
            end
            default:;
        endcase
    end
endmodule


module fifo_128w_588d (
    input  logic [587:0] data,
    input  logic         wrreq,
    input  logic         rdreq,
    input  logic         clock,
    output logic [587:0] q,
    output logic [6:0]   usedw,
    output logic         full,
    output logic         empty
);
    localparam int DEPTH = 256;
    logic [587:0] storage [0:DEPTH-1];
    logic [7:0] read_pointer;
    logic [7:0] write_pointer;
    logic [8:0] count;

    assign empty = (count == 0);
    assign full = (count == DEPTH);
    assign q = empty ? '0 : storage[read_pointer];
    // As above, preserve the width of the existing RTL debug port.
    assign usedw = count[6:0];

    initial begin
        read_pointer = '0;
        write_pointer = '0;
        count = '0;
    end

    always @(posedge clock) begin
        unique case ({wrreq && !full, rdreq && !empty})
            2'b10: begin
                storage[write_pointer] <= data;
                write_pointer <= write_pointer + 1'b1;
                count <= count + 1'b1;
            end
            2'b01: begin
                read_pointer <= read_pointer + 1'b1;
                count <= count - 1'b1;
            end
            2'b11: begin
                storage[write_pointer] <= data;
                write_pointer <= write_pointer + 1'b1;
                read_pointer <= read_pointer + 1'b1;
            end
            default:;
        endcase
    end
endmodule


module w4096_d64 (
    input  logic [63:0] data_a,
    output logic [63:0] q_a,
    input  logic [63:0] data_b,
    output logic [63:0] q_b,
    input  logic [11:0] address_a,
    input  logic [11:0] address_b,
    input  logic        wren_a,
    input  logic        wren_b,
    input  logic        clock,
    input  logic        rden_a,
    input  logic        rden_b
);
    logic [63:0] storage [0:4095];
    logic [11:0] address_a_r;
    logic [11:0] address_b_r;

    initial begin
        q_a = '0;
        q_b = '0;
        address_a_r = '0;
        address_b_r = '0;
    end

    // The generated ram_2port_2060 instance registers both the B-port address
    // and output. Modeling those two edges is required to align the LUT address
    // with wppp_hb_resp's stage_2 payload.
    always @(posedge clock) begin
        address_a_r <= address_a;
        address_b_r <= address_b;

        if (wren_a)
            storage[address_a] <= data_a;
        if (wren_b)
            storage[address_b] <= data_b;

        if (rden_a)
            q_a <= storage[address_a_r];
        if (rden_b)
            q_b <= storage[address_b_r];
    end
endmodule
