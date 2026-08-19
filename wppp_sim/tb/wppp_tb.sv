`timescale 1ns/1ps

module wppp_tb;
    import wppprefetch_pkg::*;

    localparam logic [63:0] CXL_BASE = 64'h0000_0001_0000_0000;
    localparam logic [33:0] CXL_SIZE = 34'h0001_00000;
    localparam int DEFAULT_TIMEOUT = 4000;

    logic clk = 1'b0;
    logic reset_n;
    always #5 clk = ~clk;

    axi_ports read_channel();
    axi_ports write_channel();

    logic [5:0] csr_aruser;
    logic [6:0] csr_awuser;
    logic [63:0] start_address;
    logic enable_prefetch;
    logic [33:0] address_lower;
    logic [33:0] address_upper;
    logic enqueue_valid;
    logic [63:0] enqueue_address;
    logic [15:0] enqueue_num_of_cl;
    logic csr_flush_lut;
    logic [63:0] prefetch_abt_cnt;
    logic [63:0] prefetch_ok_cnt;
    logic [63:0] faraddr;
    logic farvalid;

    wppprefetch_rw_state_t prefetch_state;
    logic [63:0] current_address;
    logic addr_issued;
    logic get_next_addr;

    wppprefetch_rw_pipeline_v2 dut (
        .axi4_mm_clk(clk),
        .axi4_mm_rst_n(reset_n),
        .wppp_axi_r_ch(read_channel.ar_req),
        .wppp_axi_w_ch(write_channel.aw_req),
        .csr_aruser(csr_aruser),
        .csr_awuser(csr_awuser),
        .start_address_i(start_address),
        .enable_prefetch_i(enable_prefetch),
        .address_lower_i(address_lower),
        .address_upper_i(address_upper),
        .enqueue_valid_i(enqueue_valid),
        .enqueue_address_i(enqueue_address),
        .enqueue_num_of_cl_i(enqueue_num_of_cl),
        .clst_d1_tvalid(1'b0),
        .clst_d1_tdata('0),
        .csr_flush_lut(csr_flush_lut),
        .prefetch_rw_curr_state(prefetch_state),
        .curr_working_address(current_address),
        .addr_seen(1'b0),
        .abort_op(1'b0),
        .prefetch_abt_cnt(prefetch_abt_cnt),
        .prefetch_ok_cnt(prefetch_ok_cnt),
        .addr_issued(addr_issued),
        .get_next_addr(get_next_addr),
        .faraddr(faraddr),
        .farvalid(farvalid),
        .frvalid(1'b1),
        .frdata(1'b1)
    );

    typedef struct packed {
        logic [11:0] id;
        logic [63:0] address;
    } read_request_t;

    read_request_t request_queue[$];
    logic [63:0] expected_address [0:1023];
    logic [511:0] expected_data [0:1023];
    bit expected_valid [0:1023];

    int accepted_read_count;
    int completed_write_count;
    int check_error_count;
    bit write_address_pending;
    logic [11:0] pending_write_id;
    logic [63:0] pending_write_address;

    task automatic record_error(input string message);
        check_error_count++;
        $display("WPPP_CHECK_ERROR: %s", message);
    endtask

    function automatic logic [511:0] response_pattern(input read_request_t request);
        logic [511:0] value;
        for (int word = 0; word < 8; word++) begin
            value[(word * 64) +: 64] = request.address
                ^ {52'b0, request.id}
                ^ 64'(word);
        end
        return value;
    endfunction

    always @(posedge clk) begin
        if (!reset_n) begin
            accepted_read_count <= 0;
            completed_write_count <= 0;
            check_error_count <= 0;
            write_address_pending <= 1'b0;
            pending_write_id <= '0;
            pending_write_address <= '0;
            for (int id = 0; id < 1024; id++)
                expected_valid[id] <= 1'b0;
        end else begin
            if (read_channel.arvalid && read_channel.arready) begin
                read_request_t request;
                request.id = read_channel.arid;
                request.address = read_channel.araddr;
                request_queue.push_back(request);
                if (read_channel.arid[9:0] != (accepted_read_count % 1024))
                    record_error($sformatf(
                        "ARID sequence mismatch: got %0d expected %0d",
                        read_channel.arid[9:0], accepted_read_count % 1024));
                if (read_channel.arlen != 0 || read_channel.arsize != 3'b110
                    || read_channel.arburst != 0 || read_channel.aruser != 6'b110000)
                    record_error("read request attributes do not match the WPPP contract");
                accepted_read_count <= accepted_read_count + 1;
            end

            if (write_channel.awvalid && write_channel.awready) begin
                if (write_address_pending)
                    record_error("accepted a second AW before completing the prior W beat");
                write_address_pending <= 1'b1;
                pending_write_id <= write_channel.awid;
                pending_write_address <= write_channel.awaddr;
                if (write_channel.awuser != 7'b0100010 || write_channel.awlen != 0
                    || write_channel.awsize != 3'b110 || write_channel.awburst != 0)
                    record_error("NCP write-address attributes do not match the WPPP contract");
            end

            if (write_channel.wvalid && write_channel.wready) begin
                int id_index;
                id_index = pending_write_id[9:0];
                if (!write_address_pending) begin
                    record_error("accepted W without a preceding AW");
                end else begin
                    if (!expected_valid[id_index])
                        record_error($sformatf("write ID %0d has no expected response", id_index));
                    if (pending_write_address !== expected_address[id_index])
                        record_error($sformatf(
                            "write address mismatch for ID %0d: got %h expected %h",
                            id_index, pending_write_address, expected_address[id_index]));
                    if (write_channel.wdata !== expected_data[id_index])
                        record_error($sformatf("write data mismatch for ID %0d", id_index));
                    if (write_channel.wstrb !== 64'hffff_ffff_ffff_ffff
                        || !write_channel.wlast)
                        record_error("NCP write-data attributes do not match the WPPP contract");
                    expected_valid[id_index] <= 1'b0;
                end
                write_address_pending <= 1'b0;
                completed_write_count <= completed_write_count + 1;
            end
        end
    end

    task automatic initialize_inputs;
        reset_n = 1'b0;
        csr_aruser = '0;
        csr_awuser = '0;
        start_address = CXL_BASE;
        enable_prefetch = 1'b1;
        address_lower = '0;
        address_upper = CXL_SIZE;
        enqueue_valid = 1'b0;
        enqueue_address = '0;
        enqueue_num_of_cl = '0;
        csr_flush_lut = 1'b0;

        read_channel.arready = 1'b1;
        read_channel.rid = '0;
        read_channel.rdata = '0;
        read_channel.rresp = '0;
        read_channel.rlast = 1'b1;
        read_channel.ruser = 1'b0;
        read_channel.rvalid = 1'b0;

        write_channel.awready = 1'b1;
        write_channel.wready = 1'b1;
        write_channel.bid = '0;
        write_channel.bresp = '0;
        write_channel.buser = '0;
        write_channel.bvalid = 1'b0;
    endtask

    task automatic apply_reset;
        repeat (5) @(posedge clk);
        @(negedge clk);
        reset_n = 1'b1;
        repeat (3) @(posedge clk);
    endtask

    task automatic enqueue_hint(
        input logic [63:0] address,
        input int unsigned cachelines
    );
        @(negedge clk);
        enqueue_address = address;
        enqueue_num_of_cl = cachelines[15:0];
        enqueue_valid = 1'b1;
        @(negedge clk);
        enqueue_valid = 1'b0;
        enqueue_address = '0;
        enqueue_num_of_cl = '0;
    endtask

    task automatic wait_for_reads(input int expected, input int timeout_cycles);
        int cycles = 0;
        while (accepted_read_count < expected && cycles < timeout_cycles) begin
            @(posedge clk);
            cycles++;
        end
        if (accepted_read_count != expected)
            record_error($sformatf(
                "read timeout: got %0d expected %0d", accepted_read_count, expected));
    endtask

    task automatic wait_for_writes(input int expected, input int timeout_cycles);
        int cycles = 0;
        while (completed_write_count < expected && cycles < timeout_cycles) begin
            @(posedge clk);
            cycles++;
        end
        if (completed_write_count != expected)
            record_error($sformatf(
                "write timeout: got %0d expected %0d", completed_write_count, expected));
    endtask

    task automatic check_queued_addresses(
        input logic [63:0] first_address,
        input int count
    );
        if (request_queue.size() < count) begin
            record_error("request queue is shorter than the requested address check");
            return;
        end
        for (int index = 0; index < count; index++) begin
            if (request_queue[index].address !== first_address + (index * 64))
                record_error($sformatf(
                    "read address %0d mismatch: got %h expected %h",
                    index, request_queue[index].address,
                    first_address + (index * 64)));
        end
    endtask

    task automatic drive_one_response(input read_request_t request);
        logic [511:0] data;
        int id_index;
        data = response_pattern(request);
        id_index = request.id[9:0];
        expected_address[id_index] = request.address;
        expected_data[id_index] = data;
        expected_valid[id_index] = 1'b1;

        @(negedge clk);
        read_channel.rid = request.id;
        read_channel.rdata = data;
        read_channel.rvalid = 1'b1;
        do @(posedge clk); while (!read_channel.rready);
    endtask

    task automatic end_response_stream;
        @(negedge clk);
        read_channel.rvalid = 1'b0;
        read_channel.rid = '0;
        read_channel.rdata = '0;
    endtask

    task automatic drive_collected_responses(
        input int count,
        input bit reverse_order,
        input int idle_cycles
    );
        read_request_t request;
        while (request_queue.size() < count)
            @(posedge clk);
        for (int index = 0; index < count; index++) begin
            if (reverse_order)
                request = request_queue.pop_back();
            else
                request = request_queue.pop_front();
            drive_one_response(request);
            if (idle_cycles > 0) begin
                end_response_stream();
                repeat (idle_cycles) @(posedge clk);
            end
        end
        end_response_stream();
    endtask

    task automatic drive_streaming_responses(input int count, input int idle_cycles);
        read_request_t request;
        for (int index = 0; index < count; index++) begin
            while (request_queue.size() == 0)
                @(posedge clk);
            request = request_queue.pop_front();
            drive_one_response(request);
            if (idle_cycles > 0) begin
                end_response_stream();
                repeat (idle_cycles) @(posedge clk);
            end
        end
        end_response_stream();
    endtask

    task automatic pulse_lut_flush;
        @(negedge clk);
        csr_flush_lut = 1'b1;
        @(negedge clk);
        csr_flush_lut = 1'b0;
    endtask

    task automatic finish_test(input string name);
        repeat (5) @(posedge clk);
        if (check_error_count != 0) begin
            $display("WPPP_TEST_FAIL: %s errors=%0d", name, check_error_count);
            $fatal(1, "WPPP test failed");
        end
        $display("WPPP_TEST_PASS: %s reads=%0d writes=%0d", name,
            accepted_read_count, completed_write_count);
        $finish;
    endtask

    task automatic run_single_hint;
        logic [63:0] base = CXL_BASE + 64'h1000;
        enqueue_hint(base, 4);
        wait_for_reads(4, DEFAULT_TIMEOUT);
        check_queued_addresses(base, 4);
        drive_collected_responses(4, 1'b0, 1);
        wait_for_writes(4, DEFAULT_TIMEOUT);
        finish_test("RUN_SINGLE_HINT");
    endtask

    task automatic run_out_of_order;
        logic [63:0] base = CXL_BASE + 64'h4000;
        enqueue_hint(base, 8);
        wait_for_reads(8, DEFAULT_TIMEOUT);
        check_queued_addresses(base, 8);
        drive_collected_responses(8, 1'b1, 0);
        wait_for_writes(8, DEFAULT_TIMEOUT);
        finish_test("RUN_OUT_OF_ORDER");
    endtask

    task automatic run_backpressure;
        logic [63:0] base = CXL_BASE + 64'h8000;
        logic [63:0] held_araddr;
        logic [11:0] held_arid;
        logic [63:0] held_awaddr;
        logic [11:0] held_awid;
        logic [511:0] held_wdata;

        read_channel.arready = 1'b0;
        enqueue_hint(base, 3);
        wait (read_channel.arvalid);
        held_araddr = read_channel.araddr;
        held_arid = read_channel.arid;
        repeat (4) begin
            @(posedge clk);
            if (!read_channel.arvalid || read_channel.araddr !== held_araddr
                || read_channel.arid !== held_arid)
                record_error("AR payload changed while arready was low");
        end
        @(negedge clk);
        read_channel.arready = 1'b1;
        wait_for_reads(3, DEFAULT_TIMEOUT);
        check_queued_addresses(base, 3);

        write_channel.awready = 1'b0;
        drive_collected_responses(3, 1'b0, 1);
        wait (write_channel.awvalid);
        held_awaddr = write_channel.awaddr;
        held_awid = write_channel.awid;
        repeat (4) begin
            @(posedge clk);
            if (!write_channel.awvalid || write_channel.awaddr !== held_awaddr
                || write_channel.awid !== held_awid)
                record_error("AW payload changed while awready was low");
        end
        @(negedge clk);
        write_channel.awready = 1'b1;

        write_channel.wready = 1'b0;
        wait (write_channel.wvalid);
        held_wdata = write_channel.wdata;
        repeat (4) begin
            @(posedge clk);
            if (!write_channel.wvalid || write_channel.wdata !== held_wdata)
                record_error("W payload changed while wready was low");
        end
        @(negedge clk);
        write_channel.wready = 1'b1;
        wait_for_writes(3, DEFAULT_TIMEOUT);
        finish_test("RUN_BACKPRESSURE");
    endtask

    task automatic run_hint_queue;
        logic [63:0] first = CXL_BASE + 64'hc000;
        logic [63:0] second = CXL_BASE + 64'h10000;
        enqueue_hint(first, 3);
        enqueue_hint(second, 2);
        wait_for_reads(5, DEFAULT_TIMEOUT);
        if (request_queue.size() >= 5) begin
            for (int index = 0; index < 3; index++) begin
                if (request_queue[index].address !== first + (index * 64))
                    record_error("first queued hint was not issued in order");
            end
            for (int index = 0; index < 2; index++) begin
                if (request_queue[index + 3].address !== second + (index * 64))
                    record_error("second queued hint was not issued in order");
            end
        end
        drive_collected_responses(5, 1'b0, 1);
        wait_for_writes(5, DEFAULT_TIMEOUT);
        finish_test("RUN_HINT_QUEUE");
    endtask

    task automatic run_lut_flush;
        logic [63:0] base = CXL_BASE + 64'h14000;
        enqueue_hint(base, 4);
        wait_for_reads(4, DEFAULT_TIMEOUT);
        pulse_lut_flush();
        drive_collected_responses(4, 1'b0, 0);
        repeat (30) @(posedge clk);
        if (completed_write_count != 0)
            record_error("a response accepted after LUT flush produced an NCP write");
        finish_test("RUN_LUT_FLUSH");
    endtask

    task automatic run_id_wrap;
        localparam int REQUESTS = 1030;
        logic [63:0] base = CXL_BASE + 64'h20000;
        fork
            drive_streaming_responses(REQUESTS, 1);
        join_none
        enqueue_hint(base, REQUESTS);
        wait_for_reads(REQUESTS, 20000);
        wait_for_writes(REQUESTS, 30000);
        if (prefetch_ok_cnt != REQUESTS)
            record_error($sformatf(
                "success counter mismatch: got %0d expected %0d",
                prefetch_ok_cnt, REQUESTS));
        finish_test("RUN_ID_WRAP");
    endtask

    // Regression for a one-cacheline hint held under AR backpressure. Disabling
    // new work after VALID is sampled must not withdraw the pending request.
    task automatic run_ar_last_stall;
        logic [63:0] base = CXL_BASE + 64'h30000;
        logic [63:0] held_araddr;
        logic [11:0] held_arid;
        int cycles = 0;

        read_channel.arready = 1'b0;
        enqueue_hint(base, 1);

        while (!read_channel.arvalid && cycles < DEFAULT_TIMEOUT) begin
            @(posedge clk);
            cycles++;
        end
        if (!read_channel.arvalid) begin
            record_error("one-line ARVALID was not presented under backpressure");
            finish_test("RUN_AR_LAST_STALL");
        end

        held_araddr = read_channel.araddr;
        held_arid = read_channel.arid;
        repeat (3) begin
            @(posedge clk);
            if (!read_channel.arvalid || read_channel.araddr !== held_araddr
                || read_channel.arid !== held_arid)
                record_error("one-line AR payload changed while ARREADY was low");
        end

        @(negedge clk);
        enable_prefetch = 1'b0;
        repeat (3) begin
            @(posedge clk);
            if (!read_channel.arvalid || read_channel.araddr !== held_araddr
                || read_channel.arid !== held_arid)
                record_error("pending AR was withdrawn when prefetch was disabled");
        end

        @(negedge clk);
        read_channel.arready = 1'b1;
        wait_for_reads(1, DEFAULT_TIMEOUT);
        check_queued_addresses(base, 1);
        enable_prefetch = 1'b1;
        finish_test("RUN_AR_LAST_STALL");
    endtask

    // Expected-fail reproducer for an invalid head hint permanently blocking
    // the valid hint behind it.
    task automatic run_range_head_block_repro;
        logic [63:0] invalid = CXL_BASE + {30'b0, CXL_SIZE} + 64'h1000;
        logic [63:0] valid = CXL_BASE + 64'h34000;
        // Use two cachelines so the invalid entry remains active while the
        // valid hint waits behind it.
        enqueue_hint(invalid, 2);
        enqueue_hint(valid, 1);
        repeat (50) @(posedge clk);
        if (accepted_read_count == 0) begin
            $display("WPPP_REPRODUCED: out-of-range head hint blocks following valid hint");
            $fatal(1, "known WPPP range-head blocking bug reproduced");
        end
        finish_test("RUN_RANGE_HEAD_BLOCK_REPRO");
    endtask

    task automatic list_tests;
        $display("RUN_SINGLE_HINT");
        $display("RUN_OUT_OF_ORDER");
        $display("RUN_BACKPRESSURE");
        $display("RUN_HINT_QUEUE");
        $display("RUN_LUT_FLUSH");
        $display("RUN_ID_WRAP");
        $display("RUN_AR_LAST_STALL");
        $display("RUN_RANGE_HEAD_BLOCK_REPRO (expected fail)");
        $display("WPPP_TEST_PASS: LIST_TESTS");
        $finish;
    endtask

    initial begin
        initialize_inputs();
        apply_reset();

        if ($test$plusargs("LIST_TESTS"))
            list_tests();
        else if ($test$plusargs("RUN_OUT_OF_ORDER"))
            run_out_of_order();
        else if ($test$plusargs("RUN_BACKPRESSURE"))
            run_backpressure();
        else if ($test$plusargs("RUN_HINT_QUEUE"))
            run_hint_queue();
        else if ($test$plusargs("RUN_LUT_FLUSH"))
            run_lut_flush();
        else if ($test$plusargs("RUN_ID_WRAP"))
            run_id_wrap();
        else if ($test$plusargs("RUN_AR_LAST_STALL"))
            run_ar_last_stall();
        else if ($test$plusargs("RUN_RANGE_HEAD_BLOCK_REPRO"))
            run_range_head_block_repro();
        else
            run_single_hint();
    end

    initial begin
        #1ms;
        $display("WPPP_TEST_FAIL: global watchdog expired");
        $fatal(1, "global testbench watchdog expired");
    end
endmodule
