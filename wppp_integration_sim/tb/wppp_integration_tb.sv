`timescale 1ns/1ps

module wppp_integration_tb;
    localparam logic [63:0] MEM_BASE = 64'h0000_0061_8000_0000;
    localparam logic [63:0] MEM_END  = 64'h0000_0061_9000_0000;
    localparam logic [63:0] HINT_PAGE = MEM_BASE + 64'h0010_0000;
    localparam logic [33:0] WPPP_SPAN = 34'h0100_0000;
    localparam int TIMEOUT_CYCLES = 50000;

    logic clk;
    logic rst_n;
    logic enable_wppp;
    logic flush_lut;

    logic [63:0] prefetch_ok_cnt_0;
    logic [63:0] prefetch_ok_cnt_1;
    logic hppb_activity;
    logic hint_enq_sel_debug;
    logic [63:0] hint_enq_address_debug;
    logic [15:0] hint_enq_count_debug;

    logic [63:0] cpu_write_count_0;
    logic [63:0] cpu_write_count_1;
    logic [31:0] cxlip_protocol_errors;
    logic [63:0] host_write_count;
    logic [63:0] host_read_count;
    logic [63:0] db_read_count_0;
    logic [63:0] db_read_count_1;
    logic [31:0] mc_protocol_errors;

    integer check_errors;
    string active_test;
    bit trace_enabled;

    axi_ports host_agent_ports();
    axi_ports cxl_to_dut_ports();
    axi_ports dut_to_mc_ports();
    axi_ports wppp0_cxl_ports();
    axi_ports wppp1_cxl_ports();
    axi_ports db0_mc_ports();
    axi_ports db1_mc_ports();

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial trace_enabled = $test$plusargs("WPPP_INT_TRACE");

    always @(posedge clk) begin
        if (trace_enabled) begin
            if (host_agent_ports.awvalid &&
                (host_agent_ports.awaddr[51:12] == HINT_PAGE[51:12])) begin
                $display("WPPP_INT_TRACE: hint write addr=%h data=%h",
                         host_agent_ports.awaddr, host_agent_ports.wdata);
            end
            if (dut.hint_enq_address_i != '0) begin
                $display("WPPP_INT_TRACE: snoop sel=%0d addr=%h count=%0d",
                         dut.hint_enq_sel_i, dut.hint_enq_address_i,
                         dut.hint_enq_num_of_cl_i);
            end
            if (hint_enq_address_debug != '0) begin
                $display("WPPP_INT_TRACE: enqueue sel=%0d addr=%h count=%0d",
                         hint_enq_sel_debug, hint_enq_address_debug,
                         hint_enq_count_debug);
            end
            if (wppp0_cxl_ports.arvalid && wppp0_cxl_ports.arready) begin
                $display("WPPP_INT_TRACE: db0 AR id=%0d addr=%h",
                         wppp0_cxl_ports.arid, wppp0_cxl_ports.araddr);
            end
            if (wppp1_cxl_ports.arvalid && wppp1_cxl_ports.arready) begin
                $display("WPPP_INT_TRACE: db1 AR id=%0d addr=%h",
                         wppp1_cxl_ports.arid, wppp1_cxl_ports.araddr);
            end
        end
    end

    fake_cxlip fake_cxlip_inst (
        .clk(clk),
        .rst_n(rst_n),
        .host_agent_r_ch(host_agent_ports.ar_resp),
        .host_agent_w_ch(host_agent_ports.aw_resp),
        .host_dut_r_ch(cxl_to_dut_ports.ar_req),
        .host_dut_w_ch(cxl_to_dut_ports.aw_req),
        .wppp0_r_ch(wppp0_cxl_ports.ar_resp),
        .wppp0_w_ch(wppp0_cxl_ports.aw_resp),
        .wppp1_r_ch(wppp1_cxl_ports.ar_resp),
        .wppp1_w_ch(wppp1_cxl_ports.aw_resp),
        .db0_mc_r_ch(db0_mc_ports.ar_req),
        .db1_mc_r_ch(db1_mc_ports.ar_req),
        .cpu_write_count_0(cpu_write_count_0),
        .cpu_write_count_1(cpu_write_count_1),
        .protocol_error_count(cxlip_protocol_errors)
    );

    wppp_integration_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .host_cxl_r_ch(cxl_to_dut_ports.ar_resp),
        .host_cxl_w_ch(cxl_to_dut_ports.aw_resp),
        .host_mc_r_ch(dut_to_mc_ports.ar_req),
        .host_mc_w_ch(dut_to_mc_ports.aw_req),
        .cxl_wppp0_r_ch(wppp0_cxl_ports.ar_req),
        .cxl_wppp0_w_ch(wppp0_cxl_ports.aw_req),
        .cxl_wppp1_r_ch(wppp1_cxl_ports.ar_req),
        .cxl_wppp1_w_ch(wppp1_cxl_ports.aw_req),
        .hint_mech_addr(HINT_PAGE),
        .cxl_start_pa(MEM_BASE),
        .address_lower('0),
        .address_span(WPPP_SPAN),
        .enable_wppp(enable_wppp),
        .flush_lut(flush_lut),
        .prefetch_ok_cnt_0(prefetch_ok_cnt_0),
        .prefetch_ok_cnt_1(prefetch_ok_cnt_1),
        .hppb_activity(hppb_activity),
        .hint_enq_sel_debug(hint_enq_sel_debug),
        .hint_enq_address_debug(hint_enq_address_debug),
        .hint_enq_count_debug(hint_enq_count_debug)
    );

    fake_mc #(
        .READ_LATENCY(4),
        .MEM_BASE_ADDR(MEM_BASE),
        .MEM_END_ADDR(MEM_END)
    ) fake_mc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .host_r_ch(dut_to_mc_ports.ar_resp),
        .host_w_ch(dut_to_mc_ports.aw_resp),
        .db0_r_ch(db0_mc_ports.ar_resp),
        .db1_r_ch(db1_mc_ports.ar_resp),
        .host_write_count(host_write_count),
        .host_read_count(host_read_count),
        .db_read_count_0(db_read_count_0),
        .db_read_count_1(db_read_count_1),
        .protocol_error_count(mc_protocol_errors)
    );

    function automatic logic [511:0] line_pattern(
        input logic [63:0] addr,
        input logic [15:0] tag
    );
        logic [511:0] value;
        value = '0;
        for (int lane = 0; lane < 8; lane++) begin
            value[(lane * 64) +: 64] =
                {tag, 8'(lane), addr[39:0]};
        end
        return value;
    endfunction

    function automatic logic [63:0] packed_hint(
        input logic [63:0] addr,
        input int unsigned count
    );
        return {14'(count), addr[49:0]};
    endfunction

    task automatic record_error(input string message);
        check_errors = check_errors + 1;
        $display("WPPP_INT_CHECK_ERROR: %s", message);
    endtask

    task automatic initialize_host_agent();
        host_agent_ports.arid = '0;
        host_agent_ports.araddr = '0;
        host_agent_ports.arlen = '0;
        host_agent_ports.arsize = 3'b110;
        host_agent_ports.arburst = '0;
        host_agent_ports.arprot = '0;
        host_agent_ports.arqos = '0;
        host_agent_ports.aruser = '0;
        host_agent_ports.arvalid = 1'b0;
        host_agent_ports.arcache = '0;
        host_agent_ports.arlock = '0;
        host_agent_ports.arregion = '0;
        host_agent_ports.rready = 1'b0;

        host_agent_ports.awid = '0;
        host_agent_ports.awaddr = '0;
        host_agent_ports.awlen = '0;
        host_agent_ports.awsize = 3'b110;
        host_agent_ports.awburst = '0;
        host_agent_ports.awprot = '0;
        host_agent_ports.awqos = '0;
        host_agent_ports.awuser = '0;
        host_agent_ports.awvalid = 1'b0;
        host_agent_ports.awcache = '0;
        host_agent_ports.awlock = '0;
        host_agent_ports.awregion = '0;
        host_agent_ports.awatop = '0;
        host_agent_ports.wdata = '0;
        host_agent_ports.wstrb = '0;
        host_agent_ports.wlast = 1'b1;
        host_agent_ports.wuser = 1'b0;
        host_agent_ports.wvalid = 1'b0;
        host_agent_ports.bready = 1'b0;
    endtask

    task automatic host_write(
        input logic [63:0] addr,
        input logic [511:0] data,
        input logic [11:0] id
    );
        int cycles;

        @(negedge clk);
        host_agent_ports.awid = id;
        host_agent_ports.awaddr = addr;
        host_agent_ports.awvalid = 1'b1;
        host_agent_ports.wdata = data;
        host_agent_ports.wstrb = 64'hffff_ffff_ffff_ffff;
        host_agent_ports.wlast = 1'b1;
        host_agent_ports.wvalid = 1'b1;

        cycles = 0;
        #1;
        while (!(host_agent_ports.awready && host_agent_ports.wready)) begin
            @(negedge clk);
            cycles++;
            if ((host_agent_ports.awready === 1'b1) !=
                (host_agent_ports.wready === 1'b1)) begin
                record_error($sformatf(
                    "host AW/W ready diverged for synchronous write addr=%h awready=%b wready=%b",
                    addr, host_agent_ports.awready, host_agent_ports.wready));
            end
            if (cycles > 1000) begin
                record_error($sformatf("host write request timeout addr=%h", addr));
                return;
            end
        end
        @(posedge clk);

        @(negedge clk);
        host_agent_ports.awvalid = 1'b0;
        host_agent_ports.wvalid = 1'b0;

        cycles = 0;
        while (host_agent_ports.bvalid !== 1'b1) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles > 1000) begin
                record_error($sformatf("host B timeout addr=%h", addr));
                return;
            end
        end
        if ((host_agent_ports.bid !== id) ||
            (host_agent_ports.bresp !== 2'b00)) begin
            record_error($sformatf(
                "host B mismatch addr=%h expected_id=%0d got_id=%0d resp=%b",
                addr, id, host_agent_ports.bid, host_agent_ports.bresp));
        end

        @(negedge clk);
        host_agent_ports.bready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        host_agent_ports.bready = 1'b0;
    endtask

    task automatic host_read(
        input  logic [63:0] addr,
        input  logic [11:0] id,
        output logic [511:0] data
    );
        int cycles;

        @(negedge clk);
        host_agent_ports.arid = id;
        host_agent_ports.araddr = addr;
        host_agent_ports.arvalid = 1'b1;

        cycles = 0;
        #1;
        while (host_agent_ports.arready !== 1'b1) begin
            @(negedge clk);
            cycles++;
            if (cycles > 1000) begin
                record_error($sformatf("host AR timeout addr=%h", addr));
                data = 'x;
                return;
            end
        end

        @(posedge clk);
        @(negedge clk);
        host_agent_ports.arvalid = 1'b0;

        cycles = 0;
        while (host_agent_ports.rvalid !== 1'b1) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles > 1000) begin
                record_error($sformatf("host R timeout addr=%h", addr));
                data = 'x;
                return;
            end
        end
        data = host_agent_ports.rdata;
        if ((host_agent_ports.rid !== id) ||
            (host_agent_ports.rresp !== 2'b00) ||
            !host_agent_ports.rlast) begin
            record_error($sformatf(
                "host R metadata mismatch addr=%h expected_id=%0d got_id=%0d resp=%b last=%b",
                addr, id, host_agent_ports.rid,
                host_agent_ports.rresp, host_agent_ports.rlast));
        end

        @(negedge clk);
        host_agent_ports.rready = 1'b1;
        @(posedge clk);
        @(negedge clk);
        host_agent_ports.rready = 1'b0;
    endtask

    task automatic wait_for_cpu_writes(
        input int expected_total,
        input int max_cycles
    );
        int cycles;
        cycles = 0;
        while ((cpu_write_count_0 + cpu_write_count_1) < expected_total) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= max_cycles) begin
                record_error($sformatf(
                    "CPU write timeout expected=%0d observed=%0d+%0d db_reads=%0d+%0d",
                    expected_total, cpu_write_count_0, cpu_write_count_1,
                    db_read_count_0, db_read_count_1));
                return;
            end
        end
        repeat (8) @(posedge clk);
    endtask

    task automatic check_cpu_line(
        input int channel,
        input logic [63:0] addr,
        input logic [511:0] expected
    );
        logic [511:0] observed;
        logic present;
        fake_cxlip_inst.cpu_backdoor_read(channel, addr, observed, present);
        if (!present) begin
            record_error($sformatf(
                "missing CPU-side NCP write channel=%0d addr=%h", channel, addr));
        end else if (observed !== expected) begin
            record_error($sformatf(
                "CPU-side NCP data mismatch channel=%0d addr=%h expected=%h observed=%h",
                channel, addr, expected, observed));
        end
    endtask

    task automatic check_global_contract(
        input int expected_db0,
        input int expected_db1,
        input int expected_cpu0,
        input int expected_cpu1
    );
        if (hppb_activity !== 1'b0) begin
            record_error("inactive HPPB reported activity");
        end
        if (db_read_count_0 != expected_db0 ||
            db_read_count_1 != expected_db1) begin
            record_error($sformatf(
                "DB read count mismatch expected=%0d+%0d observed=%0d+%0d",
                expected_db0, expected_db1,
                db_read_count_0, db_read_count_1));
        end
        if (cpu_write_count_0 != expected_cpu0 ||
            cpu_write_count_1 != expected_cpu1) begin
            record_error($sformatf(
                "CPU write count mismatch expected=%0d+%0d observed=%0d+%0d",
                expected_cpu0, expected_cpu1,
                cpu_write_count_0, cpu_write_count_1));
        end
        if (prefetch_ok_cnt_0 != expected_cpu0 ||
            prefetch_ok_cnt_1 != expected_cpu1) begin
            record_error($sformatf(
                "WPPP success count mismatch expected=%0d+%0d observed=%0d+%0d",
                expected_cpu0, expected_cpu1,
                prefetch_ok_cnt_0, prefetch_ok_cnt_1));
        end
        if (cxlip_protocol_errors != 0 || mc_protocol_errors != 0) begin
            record_error($sformatf(
                "model protocol errors cxlip=%0d mc=%0d",
                cxlip_protocol_errors, mc_protocol_errors));
        end
    endtask

    task automatic run_host_rw();
        logic [63:0] addr;
        logic [511:0] expected;
        logic [511:0] observed;

        addr = MEM_BASE + 64'h0000_4000;
        expected = line_pattern(addr, 16'h1001);
        host_write(addr, expected, 12'h021);
        host_read(addr, 12'h121, observed);
        if (observed !== expected) begin
            record_error($sformatf(
                "host pass-through data mismatch addr=%h expected=%h observed=%h",
                addr, expected, observed));
        end
        repeat (16) @(posedge clk);
        check_global_contract(0, 0, 0, 0);
    endtask

    task automatic run_single_hint();
        logic [63:0] base_addr;
        logic [511:0] expected [4];
        logic [511:0] hint_line;

        base_addr = MEM_BASE + 64'h0000_8000;
        for (int i = 0; i < 4; i++) begin
            expected[i] = line_pattern(base_addr + (i * 64), 16'h2000 + i);
            host_write(base_addr + (i * 64), expected[i], 12'h040 + i);
        end

        hint_line = '0;
        hint_line[0 +: 64] = packed_hint(base_addr, 4);
        host_write(HINT_PAGE, hint_line, 12'h080);

        wait_for_cpu_writes(4, 10000);
        for (int i = 0; i < 4; i++) begin
            check_cpu_line(0, base_addr + (i * 64), expected[i]);
        end
        check_global_contract(4, 0, 4, 0);
    endtask

    task automatic run_hint_batch();
        logic [63:0] addr [8];
        logic [511:0] expected [8][2];
        logic [511:0] hint_line;

        hint_line = '0;
        for (int i = 0; i < 8; i++) begin
            addr[i] = MEM_BASE + 64'h0002_0000 + (i * 64'h0000_0400);
            for (int line = 0; line < 2; line++) begin
                expected[i][line] = line_pattern(
                    addr[i] + (line * 64), 16'h3000 + (i * 2) + line);
                host_write(addr[i] + (line * 64), expected[i][line],
                           12'h100 + (i * 2) + line);
            end
            // Two cachelines per packed entry keeps this expected-pass test
            // independent of open bug WPPP-AR-DEQUEUE-001. Its one-line and
            // final-AR-stall behavior remains covered by wppp_sim/sim-repro.
            hint_line[(i * 64) +: 64] = packed_hint(addr[i], 2);
        end
        host_write(HINT_PAGE + 64'h40, hint_line, 12'h180);

        wait_for_cpu_writes(16, 15000);
        for (int i = 0; i < 8; i++) begin
            for (int line = 0; line < 2; line++) begin
                check_cpu_line(i % 2, addr[i] + (line * 64),
                               expected[i][line]);
            end
        end
        check_global_contract(8, 8, 8, 8);
    endtask

    task automatic run_host_and_hint();
        logic [63:0] push_base;
        logic [63:0] host_addr;
        logic [511:0] push_data [4];
        logic [511:0] host_data;
        logic [511:0] host_observed;
        logic [511:0] hint_line;

        push_base = MEM_BASE + 64'h0004_0000;
        host_addr = MEM_BASE + 64'h0006_0000;
        for (int i = 0; i < 4; i++) begin
            push_data[i] = line_pattern(push_base + (i * 64), 16'h4000 + i);
            host_write(push_base + (i * 64), push_data[i], 12'h200 + i);
        end

        hint_line = '0;
        hint_line[0 +: 64] = packed_hint(push_base, 4);
        host_write(HINT_PAGE + 64'h80, hint_line, 12'h240);

        // This host transaction overlaps the WPPP device reads and CPU pushes.
        host_data = line_pattern(host_addr, 16'h4f00);
        host_write(host_addr, host_data, 12'h241);
        host_read(host_addr, 12'h242, host_observed);
        if (host_observed !== host_data) begin
            record_error("concurrent host read/write data mismatch");
        end

        wait_for_cpu_writes(4, 10000);
        for (int i = 0; i < 4; i++) begin
            check_cpu_line(0, push_base + (i * 64), push_data[i]);
        end
        check_global_contract(4, 0, 4, 0);
    endtask

    always_ff @(posedge clk) begin
        if (rst_n && hppb_activity) begin
            record_error("inactive HPPB interfered with the WPPP path");
        end
    end

    initial begin : WATCHDOG
        repeat (TIMEOUT_CYCLES) @(posedge clk);
        $fatal(1, "WPPP_INT_TEST_FAIL: global timeout test=%s", active_test);
    end

    initial begin : TEST_MAIN
        rst_n = 1'b0;
        enable_wppp = 1'b0;
        flush_lut = 1'b0;
        check_errors = 0;
        active_test = "";
        initialize_host_agent();

        repeat (8) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        enable_wppp = 1'b1;
        repeat (8) @(posedge clk);

        if ($test$plusargs("RUN_INT_HOST_RW")) begin
            active_test = "RUN_INT_HOST_RW";
            run_host_rw();
        end else if ($test$plusargs("RUN_INT_SINGLE_HINT")) begin
            active_test = "RUN_INT_SINGLE_HINT";
            run_single_hint();
        end else if ($test$plusargs("RUN_INT_HINT_BATCH")) begin
            active_test = "RUN_INT_HINT_BATCH";
            run_hint_batch();
        end else if ($test$plusargs("RUN_INT_HOST_AND_HINT")) begin
            active_test = "RUN_INT_HOST_AND_HINT";
            run_host_and_hint();
        end else if ($test$plusargs("RUN_INT_HPPB_INACTIVE")) begin
            active_test = "RUN_INT_HPPB_INACTIVE";
            run_hint_batch();
        end else begin
            active_test = "RUN_INT_HOST_RW";
            run_host_rw();
        end

        if (check_errors != 0) begin
            $fatal(1, "WPPP_INT_TEST_FAIL: %s errors=%0d", active_test, check_errors);
        end

        $display("WPPP_TEST_PASS: %s", active_test);
        $finish;
    end
endmodule
