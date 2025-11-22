/**  prefetch_dummy.sv
  *  a dummy module periodically generates random prefetch requests to the prefetch module
  *
  */
module prefetch_dummy
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

  	output logic is_prefetch_o,			// signal start of prefetching
  	output logic [63:0] is_direct_ncp_o, // address to prefetch, byte level address
  	output logic [63:0] prefetch_addr_o	// address to prefetch, byte level address
);

localparam max_range = 64'h1 << 34;	// 2^34 = 16GB

logic [31:0] cycle_counter;			// a large enough counter to count the interval
logic [16:0] upper_random_bits;		// upper address range bits
logic [16:0] lower_random_bits;		// lower address range bits
logic [33:0] address_offsets;		// address offsets to be added to the start address
logic [range_bit - 1:0] range;                	// range between lower and upper
logic [range_bit - 1:0] random_offset;        	// random offset within range
logic [31:0] prefetch_interval;

// fibonacci_lfsr #(.LFSR_WIDTH(17), .LFSR_SEED(17'hBEEF)) 
// top_lfsr (
// 	.clk(clk_i),
// 	.reset(~reset_ni),
// 	.lfsr_out(upper_random_bits)
// );

// fibonacci_lfsr #(.LFSR_WIDTH(17), .LFSR_SEED(17'hCAFE))
// bottom_lfsr (
// 	.clk(clk_i),
// 	.reset(~reset_ni),
// 	.lfsr_out(lower_random_bits)
// );

// random offset generation
// assign address_offsets = {upper_random_bits, lower_random_bits}; // 34 bits
// assign range = (address_upper_i > address_lower_i) ? (address_upper_i - address_lower_i) : 34'b0;
// for better distribution when range is small
// assign random_offset = (range != '0) ? (((address_offsets ^ {address_offsets[16:0], address_offsets[33:17]}))) : 34'b0;

always_comb begin
	prefetch_interval = interval;
	if (csr_prefetch_interval_i != 32'h0) begin
		prefetch_interval = csr_prefetch_interval_i;
	end
end

always_ff @(posedge clk_i) begin
	if(~reset_ni || start_address_i == '0) begin
		cycle_counter <= '0;
		is_prefetch_o <= '0;
        is_direct_ncp_o <= '0;
		prefetch_addr_o <= start_address_i;
	end
	else begin
		if (address_upper_i == address_lower_i) begin
			prefetch_addr_o <= start_address_i;
		end
		else if (prefetch_addr_o <= start_address_i + {30'b0, address_upper_i}) begin
			// generate a random address within [start_address_i + address_lower_i, start_address_i + address_upper_i)
			// prefetch_addr_o <= start_address_i + {30'b0, address_lower_i} + {30'b0, random_offset};
			if (is_prefetch_o == '1 || is_direct_ncp_o == '1) begin
			     prefetch_addr_o <= prefetch_addr_o + 64'b01000000;
			end
		end
		else begin
			prefetch_addr_o <= start_address_i + {30'b0, address_lower_i};
		end
	
		if (address_upper_i < address_lower_i) begin
			is_prefetch_o <= '0;
		end
		else if(cycle_counter >= prefetch_interval) begin
			cycle_counter <= '0;
            if (address_upper_i[31:0] == 32'hC000 && address_lower_i[31:0] == 32'h0) begin
                is_direct_ncp_o <= 1'b1;
            end else if (address_lower_i[31:0] != 32'hFFFF) begin 
                is_prefetch_o <= 1'b1;
            end
		end
		else begin
			cycle_counter <= cycle_counter + 1;
            is_direct_ncp_o <= '0;
			is_prefetch_o <= '0;
		end
		
		
	end

end

endmodule


module fibonacci_lfsr
#(
    parameter LFSR_WIDTH = 17,
    parameter LFSR_SEED = 17'h1,            // non-zero seed value
    parameter TAPS = 17'b10001000000000000  // taps at positions 17 and 14 for a 17-bit Fibonacci LFSR
)
(
    input logic clk,
    input logic reset,
    output logic [LFSR_WIDTH-1:0] lfsr_out
);
    logic [LFSR_WIDTH-1:0] lfsr_reg;
    logic feedback;

    // Parameterized lfsr feedback calculation using TAPS
    always_comb begin
        feedback = '0;
        for (int i = 0; i < LFSR_WIDTH; i++) begin
            if (TAPS[i]) begin
                feedback = feedback ^ lfsr_reg[i];
			end
        end
    end
    
    always_ff @(posedge clk) begin
        if (reset) begin
            lfsr_reg <= LFSR_SEED;  // set seed
        end 
		else begin
            // feedback to the LSB
            lfsr_reg <= {lfsr_reg[LFSR_WIDTH-2:0], feedback};
        end
    end
    
    // output current LFSR state
    assign lfsr_out = lfsr_reg;
endmodule
