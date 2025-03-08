// (C) 2001-2024 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module  w32_d1024_ram_2port_2050_e2optgi  (
    clock,
    data,
    rdaddress,
    sclr,
    wraddress,
    wren,
    q);

    input    clock;
    input  [31:0]  data;
    input  [9:0]  rdaddress;
    input    sclr;
    input  [9:0]  wraddress;
    input    wren;
    output [31:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
    tri0     sclr;
    tri1     clock;
    tri0     wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

    wire [31:0] sub_wire0;
    wire [31:0] q = sub_wire0[31:0];

    altera_syncram  altera_syncram_component (
                .address_a (wraddress),
                .address_b (rdaddress),
                .clock0 (clock),
                .data_a (data),
                .sclr (sclr),
                .wren_a (wren),
                .q_b (sub_wire0),
                .aclr0 (1'b0),
                .aclr1 (1'b0),
                .address2_a (1'b1),
                .address2_b (1'b1),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_a (1'b1),
                .byteena_b (1'b1),
                .clock1 (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .data_b ({32{1'b1}}),
                .eccencbypass (1'b0),
                .eccencparity (8'b0),
                .eccstatus (),
                .q_a (),
                .rden_a (1'b1),
                .rden_b (1'b1),
                .wren_b (1'b0));
    defparam
        altera_syncram_component.address_aclr_b  = "NONE",
        altera_syncram_component.address_reg_b  = "CLOCK0",
        altera_syncram_component.clock_enable_input_a  = "BYPASS",
        altera_syncram_component.clock_enable_input_b  = "BYPASS",
        altera_syncram_component.clock_enable_output_b  = "BYPASS",
        altera_syncram_component.enable_force_to_zero  = "FALSE",
        altera_syncram_component.intended_device_family  = "Agilex 7",
        altera_syncram_component.lpm_type  = "altera_syncram",
        altera_syncram_component.numwords_a  = 1024,
        altera_syncram_component.numwords_b  = 1024,
        altera_syncram_component.operation_mode  = "DUAL_PORT",
        altera_syncram_component.outdata_aclr_b  = "NONE",
        altera_syncram_component.outdata_sclr_b  = "SCLEAR",
        altera_syncram_component.outdata_reg_b  = "CLOCK0",
        altera_syncram_component.power_up_uninitialized  = "FALSE",
        altera_syncram_component.read_during_write_mode_mixed_ports  = "OLD_DATA",
        altera_syncram_component.widthad_a  = 10,
        altera_syncram_component.widthad_b  = 10,
        altera_syncram_component.width_a  = 32,
        altera_syncram_component.width_b  = 32,
        altera_syncram_component.width_byteena_a  = 1;








endmodule


