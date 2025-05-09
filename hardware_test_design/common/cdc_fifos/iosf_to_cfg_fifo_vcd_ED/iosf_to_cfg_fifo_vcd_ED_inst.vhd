	component iosf_to_cfg_fifo_vcd_ED is
		port (
			data    : in  std_logic_vector(143 downto 0) := (others => 'X'); -- datain
			wrreq   : in  std_logic                      := 'X';             -- wrreq
			rdreq   : in  std_logic                      := 'X';             -- rdreq
			wrclk   : in  std_logic                      := 'X';             -- wrclk
			rdclk   : in  std_logic                      := 'X';             -- rdclk
			aclr    : in  std_logic                      := 'X';             -- aclr
			q       : out std_logic_vector(143 downto 0);                    -- dataout
			rdempty : out std_logic;                                         -- rdempty
			wrfull  : out std_logic                                          -- wrfull
		);
	end component iosf_to_cfg_fifo_vcd_ED;

	u0 : component iosf_to_cfg_fifo_vcd_ED
		port map (
			data    => CONNECTED_TO_data,    --  fifo_input.datain
			wrreq   => CONNECTED_TO_wrreq,   --            .wrreq
			rdreq   => CONNECTED_TO_rdreq,   --            .rdreq
			wrclk   => CONNECTED_TO_wrclk,   --            .wrclk
			rdclk   => CONNECTED_TO_rdclk,   --            .rdclk
			aclr    => CONNECTED_TO_aclr,    --            .aclr
			q       => CONNECTED_TO_q,       -- fifo_output.dataout
			rdempty => CONNECTED_TO_rdempty, --            .rdempty
			wrfull  => CONNECTED_TO_wrfull   --            .wrfull
		);

