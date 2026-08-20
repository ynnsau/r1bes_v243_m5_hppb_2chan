module bram_b512_d16384 (
		input  wire [511:0] data,      //      data.datain,        Data input of the memory.The data port is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		output wire [511:0] q,         //         q.dataout,       Data output from the memory
		input  wire [13:0]  wraddress, // wraddress.wraddress,     Write address input to the memory.
		input  wire [13:0]  rdaddress, // rdaddress.rdaddress,     Read address input to the memory.
		input  wire         wren,      //      wren.wren,          Write enable input for address port.The wren signal is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		input  wire         clock,     //     clock.clk,           Memory clock, refer to user guide for specific details
		input  wire [63:0]  byteena_a  // byteena_a.byte_enable_a, Byte enable input to mask the data_a port so that only specific bytes, nibbles, or bits of the data are written. The byteena_a port is not supported in the following conditions:If implement_in_les parameter is set to ON and If operation_mode parameter is set to ROM
	);
endmodule

