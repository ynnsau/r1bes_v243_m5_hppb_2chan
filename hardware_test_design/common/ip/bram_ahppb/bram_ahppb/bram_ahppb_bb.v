module bram_ahppb (
		input  wire [511:0] data,      //      data.datain,    Data input of the memory.The data port is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		output wire [511:0] q,         //         q.dataout,   Data output from the memory
		input  wire [5:0]   wraddress, // wraddress.wraddress, Write address input to the memory.
		input  wire [5:0]   rdaddress, // rdaddress.rdaddress, Read address input to the memory.
		input  wire         wren,      //      wren.wren,      Write enable input for address port.The wren signal is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		input  wire         clock      //     clock.clk,       Memory clock, refer to user guide for specific details
	);
endmodule

