	component fifo_hppb is
		port (
			data  : in  std_logic_vector(522 downto 0) := (others => 'X'); -- datain
			wrreq : in  std_logic                      := 'X';             -- wrreq
			rdreq : in  std_logic                      := 'X';             -- rdreq
			clock : in  std_logic                      := 'X';             -- clk
			q     : out std_logic_vector(522 downto 0);                    -- dataout
			full  : out std_logic;                                         -- full
			empty : out std_logic                                          -- empty
		);
	end component fifo_hppb;

	u0 : component fifo_hppb
		port map (
			data  => CONNECTED_TO_data,  --  fifo_input.datain
			wrreq => CONNECTED_TO_wrreq, --            .wrreq
			rdreq => CONNECTED_TO_rdreq, --            .rdreq
			clock => CONNECTED_TO_clock, --            .clk
			q     => CONNECTED_TO_q,     -- fifo_output.dataout
			full  => CONNECTED_TO_full,  --            .full
			empty => CONNECTED_TO_empty  --            .empty
		);

