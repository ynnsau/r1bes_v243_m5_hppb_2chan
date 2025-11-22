
module prefetch_one
#(
  	parameter interval = 3000,	// interval (in cycles) between prefetch requests
	parameter range_bit = 34	// range of address bits for lower and upper address
)
(
	input logic clk_i,
  	input logic reset_ni,					// active high reset
	input logic [63:0] start_address_i, 	// user defined starting address
	input logic [range_bit - 1:0] address_lower_i,		// 16GB range
	input logic [range_bit - 1:0] address_upper_i,		// 16GB range
	input logic [31:0] csr_prefetch_interval_i, // prefetch interval from CSR
    input logic [63:0] csr_prefetch_fifo_ahead_offset,

    input logic [63:0] chan0_address_i, 
    input logic chan0_address_valid,

    input logic [63:0] chan1_address_i, 
    input logic chan1_address_valid,

    input logic get_next_addr,
    input logic addr_issued,

  	output logic is_prefetch_o,			// signal start of prefetching
  	output logic [63:0] is_direct_ncp_o, // address to prefetch, byte level address
  	output logic [63:0] prefetch_addr_o	// address to prefetch, byte level address
);

localparam max_range = 64'h1 << 34;	// 2^34 = 16GB

logic [30:0] cycle_counter;			// a large enough counter to count the interval
logic [30:0] prefetch_interval;
logic addr_valid;
logic is_prefetch_r;
logic [63:0] addr_reg, addr_with_offset_reg, addr_curr, end_addr_reg;
logic prefetch_enable;
(* preserve_for_debug *) logic addr_gt_lb, addr_lt_ub;

assign addr_gt_lb = addr_with_offset_reg >= start_address_i;
assign addr_lt_ub = addr_with_offset_reg <= end_addr_reg;
assign is_prefetch_o = prefetch_enable & is_prefetch_r; // only allow prefetch when enabled

always_comb begin
    prefetch_enable = 1'b0; // this will be set by MSB of csr_prefetch_interval_i
	prefetch_interval = interval;
	if (csr_prefetch_interval_i[30:0] != 31'h0) begin
		prefetch_interval = csr_prefetch_interval_i[30:0];
	end

    if (csr_prefetch_interval_i[31]) begin 
        prefetch_enable = 1'b1;
    end
end

always_ff @(posedge clk_i) begin
	if(~reset_ni || start_address_i == '0) begin
		cycle_counter <= '0;
		is_prefetch_r <= '0;
        is_direct_ncp_o <= '0;
        prefetch_addr_o <= '0;
	end
	else begin
	
		if (address_upper_i < address_lower_i) begin
			is_prefetch_r <= '0;
		end
		else if(cycle_counter >= prefetch_interval) begin
			cycle_counter <= '0;
            if (address_upper_i[31:0] == 32'hC000 && address_lower_i[31:0] == 32'h0) begin // C000 = 48MB
                is_direct_ncp_o <= (addr_gt_lb && addr_lt_ub); 
            end else if (address_lower_i[31:0] != 32'hFFFF) begin // 64MB check
                if (address_upper_i == address_lower_i) begin
                    prefetch_addr_o <= start_address_i;
                    is_prefetch_r <= 1'b1;
                end else begin
                    prefetch_addr_o <= addr_with_offset_reg;
                    is_prefetch_r <= (addr_gt_lb && addr_lt_ub);
                end
            end
		end
		else begin
			cycle_counter <= cycle_counter + 1;
            is_direct_ncp_o <= '0;
			is_prefetch_r <= '0;
		end

	end
end

always_ff @(posedge clk_i) begin
	if(~reset_ni || start_address_i == '0) begin
        addr_reg <= '0;
        addr_with_offset_reg <= '0;
        end_addr_reg <= '0;
    end else begin
        if (addr_valid) begin
            addr_reg <= addr_curr;
            addr_with_offset_reg <= addr_reg + csr_prefetch_fifo_ahead_offset;
        end 
        end_addr_reg <= start_address_i + address_upper_i;
    end
end

always_comb begin
    addr_valid = 1'b0;
    addr_curr = '0;

    if (chan0_address_valid) begin
        addr_valid = 1'b1;
        addr_curr = chan0_address_i;
    end else if (chan1_address_valid) begin
        addr_valid = 1'b1;
        addr_curr = chan0_address_i;
    end
end

endmodule


