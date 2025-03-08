module port_1_ram (
		input  wire [13:0] data,    //    data.datain,  Data input of the memory.The data port is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		output wire [13:0] q,       //       q.dataout, Data output from the memory
		input  wire [11:0] address, // address.address, Address input of the memory
		input  wire        wren,    //    wren.wren,    Write enable input for address port. The wren signal is required for all RAM operation modes:SINGLE_PORT,DUAL_PORT,BIDIR_DUAL_PORT,QUAD_PORT
		input  wire        clock    //   clock.clk,     Memory clock,refer to user guide for specific details
	);
endmodule

