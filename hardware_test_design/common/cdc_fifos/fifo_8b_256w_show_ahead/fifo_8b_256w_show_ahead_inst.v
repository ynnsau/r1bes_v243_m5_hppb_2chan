	fifo_8b_256w_show_ahead u0 (
		.data  (_connected_to_data_),  //   input,  width = 8,  fifo_input.datain
		.wrreq (_connected_to_wrreq_), //   input,  width = 1,            .wrreq
		.rdreq (_connected_to_rdreq_), //   input,  width = 1,            .rdreq
		.clock (_connected_to_clock_), //   input,  width = 1,            .clk
		.aclr  (_connected_to_aclr_),  //   input,  width = 1,            .aclr
		.q     (_connected_to_q_),     //  output,  width = 8, fifo_output.dataout
		.usedw (_connected_to_usedw_), //  output,  width = 8,            .usedw
		.full  (_connected_to_full_),  //  output,  width = 1,            .full
		.empty (_connected_to_empty_)  //  output,  width = 1,            .empty
	);

