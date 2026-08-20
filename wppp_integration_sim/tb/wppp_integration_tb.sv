`timescale 1ns/1ps

module wppp_integration_tb #(
    parameter bit USE_ATC = 1'b0
);
    localparam logic [63:0] MEM_BASE = 64'h0000_0061_8000_0000;
    localparam logic [63:0] MEM_END  = 64'h0000_0061_9000_0000;
    localparam logic [63:0] HINT_PAGE = MEM_BASE + 64'h0010_0000;
    localparam logic [63:0] ATC_OFFSET = 64'h0000_0001_0000_0000;
    localparam logic [33:0] WPPP_SPAN = 34'h0100_0000;
    localparam int TIMEOUT_CYCLES = 50000;
    localparam int MAX_DB_REQUESTS = 64;

    logic clk;
    logic rst_n;
    logic enable_wppp;
    logic flush_lut;
    logic flush_translation;

    logic [63:0] prefetch_ok_cnt_0;
    logic [63:0] prefetch_ok_cnt_1;
    logic hppb_activity;
    logic hint_enq_sel_debug;
    logic [63:0] hint_enq_address_debug;
    logic [15:0] hint_enq_count_debug;
    logic translation_flush_busy;
    logic [63:0] translation_status;
    logic [63:0] translation_stats [0:16];

    logic [63:0] cpu_write_count_0;
    logic [63:0] cpu_write_count_1;
    logic [31:0] cxlip_protocol_errors;
    logic [63:0] host_write_count;
    logic [63:0] host_read_count;
    logic [63:0] db_read_count_0;
    logic [63:0] db_read_count_1;
    logic [31:0] mc_protocol_errors;

    integer check_errors;
    integer atc_init_cycles;
    string active_test;
    bit trace_enabled;

    logic [11:0] db0_req_id_log [0:MAX_DB_REQUESTS-1];
    logic [63:0] db0_req_addr_log [0:MAX_DB_REQUESTS-1];
    logic [11:0] db1_req_id_log [0:MAX_DB_REQUESTS-1];
    logic [63:0] db1_req_addr_log [0:MAX_DB_REQUESTS-1];
    integer db0_req_log_count;
    integer db1_req_log_count;
    logic [11:0] injected_db_id;
    logic [511:0] injected_db_data;

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

    // Retain accepted DB requests for ordering checks and directed response
    // injection. This is verification-only state; the DUT and endpoint RTL are
    // left unchanged.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            db0_req_log_count <= 0;
            db1_req_log_count <= 0;
        end else begin
            if (db0_mc_ports.arvalid && db0_mc_ports.arready) begin
                if (db0_req_log_count < MAX_DB_REQUESTS) begin
                    db0_req_id_log[db0_req_log_count] <= db0_mc_ports.arid;
                    db0_req_addr_log[db0_req_log_count] <= db0_mc_ports.araddr;
                    db0_req_log_count <= db0_req_log_count + 1;
                end else begin
                    $error("WPPP_INT_CHECK_ERROR: DB0 request log overflow");
                end
            end
            if (db1_mc_ports.arvalid && db1_mc_ports.arready) begin
                if (db1_req_log_count < MAX_DB_REQUESTS) begin
                    db1_req_id_log[db1_req_log_count] <= db1_mc_ports.arid;
                    db1_req_addr_log[db1_req_log_count] <= db1_mc_ports.araddr;
                    db1_req_log_count <= db1_req_log_count + 1;
                end else begin
                    $error("WPPP_INT_CHECK_ERROR: DB1 request log overflow");
                end
            end
        end
    end

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

    wppp_integration_top #(
        .LEGACY_HINT_FORMAT(!USE_ATC),
        .LEGACY_DIRECT_MODE(!USE_ATC)
    ) dut (
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
        .translation_offset(USE_ATC ? ATC_OFFSET : 64'b0),
        .flush_translation(flush_translation),
        .prefetch_ok_cnt_0(prefetch_ok_cnt_0),
        .prefetch_ok_cnt_1(prefetch_ok_cnt_1),
        .hppb_activity(hppb_activity),
        .hint_enq_sel_debug(hint_enq_sel_debug),
        .hint_enq_address_debug(hint_enq_address_debug),
        .hint_enq_count_debug(hint_enq_count_debug),
        .translation_flush_busy(translation_flush_busy),
        .translation_status(translation_status),
        .translation_stats(translation_stats)
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

    function automatic logic [63:0] packed_atc_hint(
        input logic [63:0] va,
        input int unsigned count
    );
        return {6'b0, 16'(count), va[47:6]};
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

    task automatic wait_for_db_reads(
        input int expected_db0,
        input int expected_db1,
        input int max_cycles
    );
        int cycles;
        cycles = 0;
        while ((db_read_count_0 < expected_db0) ||
               (db_read_count_1 < expected_db1)) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= max_cycles) begin
                record_error($sformatf(
                    "DB read timeout expected=%0d+%0d observed=%0d+%0d",
                    expected_db0, expected_db1,
                    db_read_count_0, db_read_count_1));
                return;
            end
        end
    endtask

    task automatic wait_for_translation_stat(
        input int stat_index,
        input longint unsigned expected_minimum,
        input int max_cycles
    );
        int cycles;
        cycles = 0;
        while (translation_stats[stat_index] < expected_minimum) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= max_cycles) begin
                record_error($sformatf(
                    "translation stat timeout index=%0d expected>=%0d observed=%0d",
                    stat_index, expected_minimum,
                    translation_stats[stat_index]));
                return;
            end
        end
    endtask

    task automatic inject_db_response(
        input int channel,
        input logic [11:0] id,
        input logic [511:0] data
    );
        @(negedge clk);
        injected_db_id = id;
        injected_db_data = data;
        if (channel == 0) begin
            force db0_mc_ports.rid = injected_db_id;
            force db0_mc_ports.rdata = injected_db_data;
            force db0_mc_ports.rresp = 2'b00;
            force db0_mc_ports.rlast = 1'b1;
            force db0_mc_ports.ruser = 1'b0;
            force db0_mc_ports.rvalid = 1'b1;
            @(posedge clk);
            #1;
            if (db0_mc_ports.rready !== 1'b1) begin
                record_error("DB0 response was not accepted");
            end
            @(negedge clk);
            force db0_mc_ports.rvalid = 1'b0;
            release db0_mc_ports.rid;
            release db0_mc_ports.rdata;
            release db0_mc_ports.rresp;
            release db0_mc_ports.rlast;
            release db0_mc_ports.ruser;
        end else begin
            force db1_mc_ports.rid = injected_db_id;
            force db1_mc_ports.rdata = injected_db_data;
            force db1_mc_ports.rresp = 2'b00;
            force db1_mc_ports.rlast = 1'b1;
            force db1_mc_ports.ruser = 1'b0;
            force db1_mc_ports.rvalid = 1'b1;
            @(posedge clk);
            #1;
            if (db1_mc_ports.rready !== 1'b1) begin
                record_error("DB1 response was not accepted");
            end
            @(negedge clk);
            force db1_mc_ports.rvalid = 1'b0;
            release db1_mc_ports.rid;
            release db1_mc_ports.rdata;
            release db1_mc_ports.rresp;
            release db1_mc_ports.rlast;
            release db1_mc_ports.ruser;
        end
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

    // Exercise the production hint format, generated 81x32 FIFO, delayed
    // translation fill, generated 512x16K cache RAM, and the complete fake
    // CXL/fake-MC data path.  The first reference intentionally misses and is
    // dropped; the second reference hits the newly inserted translation.
    task automatic run_atc_cold_then_hit();
        logic [63:0] base_pa;
        logic [63:0] base_va;
        logic [511:0] expected [4];
        logic [511:0] hint_line;

        if (!USE_ATC) begin
            record_error("ATC test requires wppp_atc_integration_tb");
            return;
        end

        base_pa = MEM_BASE + 64'h0000_d000;
        base_va = base_pa + ATC_OFFSET;
        for (int i = 0; i < 4; i++) begin
            expected[i] = line_pattern(base_pa + (i * 64), 16'ha000 + i);
            host_write(base_pa + (i * 64), expected[i], 12'h500 + i);
        end

        hint_line = '0;
        hint_line[0 +: 64] = packed_atc_hint(base_va, 4);
        host_write(HINT_PAGE + 64'h280, hint_line, 12'h520);

        wait_for_translation_stat(1, 1, 1000);
        if ((db_read_count_0 != 0) || (db_read_count_1 != 0)) begin
            record_error("cold ATC miss incorrectly emitted WPPP work");
        end

        wait_for_translation_stat(4, 1, 1000);
        repeat (4) @(posedge clk);
        if ((translation_stats[0] != 0) ||
            (translation_stats[1] != 1) ||
            (translation_stats[3] != 1) ||
            (translation_stats[4] != 1)) begin
            record_error($sformatf(
                "unexpected cold-fill stats hit=%0d miss=%0d unique=%0d insert=%0d",
                translation_stats[0], translation_stats[1],
                translation_stats[3], translation_stats[4]));
        end

        host_write(HINT_PAGE + 64'h2c0, hint_line, 12'h521);
        wait_for_cpu_writes(4, 10000);
        for (int i = 0; i < 4; i++) begin
            // The eight physical slots in the cold line preserve selector
            // continuity, so slot zero of the repeated line selects engine 1.
            check_cpu_line(1, base_pa + (i * 64), expected[i]);
        end
        if ((translation_stats[0] != 1) ||
            (translation_stats[1] != 1) ||
            (translation_stats[7] != 0)) begin
            record_error($sformatf(
                "unexpected ATC hit/drop stats hit=%0d miss=%0d fifo_drop=%0d",
                translation_stats[0], translation_stats[1],
                translation_stats[7]));
        end
        check_global_contract(0, 4, 0, 4);
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
            // Keep two cachelines per packed entry so this batch covers
            // multi-line expansion; one-line/final-AR behavior has dedicated
            // expected-pass backpressure regressions.
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

    task automatic run_db_backpressure();
        logic [63:0] base_addr;
        logic [511:0] expected [4];
        logic [511:0] hint_line;
        logic [11:0] held_id;
        logic [63:0] held_addr;
        int cycles;
        bit final_ar_dropped;

        base_addr = MEM_BASE + 64'h0008_0000;
        for (int i = 0; i < 4; i++) begin
            expected[i] = line_pattern(base_addr + (i * 64), 16'h5000 + i);
            host_write(base_addr + (i * 64), expected[i], 12'h300 + i);
        end

        // Stall the first AR to prove that a non-final request is retained.
        force db0_mc_ports.arready = 1'b0;
        hint_line = '0;
        hint_line[0 +: 64] = packed_hint(base_addr, 4);
        host_write(HINT_PAGE + 64'h100, hint_line, 12'h340);

        cycles = 0;
        while (db0_mc_ports.arvalid !== 1'b1) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= 1000) begin
                record_error("DB0 ARVALID timeout before initial backpressure check");
                release db0_mc_ports.arready;
                return;
            end
        end
        held_id = db0_mc_ports.arid;
        held_addr = db0_mc_ports.araddr;
        repeat (4) begin
            @(posedge clk);
            #1;
            if ((db0_mc_ports.arvalid !== 1'b1) ||
                (db0_mc_ports.arid !== held_id) ||
                (db0_mc_ports.araddr !== held_addr)) begin
                record_error("non-final DB0 AR changed while ARREADY was low");
            end
        end

        @(negedge clk);
        release db0_mc_ports.arready;
        wait_for_db_reads(3, 0, 1000);

        // Stall the fourth/final AR. AXI requires the request to remain valid
        // and stable until a handshake, regardless of its position in a hint.
        @(negedge clk);
        force db0_mc_ports.arready = 1'b0;
        #1;
        if (db0_mc_ports.arvalid !== 1'b1) begin
            record_error("final DB0 AR was not presented before directed stall");
            release db0_mc_ports.arready;
            return;
        end
        held_id = db0_mc_ports.arid;
        held_addr = db0_mc_ports.araddr;

        @(posedge clk);
        #1;
        final_ar_dropped = db0_mc_ports.arvalid !== 1'b1;
        if (final_ar_dropped) begin
            record_error($sformatf(
                "final DB0 AR dropped without handshake id=%0d addr=%h",
                held_id, held_addr));
            $display("WPPP_REPRODUCED: integration final-cacheline hint dequeued without AR handshake");
        end else if ((db0_mc_ports.arid !== held_id) ||
                     (db0_mc_ports.araddr !== held_addr)) begin
            record_error("final DB0 AR payload changed while ARREADY was low");
        end

        if (!final_ar_dropped) begin
            // Once VALID has been sampled under backpressure, disabling new
            // prefetch work must not withdraw the in-flight AXI transaction.
            @(negedge clk);
            enable_wppp = 1'b0;
            repeat (3) begin
                @(posedge clk);
                #1;
                if ((db0_mc_ports.arvalid !== 1'b1) ||
                    (db0_mc_ports.arid !== held_id) ||
                    (db0_mc_ports.araddr !== held_addr)) begin
                    record_error("final DB0 AR was not stable throughout backpressure");
                end
            end
        end

        @(negedge clk);
        release db0_mc_ports.arready;
        if (final_ar_dropped) begin
            repeat (64) @(posedge clk);
            if (db_read_count_0 != 3) begin
                record_error($sformatf(
                    "unexpected DB0 count after dropped final AR: %0d",
                    db_read_count_0));
            end
            return;
        end

        wait_for_cpu_writes(4, 10000);
        @(negedge clk);
        enable_wppp = 1'b1;
        for (int i = 0; i < 4; i++) begin
            check_cpu_line(0, base_addr + (i * 64), expected[i]);
        end
        check_global_contract(4, 0, 4, 0);
    endtask

    task automatic run_ncp_backpressure();
        logic [63:0] base_addr;
        logic [511:0] expected [4];
        logic [511:0] hint_line;
        logic [11:0] held_awid;
        logic [63:0] held_awaddr;
        logic [511:0] held_wdata;
        int cycles;

        base_addr = MEM_BASE + 64'h0009_0000;
        for (int i = 0; i < 4; i++) begin
            expected[i] = line_pattern(base_addr + (i * 64), 16'h6000 + i);
            host_write(base_addr + (i * 64), expected[i], 12'h380 + i);
        end

        // Independently block AW and W. Suppressing BVALID during the transfer
        // models an arbitrarily delayed write response; production WPPP keeps
        // BREADY asserted and does not use B to retire its internal entry.
        force wppp0_cxl_ports.awready = 1'b0;
        force wppp0_cxl_ports.wready = 1'b0;
        force wppp0_cxl_ports.bvalid = 1'b0;
        hint_line = '0;
        hint_line[0 +: 64] = packed_hint(base_addr, 4);
        host_write(HINT_PAGE + 64'h140, hint_line, 12'h3c0);

        cycles = 0;
        while (wppp0_cxl_ports.awvalid !== 1'b1) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= 2000) begin
                record_error("NCP AWVALID timeout before backpressure check");
                release wppp0_cxl_ports.awready;
                release wppp0_cxl_ports.wready;
                release wppp0_cxl_ports.bvalid;
                return;
            end
        end
        held_awid = wppp0_cxl_ports.awid;
        held_awaddr = wppp0_cxl_ports.awaddr;
        repeat (4) begin
            @(posedge clk);
            #1;
            if ((wppp0_cxl_ports.awvalid !== 1'b1) ||
                (wppp0_cxl_ports.awid !== held_awid) ||
                (wppp0_cxl_ports.awaddr !== held_awaddr)) begin
                record_error("NCP AW changed while AWREADY was low");
            end
            if (wppp0_cxl_ports.bready !== 1'b1) begin
                record_error("NCP BREADY deasserted while B response was delayed");
            end
        end

        @(negedge clk);
        release wppp0_cxl_ports.awready;
        cycles = 0;
        while (wppp0_cxl_ports.wvalid !== 1'b1) begin
            @(posedge clk);
            #1;
            cycles++;
            if (cycles >= 1000) begin
                record_error("NCP WVALID timeout after AW handshake");
                release wppp0_cxl_ports.wready;
                release wppp0_cxl_ports.bvalid;
                return;
            end
        end
        held_wdata = wppp0_cxl_ports.wdata;
        repeat (4) begin
            @(posedge clk);
            #1;
            if ((wppp0_cxl_ports.wvalid !== 1'b1) ||
                (wppp0_cxl_ports.wdata !== held_wdata) ||
                (wppp0_cxl_ports.wstrb !== 64'hffff_ffff_ffff_ffff) ||
                (wppp0_cxl_ports.wlast !== 1'b1)) begin
                record_error("NCP W changed while WREADY was low");
            end
        end

        @(negedge clk);
        release wppp0_cxl_ports.wready;
        wait_for_cpu_writes(4, 10000);
        repeat (4) begin
            @(posedge clk);
            #1;
            if (wppp0_cxl_ports.bready !== 1'b1) begin
                record_error("NCP BREADY did not remain asserted");
            end
        end
        release wppp0_cxl_ports.bvalid;

        for (int i = 0; i < 4; i++) begin
            check_cpu_line(0, base_addr + (i * 64), expected[i]);
        end
        check_global_contract(4, 0, 4, 0);
    endtask

    task automatic run_out_of_order();
        logic [63:0] base_addr [2];
        logic [511:0] expected [2][4];
        logic [511:0] hint_line;

        base_addr[0] = MEM_BASE + 64'h000a_0000;
        base_addr[1] = MEM_BASE + 64'h000b_0000;
        for (int channel = 0; channel < 2; channel++) begin
            for (int i = 0; i < 4; i++) begin
                expected[channel][i] = line_pattern(
                    base_addr[channel] + (i * 64),
                    16'h7000 + (channel * 16) + i);
                host_write(base_addr[channel] + (i * 64),
                           expected[channel][i],
                           12'h400 + (channel * 16) + i);
            end
        end

        // Hide the fake MC's normal ordered responses. Requests are still
        // accepted and logged, then the testbench returns each channel in
        // reverse ID order using otherwise legal AXI R transactions.
        force db0_mc_ports.rvalid = 1'b0;
        force db1_mc_ports.rvalid = 1'b0;
        hint_line = '0;
        hint_line[0 +: 64] = packed_hint(base_addr[0], 4);
        hint_line[64 +: 64] = packed_hint(base_addr[1], 4);
        host_write(HINT_PAGE + 64'h180, hint_line, 12'h440);
        wait_for_db_reads(4, 4, 5000);

        for (int i = 0; i < 4; i++) begin
            if (db0_req_addr_log[i] !== base_addr[0] + (i * 64)) begin
                record_error($sformatf(
                    "unexpected DB0 request order index=%0d addr=%h", i,
                    db0_req_addr_log[i]));
            end
            if (db1_req_addr_log[i] !== base_addr[1] + (i * 64)) begin
                record_error($sformatf(
                    "unexpected DB1 request order index=%0d addr=%h", i,
                    db1_req_addr_log[i]));
            end
        end

        for (int i = 3; i >= 0; i--) begin
            inject_db_response(0, db0_req_id_log[i], expected[0][i]);
            inject_db_response(1, db1_req_id_log[i], expected[1][i]);
        end

        wait_for_cpu_writes(8, 10000);
        for (int channel = 0; channel < 2; channel++) begin
            for (int i = 0; i < 4; i++) begin
                check_cpu_line(channel, base_addr[channel] + (i * 64),
                               expected[channel][i]);
            end
        end
        check_global_contract(4, 4, 4, 4);
    endtask

    task automatic run_hint_sequence();
        logic [63:0] addr [6];
        logic [511:0] expected [6][2];
        logic [511:0] wrong_page_data;
        logic [511:0] first_hint_line;
        logic [511:0] second_hint_line;

        for (int i = 0; i < 6; i++) begin
            addr[i] = MEM_BASE + 64'h000c_0000 + (i * 64'h0000_0400);
            for (int line = 0; line < 2; line++) begin
                expected[i][line] = line_pattern(
                    addr[i] + (line * 64), 16'h8000 + (i * 2) + line);
                host_write(addr[i] + (line * 64), expected[i][line],
                           12'h480 + (i * 2) + line);
            end
        end

        // A hint-shaped write outside the configured 4 KiB page must remain
        // ordinary host traffic and generate no WPPP request.
        wrong_page_data = '0;
        wrong_page_data[0 +: 64] = packed_hint(addr[0], 2);
        host_write(HINT_PAGE + 64'h1000, wrong_page_data, 12'h4c0);
        repeat (12) @(posedge clk);
        if ((db_read_count_0 != 0) || (db_read_count_1 != 0)) begin
            record_error("off-page hint-shaped write generated WPPP traffic");
        end

        // Sparse slots still advance the engine selector. The first line uses
        // slots 0/2 on engine 0 and slots 5/7 on engine 1.
        first_hint_line = '0;
        first_hint_line[(0 * 64) +: 64] = packed_hint(addr[0], 2);
        first_hint_line[(2 * 64) +: 64] = packed_hint(addr[1], 2);
        first_hint_line[(5 * 64) +: 64] = packed_hint(addr[2], 2);
        first_hint_line[(7 * 64) +: 64] = packed_hint(addr[3], 2);
        host_write(HINT_PAGE + 64'h1c0, first_hint_line, 12'h4c1);

        // Wait until the eight-slot serializer is idle before presenting the
        // next line; overlapping captures are intentionally not assumed safe.
        repeat (12) @(posedge clk);
        if (dut.hint_snoop.hint_mech_valid !== 1'b0) begin
            record_error("hint serializer did not return idle after eight slots");
        end

        // The capture toggle preserves selector continuity across lines: on
        // this second line slot 1 selects engine 0 and slot 4 selects engine 1.
        second_hint_line = '0;
        second_hint_line[(1 * 64) +: 64] = packed_hint(addr[4], 2);
        second_hint_line[(4 * 64) +: 64] = packed_hint(addr[5], 2);
        host_write(HINT_PAGE + 64'h200, second_hint_line, 12'h4c2);

        wait_for_cpu_writes(12, 15000);
        for (int i = 0; i < 2; i++) begin
            check_cpu_line(0, addr[0] + (i * 64), expected[0][i]);
            check_cpu_line(0, addr[1] + (i * 64), expected[1][i]);
            check_cpu_line(1, addr[2] + (i * 64), expected[2][i]);
            check_cpu_line(1, addr[3] + (i * 64), expected[3][i]);
            check_cpu_line(0, addr[4] + (i * 64), expected[4][i]);
            check_cpu_line(1, addr[5] + (i * 64), expected[5][i]);
        end
        check_global_contract(6, 6, 6, 6);
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
        flush_translation = 1'b0;
        check_errors = 0;
        active_test = "";
        initialize_host_agent();

        repeat (8) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        enable_wppp = 1'b1;
        if (USE_ATC) begin
            atc_init_cycles = 0;
            while ((translation_flush_busy !== 1'b0) &&
                   (atc_init_cycles < 20000)) begin
                @(posedge clk);
                #1;
                atc_init_cycles++;
            end
            if (translation_flush_busy !== 1'b0) begin
                record_error("ATC power-on cache sweep did not complete");
            end
            repeat (4) @(posedge clk);
        end else begin
            repeat (8) @(posedge clk);
        end

        if ($test$plusargs("RUN_INT_ATC_COLD_HIT")) begin
            active_test = "RUN_INT_ATC_COLD_HIT";
            run_atc_cold_then_hit();
        end else if ($test$plusargs("RUN_INT_HOST_RW")) begin
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
        end else if ($test$plusargs("RUN_INT_DB_BACKPRESSURE")) begin
            active_test = "RUN_INT_DB_BACKPRESSURE";
            run_db_backpressure();
        end else if ($test$plusargs("RUN_INT_NCP_BACKPRESSURE")) begin
            active_test = "RUN_INT_NCP_BACKPRESSURE";
            run_ncp_backpressure();
        end else if ($test$plusargs("RUN_INT_OUT_OF_ORDER")) begin
            active_test = "RUN_INT_OUT_OF_ORDER";
            run_out_of_order();
        end else if ($test$plusargs("RUN_INT_HINT_SEQUENCE")) begin
            active_test = "RUN_INT_HINT_SEQUENCE";
            run_hint_sequence();
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

module wppp_atc_integration_tb;
    wppp_integration_tb #(
        .USE_ATC(1'b1)
    ) tb ();
endmodule
