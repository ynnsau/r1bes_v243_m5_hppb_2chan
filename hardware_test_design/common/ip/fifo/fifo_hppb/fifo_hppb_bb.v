module fifo_hppb (
		input  wire [522:0] data,  //  fifo_input.datain,  Data input of the memory.The data port is required for all FIFO operation.
		input  wire         wrreq, //            .wrreq,   wrreq input signal to request for write operation.The wrreq signal is required for all FIFO operation.
		input  wire         rdreq, //            .rdreq,   rdreq input signal to request for read operation.The rdreq signal is required for all FIFO operation.
		input  wire         clock, //            .clk,     Positive-edge-triggered clock.
		output wire [522:0] q,     // fifo_output.dataout, Data output of the memory. This port is required for all FIFO operation.
		output wire         full,  //            .full,    When full signal is asserted, the FIFO IP core is considered full. Do not perform write request operation when the FIFO IP core is full.
		output wire         empty  //            .empty,   When empty signal is asserted, the FIFO IP core is considered empty.Do not perform read request operation when the FIFO IP core is empty.
	);
endmodule

