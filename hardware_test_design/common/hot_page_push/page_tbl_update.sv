module page_tbl_update
#(
  parameter MIG_GRP_SIZE = 32
)
(
    input  logic         clk,
    input  logic         rst_n,
    input  logic         hppb_tbl_update,   // only one pulse
    input  logic [63:0]  hppb_src_addr[MIG_GRP_SIZE],
    input  logic [63:0]  hppb_dst_addr[MIG_GRP_SIZE],

    input  logic         hint_enq_sel_i,
    input  logic [63:0]  hint_enq_address_i,
    input  logic [15:0]  hint_enq_num_of_cl_i,

    output logic         hint_enq_sel_o,
    output logic [63:0]  hint_enq_address_o,
    output logic [15:0]  hint_enq_num_of_cl_o
);

    logic [63:0] page_tbl_in, page_tbl_in_next;
    logic [63:0] page_tbl_out;
    logic        update_en;
    logic [$clog2(MIG_GRP_SIZE)-1:0] pg_update_idx;

    logic page_tbl_update_vld;
    logic page_tbl_rmw;

    logic [63:0] page_tbl_update_pg_set;
    logic [15:0] page_tbl_hppb_addr;

    logic [63:0] hppb_src_addr_reg[MIG_GRP_SIZE];
    logic [63:0] hppb_dst_addr_reg[MIG_GRP_SIZE];
    logic hppb_tbl_update_reg;
    bram_pgmap_table bram_pgmap_table (  // 0 == page in CXL, 1 == page in HOST 
        .data    (page_tbl_in),
        .address ((hppb_tbl_update_reg | page_tbl_update_vld) ? page_tbl_hppb_addr : hint_enq_address_i[33:18]),
        .wren    (update_en),
        .clock   (clk),
        .q       (page_tbl_out)
    );

    always_ff @(posedge clk) begin
        if (~rst_n) begin
            pg_update_idx <= '0;
            page_tbl_update_vld <= 1'b0;
            page_tbl_rmw <= 1'b0;
            update_en <= 1'b0;
            page_tbl_in <= '0;
            hppb_tbl_update_reg <= 1'b0;
            hppb_src_addr_reg <= '{default:'0};
            hppb_dst_addr_reg <= '{default:'0};
        end else begin
            if (hppb_tbl_update) begin
                hppb_src_addr_reg <= hppb_src_addr;
                hppb_dst_addr_reg <= hppb_dst_addr;
                hppb_tbl_update_reg <= 1'b1;
            end
            if (hppb_tbl_update_reg) begin
                page_tbl_update_vld <= 1'b1;
                hppb_tbl_update_reg <= 1'b0;
            end
            if (page_tbl_update_vld) begin
                if (page_tbl_rmw == 1'b0) begin
                    // Read phase
                    page_tbl_in <= page_tbl_in_next;
                    update_en <= 1'b1;
                end else begin
                    // Write phase
                    update_en <= 1'b0;
                    if (pg_update_idx == MIG_GRP_SIZE-1) begin
                        page_tbl_update_vld <= 1'b0;
                        pg_update_idx <= '0;
                    end else begin
                        pg_update_idx <= pg_update_idx + 1'b1;
                    end
                end
                page_tbl_rmw <= ~page_tbl_rmw;
            end
        end
    end

    logic demotion;
    always_comb begin
        page_tbl_update_pg_set = '0;
        page_tbl_hppb_addr = '0;
        demotion = 1'b0;
        unique case({hppb_src_addr_reg[pg_update_idx] >= 64'h0000008080000000, hppb_dst_addr_reg[pg_update_idx] >= 64'h0000008080000000})
            2'b00: begin // HOST to HOST
                page_tbl_update_pg_set = 64'h0;
            end
            2'b01: begin // HOST to CXL
                page_tbl_update_pg_set = ~(64'(1) << (hppb_dst_addr_reg[pg_update_idx][17:12]));
                page_tbl_hppb_addr = hppb_dst_addr_reg[pg_update_idx][33:18];
                demotion = 1'b1;
            end
            2'b10: begin // CXL to HOST
                page_tbl_update_pg_set = 64'(1) << (hppb_src_addr_reg[pg_update_idx][17:12]);
                page_tbl_hppb_addr = hppb_src_addr_reg[pg_update_idx][33:18];
            end
            2'b11: begin // CXL to CXL
                page_tbl_update_pg_set = 64'h0;
            end
            default:;
        endcase
        page_tbl_in_next = demotion ? page_tbl_out & page_tbl_update_pg_set : page_tbl_out | page_tbl_update_pg_set;
        // page_tbl_update_pg_set =  1 << (hppb_src_addr_reg[pg_update_idx][17:12]);
        // page_tbl_hppb_addr = hppb_src_addr_reg[pg_update_idx][33:18];
    end

    logic [63:0]  hint_enq_address_reg;
    logic [63:0]  hint_enq_address_o_next;
    logic         hint_enq_sel_reg;
    logic [15:0]  hint_enq_num_of_cl_reg;
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            hint_enq_sel_o        <= '0;
            hint_enq_num_of_cl_o  <= '0;
            hint_enq_address_o    <= '0;
            hint_enq_address_reg  <= '0;
            hint_enq_sel_reg       <= '0;
            hint_enq_num_of_cl_reg <= '0;
        end else begin
            hint_enq_sel_reg      <= hint_enq_sel_i;
            hint_enq_sel_o        <= hint_enq_sel_reg;
            hint_enq_num_of_cl_reg <= hint_enq_num_of_cl_i;
            hint_enq_num_of_cl_o  <= hint_enq_num_of_cl_reg;

            hint_enq_address_reg  <= hint_enq_address_i;
            hint_enq_address_o    <= hint_enq_address_o_next;
        end
    end

    logic hint_enq_addr_cancel;
    always_comb begin
        hint_enq_addr_cancel = ((1 << hint_enq_address_reg[17:12]) & page_tbl_out) != 0;
        hint_enq_address_o_next = (page_tbl_update_vld | hint_enq_addr_cancel) ? '0 : hint_enq_address_reg;  // single port
    end

endmodule
