`timescale 1ns/1ps

module fake_cpu_sink (
    input logic clk,
    input logic rst_n,
    axi_ports.aw_resp cpu_w_ch,
    output logic [63:0] write_count,
    output logic [31:0] protocol_error_count
);
    typedef logic [511:0] line_t;
    typedef logic [57:0] line_key_t;

    line_t cpu_mem [line_key_t];
    logic aw_pending;
    logic [11:0] awid_reg;
    logic [63:0] awaddr_reg;
    logic bvalid_reg;
    logic [11:0] bid_reg;

    wire aw_fire = cpu_w_ch.awvalid && cpu_w_ch.awready;
    wire w_fire = cpu_w_ch.wvalid && cpu_w_ch.wready;
    wire aw_error = aw_fire &&
        ((cpu_w_ch.awlen != '0) ||
         (cpu_w_ch.awsize != 3'b110) ||
         (cpu_w_ch.awuser != 6'b100010));
    wire w_error = w_fire &&
        (!cpu_w_ch.wlast || (cpu_w_ch.wstrb != 64'hffff_ffff_ffff_ffff));

    function automatic line_key_t line_key(input logic [63:0] addr);
        return addr[63:6];
    endfunction

    assign cpu_w_ch.awready = rst_n && !aw_pending;
    assign cpu_w_ch.wready = rst_n && aw_pending;
    assign cpu_w_ch.bid = bid_reg;
    assign cpu_w_ch.bresp = 2'b00;
    assign cpu_w_ch.buser = '0;
    assign cpu_w_ch.bvalid = bvalid_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cpu_mem.delete();
            aw_pending <= 1'b0;
            awid_reg <= '0;
            awaddr_reg <= '0;
            bvalid_reg <= 1'b0;
            bid_reg <= '0;
            write_count <= '0;
            protocol_error_count <= '0;
        end else begin
            if (bvalid_reg && cpu_w_ch.bready) begin
                bvalid_reg <= 1'b0;
            end

            if (aw_fire) begin
                aw_pending <= 1'b1;
                awid_reg <= cpu_w_ch.awid;
                awaddr_reg <= cpu_w_ch.awaddr;
                if (aw_error) begin
                    $error("WPPP_INT_CHECK_ERROR: invalid NCP AW addr=%h len=%0d size=%0d user=%b",
                           cpu_w_ch.awaddr, cpu_w_ch.awlen,
                           cpu_w_ch.awsize, cpu_w_ch.awuser);
                end
            end

            if (w_fire) begin
                cpu_mem[line_key(awaddr_reg)] = cpu_w_ch.wdata;
                aw_pending <= 1'b0;
                bid_reg <= awid_reg;
                bvalid_reg <= 1'b1;
                write_count <= write_count + 1'b1;
                if (w_error) begin
                    $error("WPPP_INT_CHECK_ERROR: invalid NCP W addr=%h last=%b strb=%h",
                           awaddr_reg, cpu_w_ch.wlast, cpu_w_ch.wstrb);
                end
            end

            protocol_error_count <= protocol_error_count + aw_error + w_error;
        end
    end

    task automatic backdoor_read(
        input  logic [63:0] addr,
        output logic [511:0] data,
        output logic present
    );
        present = cpu_mem.exists(line_key(addr));
        if (present) begin
            data = cpu_mem[line_key(addr)];
        end else begin
            data = '0;
        end
    endtask
endmodule

module fake_cxlip (
    input logic clk,
    input logic rst_n,

    // Host test-agent side and CXL.mem request side toward the DUT.
    axi_ports.ar_resp host_agent_r_ch,
    axi_ports.aw_resp host_agent_w_ch,
    axi_ports.ar_req  host_dut_r_ch,
    axi_ports.aw_req  host_dut_w_ch,

    // WPPP output channels from the DUT.
    axi_ports.ar_resp wppp0_r_ch,
    axi_ports.aw_resp wppp0_w_ch,
    axi_ports.ar_resp wppp1_r_ch,
    axi_ports.aw_resp wppp1_w_ch,

    // Device-biased read paths to the device-side fake MC.
    axi_ports.ar_req db0_mc_r_ch,
    axi_ports.ar_req db1_mc_r_ch,

    output logic [63:0] cpu_write_count_0,
    output logic [63:0] cpu_write_count_1,
    output logic [31:0] protocol_error_count
);
    logic [31:0] cpu_error_count_0;
    logic [31:0] cpu_error_count_1;

    axi_passthrough host_ingress (
        .upstream_r(host_agent_r_ch),
        .upstream_w(host_agent_w_ch),
        .downstream_r(host_dut_r_ch),
        .downstream_w(host_dut_w_ch)
    );

    // WPPP AR traffic is a device-biased read and reaches the device MC.
    axi_read_passthrough db_read_path_0 (
        .upstream_r(wppp0_r_ch),
        .downstream_r(db0_mc_r_ch)
    );

    axi_read_passthrough db_read_path_1 (
        .upstream_r(wppp1_r_ch),
        .downstream_r(db1_mc_r_ch)
    );

    // WPPP writes are NCP pushes to CPU memory. They terminate here instead
    // of modifying the device-side fake-MC backing store.
    fake_cpu_sink cpu_sink_0 (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_w_ch(wppp0_w_ch),
        .write_count(cpu_write_count_0),
        .protocol_error_count(cpu_error_count_0)
    );

    fake_cpu_sink cpu_sink_1 (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_w_ch(wppp1_w_ch),
        .write_count(cpu_write_count_1),
        .protocol_error_count(cpu_error_count_1)
    );

    assign protocol_error_count = cpu_error_count_0 + cpu_error_count_1;

    task automatic cpu_backdoor_read(
        input  int channel,
        input  logic [63:0] addr,
        output logic [511:0] data,
        output logic present
    );
        if (channel == 0) begin
            cpu_sink_0.backdoor_read(addr, data, present);
        end else if (channel == 1) begin
            cpu_sink_1.backdoor_read(addr, data, present);
        end else begin
            data = 'x;
            present = 1'b0;
            $error("WPPP_INT_CHECK_ERROR: invalid CPU sink channel %0d", channel);
        end
    endtask
endmodule
