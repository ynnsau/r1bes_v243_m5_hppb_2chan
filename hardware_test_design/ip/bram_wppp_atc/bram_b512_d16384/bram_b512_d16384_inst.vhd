	component bram_b512_d16384 is
		port (
			data      : in  std_logic_vector(511 downto 0) := (others => 'X'); -- datain
			q         : out std_logic_vector(511 downto 0);                    -- dataout
			wraddress : in  std_logic_vector(13 downto 0)  := (others => 'X'); -- wraddress
			rdaddress : in  std_logic_vector(13 downto 0)  := (others => 'X'); -- rdaddress
			wren      : in  std_logic                      := 'X';             -- wren
			clock     : in  std_logic                      := 'X';             -- clk
			byteena_a : in  std_logic_vector(63 downto 0)  := (others => 'X')  -- byte_enable_a
		);
	end component bram_b512_d16384;

	u0 : component bram_b512_d16384
		port map (
			data      => CONNECTED_TO_data,      --      data.datain
			q         => CONNECTED_TO_q,         --         q.dataout
			wraddress => CONNECTED_TO_wraddress, -- wraddress.wraddress
			rdaddress => CONNECTED_TO_rdaddress, -- rdaddress.rdaddress
			wren      => CONNECTED_TO_wren,      --      wren.wren
			clock     => CONNECTED_TO_clock,     --     clock.clk
			byteena_a => CONNECTED_TO_byteena_a  -- byteena_a.byte_enable_a
		);

