`timescale 1ns/1ps

module fake_mc #(
    parameter int READ_LATENCY = 4,
    parameter logic [63:0] MEM_BASE_ADDR = 64'h0000_0061_8000_0000,
    parameter logic [63:0] MEM_END_ADDR  = 64'h0000_0061_9000_0000
) (
    input logic clk,
    input logic rst_n,

    // Normal host-originated CXL.mem traffic after the AFU pass-through.
    axi_ports.ar_resp host_r_ch,
    axi_ports.aw_resp host_w_ch,

    // Device-biased reads emitted by the two WPPP engines.
    axi_ports.ar_resp db0_r_ch,
    axi_ports.ar_resp db1_r_ch,

    output logic [63:0] host_write_count,
    output logic [63:0] host_read_count,
    output logic [63:0] db_read_count_0,
    output logic [63:0] db_read_count_1,
    output logic [31:0] protocol_error_count
);
    typedef logic [511:0] line_t;
    typedef logic [57:0] line_key_t;
    localparam int DB_QUEUE_DEPTH = 64;
    localparam int DB_QUEUE_PTR_W = $clog2(DB_QUEUE_DEPTH);

    line_t mem [line_key_t];

    logic host_aw_pending;
    logic [11:0] host_awid_reg;
    logic [63:0] host_awaddr_reg;
    logic [5:0] host_awuser_reg;
    logic host_w_pending;
    logic [511:0] host_wdata_reg;
    logic [63:0] host_wstrb_reg;

    logic host_bvalid_reg;
    logic [11:0] host_bid_reg;

    logic host_rd_pending;
    logic [11:0] host_rd_id;
    logic [63:0] host_rd_addr;
    integer host_rd_timer;
    logic host_rvalid_reg;
    logic [11:0] host_rid_reg;
    logic [511:0] host_rdata_reg;

    logic [11:0] db0_id_queue [DB_QUEUE_DEPTH];
    logic [63:0] db0_addr_queue [DB_QUEUE_DEPTH];
    logic [DB_QUEUE_PTR_W-1:0] db0_head;
    logic [DB_QUEUE_PTR_W-1:0] db0_tail;
    integer db0_count;
    integer db0_rd_timer;
    logic db0_rvalid_reg;
    logic [11:0] db0_rid_reg;
    logic [511:0] db0_rdata_reg;

    logic [11:0] db1_id_queue [DB_QUEUE_DEPTH];
    logic [63:0] db1_addr_queue [DB_QUEUE_DEPTH];
    logic [DB_QUEUE_PTR_W-1:0] db1_head;
    logic [DB_QUEUE_PTR_W-1:0] db1_tail;
    integer db1_count;
    integer db1_rd_timer;
    logic db1_rvalid_reg;
    logic [11:0] db1_rid_reg;
    logic [511:0] db1_rdata_reg;

    wire host_aw_fire = host_w_ch.awvalid && host_w_ch.awready;
    wire host_w_fire  = host_w_ch.wvalid && host_w_ch.wready;
    wire host_write_commit =
        (host_aw_pending || host_aw_fire) &&
        (host_w_pending || host_w_fire) &&
        !host_bvalid_reg;
    wire host_aw_error = host_aw_fire &&
        (!addr_in_range(host_w_ch.awaddr) ||
         (host_w_ch.awlen != '0) ||
         (host_w_ch.awsize != 3'b110));
    wire host_w_error = host_w_fire && !host_w_ch.wlast;
    wire host_ar_error = host_r_ch.arvalid && host_r_ch.arready &&
        (!addr_in_range(host_r_ch.araddr) ||
         (host_r_ch.arlen != '0) ||
         (host_r_ch.arsize != 3'b110));
    wire db0_ar_error = db0_r_ch.arvalid && db0_r_ch.arready &&
        (!addr_in_range(db0_r_ch.araddr) ||
         (db0_r_ch.arlen != '0) ||
         (db0_r_ch.arsize != 3'b110) ||
         (db0_r_ch.aruser != 6'b110000));
    wire db1_ar_error = db1_r_ch.arvalid && db1_r_ch.arready &&
        (!addr_in_range(db1_r_ch.araddr) ||
         (db1_r_ch.arlen != '0) ||
         (db1_r_ch.arsize != 3'b110) ||
         (db1_r_ch.aruser != 6'b110000));
    wire db0_enqueue = db0_r_ch.arvalid && db0_r_ch.arready;
    wire db1_enqueue = db1_r_ch.arvalid && db1_r_ch.arready;
    wire db0_launch = !db0_rvalid_reg && (db0_count > 0) &&
                      (db0_rd_timer == 0);
    wire db1_launch = !db1_rvalid_reg && (db1_count > 0) &&
                      (db1_rd_timer == 0);

    function automatic line_key_t line_key(input logic [63:0] addr);
        return addr[63:6];
    endfunction

    function automatic logic addr_in_range(input logic [63:0] addr);
        return (addr >= MEM_BASE_ADDR) && (addr < MEM_END_ADDR);
    endfunction

    function automatic line_t read_line(input logic [63:0] addr);
        line_key_t key;
        key = line_key(addr);
        if (mem.exists(key)) begin
            return mem[key];
        end
        return '0;
    endfunction

    function automatic line_t merge_line(
        input line_t old_data,
        input line_t new_data,
        input logic [63:0] byte_enable
    );
        line_t result;
        result = old_data;
        for (int byte_idx = 0; byte_idx < 64; byte_idx++) begin
            if (byte_enable[byte_idx]) begin
                result[(byte_idx * 8) +: 8] =
                    new_data[(byte_idx * 8) +: 8];
            end
        end
        return result;
    endfunction

    assign host_w_ch.awready = rst_n && !host_aw_pending && !host_bvalid_reg;
    assign host_w_ch.wready  = rst_n && !host_w_pending && !host_bvalid_reg;
    assign host_w_ch.bid     = host_bid_reg;
    assign host_w_ch.bresp   = 2'b00;
    assign host_w_ch.buser   = '0;
    assign host_w_ch.bvalid  = host_bvalid_reg;

    assign host_r_ch.arready = rst_n && !host_rd_pending && !host_rvalid_reg;
    assign host_r_ch.rid     = host_rid_reg;
    assign host_r_ch.rdata   = host_rdata_reg;
    assign host_r_ch.rresp   = 2'b00;
    assign host_r_ch.rlast   = 1'b1;
    assign host_r_ch.ruser   = 1'b0;
    assign host_r_ch.rvalid  = host_rvalid_reg;

    assign db0_r_ch.arready = rst_n && (db0_count < DB_QUEUE_DEPTH);
    assign db0_r_ch.rid     = db0_rid_reg;
    assign db0_r_ch.rdata   = db0_rdata_reg;
    assign db0_r_ch.rresp   = 2'b00;
    assign db0_r_ch.rlast   = 1'b1;
    assign db0_r_ch.ruser   = 1'b0;
    assign db0_r_ch.rvalid  = db0_rvalid_reg;

    assign db1_r_ch.arready = rst_n && (db1_count < DB_QUEUE_DEPTH);
    assign db1_r_ch.rid     = db1_rid_reg;
    assign db1_r_ch.rdata   = db1_rdata_reg;
    assign db1_r_ch.rresp   = 2'b00;
    assign db1_r_ch.rlast   = 1'b1;
    assign db1_r_ch.ruser   = 1'b0;
    assign db1_r_ch.rvalid  = db1_rvalid_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mem.delete();
            host_aw_pending <= 1'b0;
            host_awid_reg <= '0;
            host_awaddr_reg <= '0;
            host_awuser_reg <= '0;
            host_w_pending <= 1'b0;
            host_wdata_reg <= '0;
            host_wstrb_reg <= '0;
            host_bvalid_reg <= 1'b0;
            host_bid_reg <= '0;
            host_write_count <= '0;
        end else begin
            if (host_bvalid_reg && host_w_ch.bready) begin
                host_bvalid_reg <= 1'b0;
            end

            if (host_aw_fire) begin
                host_aw_pending <= 1'b1;
                host_awid_reg <= host_w_ch.awid;
                host_awaddr_reg <= host_w_ch.awaddr;
                host_awuser_reg <= host_w_ch.awuser;
                if (!addr_in_range(host_w_ch.awaddr) ||
                    (host_w_ch.awlen != '0) ||
                    (host_w_ch.awsize != 3'b110)) begin
                    $error("WPPP_INT_CHECK_ERROR: fake MC rejected host AW addr=%h len=%0d size=%0d",
                           host_w_ch.awaddr, host_w_ch.awlen,
                           host_w_ch.awsize);
                end
            end

            if (host_w_fire) begin
                host_w_pending <= 1'b1;
                host_wdata_reg <= host_w_ch.wdata;
                host_wstrb_reg <= host_w_ch.wstrb;
                if (!host_w_ch.wlast) begin
                    $error("WPPP_INT_CHECK_ERROR: fake MC requires single-beat host writes");
                end
            end

            if (host_write_commit) begin : HOST_WRITE_COMMIT
                logic [63:0] commit_addr;
                logic [11:0] commit_id;
                line_t commit_data;
                logic [63:0] commit_strb;
                line_t old_data;

                commit_addr = host_aw_fire ? host_w_ch.awaddr : host_awaddr_reg;
                commit_id = host_aw_fire ? host_w_ch.awid : host_awid_reg;
                commit_data = host_w_fire ? host_w_ch.wdata : host_wdata_reg;
                commit_strb = host_w_fire ? host_w_ch.wstrb : host_wstrb_reg;
                old_data = read_line(commit_addr);
                mem[line_key(commit_addr)] =
                    merge_line(old_data, commit_data, commit_strb);

                host_aw_pending <= 1'b0;
                host_w_pending <= 1'b0;
                host_bid_reg <= commit_id;
                host_bvalid_reg <= 1'b1;
                host_write_count <= host_write_count + 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            host_rd_pending <= 1'b0;
            host_rd_id <= '0;
            host_rd_addr <= '0;
            host_rd_timer <= 0;
            host_rvalid_reg <= 1'b0;
            host_rid_reg <= '0;
            host_rdata_reg <= '0;
            host_read_count <= '0;
        end else begin
            if (host_rvalid_reg && host_r_ch.rready) begin
                host_rvalid_reg <= 1'b0;
            end

            if (host_r_ch.arvalid && host_r_ch.arready) begin
                host_rd_pending <= 1'b1;
                host_rd_id <= host_r_ch.arid;
                host_rd_addr <= host_r_ch.araddr;
                host_rd_timer <= READ_LATENCY;
                host_read_count <= host_read_count + 1'b1;
                if (!addr_in_range(host_r_ch.araddr) ||
                    (host_r_ch.arlen != '0) ||
                    (host_r_ch.arsize != 3'b110)) begin
                    $error("WPPP_INT_CHECK_ERROR: fake MC rejected host AR addr=%h len=%0d size=%0d",
                           host_r_ch.araddr, host_r_ch.arlen,
                           host_r_ch.arsize);
                end
            end else if (host_rd_pending && (host_rd_timer > 0)) begin
                host_rd_timer <= host_rd_timer - 1;
            end else if (host_rd_pending && !host_rvalid_reg) begin
                host_rd_pending <= 1'b0;
                host_rid_reg <= host_rd_id;
                host_rdata_reg <= read_line(host_rd_addr);
                host_rvalid_reg <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            db0_head <= '0;
            db0_tail <= '0;
            db0_count <= 0;
            db0_rd_timer <= 0;
            db0_rvalid_reg <= 1'b0;
            db0_rid_reg <= '0;
            db0_rdata_reg <= '0;
            db_read_count_0 <= '0;
        end else begin
            if (db0_rvalid_reg && db0_r_ch.rready) begin
                db0_rvalid_reg <= 1'b0;
            end

            if (db0_enqueue) begin
                db0_id_queue[db0_tail] <= db0_r_ch.arid;
                db0_addr_queue[db0_tail] <= db0_r_ch.araddr;
                db0_tail <= db0_tail + 1'b1;
                db_read_count_0 <= db_read_count_0 + 1'b1;
                if (!addr_in_range(db0_r_ch.araddr) ||
                    (db0_r_ch.arlen != '0) ||
                    (db0_r_ch.arsize != 3'b110) ||
                    (db0_r_ch.aruser != 6'b110000)) begin
                    $error("WPPP_INT_CHECK_ERROR: invalid DB0 read addr=%h user=%b",
                           db0_r_ch.araddr, db0_r_ch.aruser);
                end
            end

            if (!db0_rvalid_reg && (db0_count > 0) &&
                (db0_rd_timer > 0)) begin
                db0_rd_timer <= db0_rd_timer - 1;
            end else if (db0_launch) begin
                db0_head <= db0_head + 1'b1;
                db0_rid_reg <= db0_id_queue[db0_head];
                db0_rdata_reg <= read_line(db0_addr_queue[db0_head]);
                db0_rvalid_reg <= 1'b1;
                db0_rd_timer <= READ_LATENCY;
            end else if (db0_enqueue && (db0_count == 0)) begin
                db0_rd_timer <= READ_LATENCY;
            end

            unique case ({db0_enqueue, db0_launch})
                2'b10: db0_count <= db0_count + 1;
                2'b01: db0_count <= db0_count - 1;
                default: db0_count <= db0_count;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            db1_head <= '0;
            db1_tail <= '0;
            db1_count <= 0;
            db1_rd_timer <= 0;
            db1_rvalid_reg <= 1'b0;
            db1_rid_reg <= '0;
            db1_rdata_reg <= '0;
            db_read_count_1 <= '0;
        end else begin
            if (db1_rvalid_reg && db1_r_ch.rready) begin
                db1_rvalid_reg <= 1'b0;
            end

            if (db1_enqueue) begin
                db1_id_queue[db1_tail] <= db1_r_ch.arid;
                db1_addr_queue[db1_tail] <= db1_r_ch.araddr;
                db1_tail <= db1_tail + 1'b1;
                db_read_count_1 <= db_read_count_1 + 1'b1;
                if (!addr_in_range(db1_r_ch.araddr) ||
                    (db1_r_ch.arlen != '0) ||
                    (db1_r_ch.arsize != 3'b110) ||
                    (db1_r_ch.aruser != 6'b110000)) begin
                    $error("WPPP_INT_CHECK_ERROR: invalid DB1 read addr=%h user=%b",
                           db1_r_ch.araddr, db1_r_ch.aruser);
                end
            end

            if (!db1_rvalid_reg && (db1_count > 0) &&
                (db1_rd_timer > 0)) begin
                db1_rd_timer <= db1_rd_timer - 1;
            end else if (db1_launch) begin
                db1_head <= db1_head + 1'b1;
                db1_rid_reg <= db1_id_queue[db1_head];
                db1_rdata_reg <= read_line(db1_addr_queue[db1_head]);
                db1_rvalid_reg <= 1'b1;
                db1_rd_timer <= READ_LATENCY;
            end else if (db1_enqueue && (db1_count == 0)) begin
                db1_rd_timer <= READ_LATENCY;
            end

            unique case ({db1_enqueue, db1_launch})
                2'b10: db1_count <= db1_count + 1;
                2'b01: db1_count <= db1_count - 1;
                default: db1_count <= db1_count;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            protocol_error_count <= '0;
        end else begin
            protocol_error_count <= protocol_error_count +
                host_aw_error + host_w_error + host_ar_error +
                db0_ar_error + db1_ar_error;
        end
    end

    task automatic backdoor_write(
        input logic [63:0] addr,
        input logic [511:0] data
    );
        if (!addr_in_range(addr)) begin
            $error("WPPP_INT_CHECK_ERROR: fake MC backdoor write out of range: %h", addr);
        end else begin
            mem[line_key(addr)] = data;
        end
    endtask

    task automatic backdoor_read(
        input  logic [63:0] addr,
        output logic [511:0] data,
        output logic present
    );
        present = mem.exists(line_key(addr));
        data = read_line(addr);
    endtask
endmodule
