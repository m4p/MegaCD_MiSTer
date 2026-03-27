library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;

entity CD_DAC is
	port(
		CLK			: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		
		PALSW			: in std_logic;
		
		CD_DI			: in std_logic_vector(15 downto 0);
		CD_WR			: in std_logic;
		
		FD_DI			: in std_logic_vector(10 downto 0);
		FD_WR			: in std_logic;
		SS_REQ      : in std_logic := '0';
		SS_WR       : in std_logic := '0';
		SS_ADDR     : in std_logic_vector(10 downto 0) := (others => '0');
		SS_DIN      : in std_logic_vector(31 downto 0) := (others => '0');
		SS_DOUT     : out std_logic_vector(31 downto 0);
		SS_ACK      : out std_logic;

		WR_READY 		: out std_logic;

		SL				: out signed(15 downto 0);
		SR				: out signed(15 downto 0)
	);
end CD_DAC;

architecture rtl of CD_DAC is

	signal EN 			: std_logic;
	
	signal CD_WR_OLD 	: std_logic;
	signal LR 			: std_logic;
	signal FULL 		: std_logic;
	signal EMPTY 		: std_logic;
	signal WR_READY_I : std_logic;
	signal RD_REQ 		: std_logic;
	signal WR_REQ 		: std_logic;
	signal FIFO_D 		: std_logic_vector(31 downto 0);
	signal FIFO_Q 		: std_logic_vector(31 downto 0);
	signal SAMPLE_CE 	: std_logic;
	signal FIFO_SS_REQ  : std_logic;
	signal FIFO_SS_ADDR : std_logic_vector(10 downto 0);
	signal FIFO_SS_DOUT : std_logic_vector(31 downto 0);
	signal FIFO_SS_ACK  : std_logic;
	signal SS_LOCAL_REQ_D : std_logic := '0';
	signal SS_DOUT_REG    : std_logic_vector(31 downto 0) := (others => '0');

	signal ATT 			: unsigned(10 downto 0);
	signal ATT_CUR 	: unsigned(11 downto 0);
	
	signal OUTL 		: signed(15 downto 0);
	signal OUTR 		: signed(15 downto 0);
	
	signal CDDA_REF   : integer;

	component CDDA_FIFO
		port (
			CLK, nRESET, RD, WR         : in std_logic;
			DIN                         : in std_logic_vector(31 downto 0);
			SS_REQ                      : in std_logic;
			SS_WR                       : in std_logic;
			SS_ADDR                     : in std_logic_vector(10 downto 0);
			SS_DIN                      : in std_logic_vector(31 downto 0);
			EMPTY, FULL, WRITE_READY    : out std_logic;
			Q                           : out std_logic_vector(31 downto 0);
			SS_DOUT                     : out std_logic_vector(31 downto 0);
			SS_ACK                      : out std_logic
		);
	end component;

begin

	EN <= ENABLE;
	WR_READY <= WR_READY_I;
	SS_ACK <= SS_LOCAL_REQ_D or FIFO_SS_ACK;
	SS_DOUT <= SS_DOUT_REG when SS_LOCAL_REQ_D = '1' else FIFO_SS_DOUT;
	FIFO_SS_REQ <= SS_REQ when unsigned(SS_ADDR) >= 3 else '0';
	FIFO_SS_ADDR <= std_logic_vector(unsigned(SS_ADDR) - 3) when unsigned(SS_ADDR) >= 3 else (others => '0');

	process(RST_N, CLK)
	begin
		if RST_N = '0' then
			SS_LOCAL_REQ_D <= '0';
			SS_DOUT_REG <= (others => '0');
		elsif rising_edge(CLK) then
			SS_LOCAL_REQ_D <= '0';
			if SS_REQ = '1' and unsigned(SS_ADDR) < 3 then
				SS_LOCAL_REQ_D <= '1';
				SS_DOUT_REG <= (others => '0');
				case SS_ADDR(1 downto 0) is
					when "00" =>
						SS_DOUT_REG(0) <= CD_WR_OLD;
						SS_DOUT_REG(1) <= LR;
						SS_DOUT_REG(2) <= FULL;
						SS_DOUT_REG(3) <= EMPTY;
						SS_DOUT_REG(4) <= RD_REQ;
						SS_DOUT_REG(5) <= WR_REQ;
						SS_DOUT_REG(6) <= WR_READY_I;
						SS_DOUT_REG(17 downto 7) <= std_logic_vector(ATT);
						SS_DOUT_REG(29 downto 18) <= std_logic_vector(ATT_CUR);
					when "01" =>
						SS_DOUT_REG <= FIFO_D;
					when others =>
						SS_DOUT_REG(15 downto 0) <= std_logic_vector(OUTL);
						SS_DOUT_REG(31 downto 16) <= std_logic_vector(OUTR);
				end case;
			end if;
		end if;
	end process;

	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			LR <= '0';
			FIFO_D <= (others => '0');
			WR_REQ <= '0';
			CD_WR_OLD <= '0';
		elsif rising_edge(CLK) then
			WR_REQ <= '0';
			if SS_REQ = '1' and SS_WR = '1' and unsigned(SS_ADDR) < 3 then
				case SS_ADDR(1 downto 0) is
					when "00" =>
						CD_WR_OLD <= SS_DIN(0);
						LR <= SS_DIN(1);
						WR_REQ <= SS_DIN(5);
					when "01" =>
						FIFO_D <= SS_DIN;
					when others =>
						null;
				end case;
			elsif EN = '1' then
				CD_WR_OLD <= CD_WR;
				if CD_WR = '1' and CD_WR_OLD = '0' then
					LR <= not LR;
					if LR = '0' then
						FIFO_D(15 downto 0) <= CD_DI;
					else
						FIFO_D(31 downto 16) <= CD_DI;
						if FULL = '0' then
							WR_REQ <= '1';
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

	
	FIFO : CDDA_FIFO
	port map(
		CLK          => CLK,
		nRESET      => RST_N,
		DIN         => FIFO_D,
		WR          => WR_REQ,
		FULL        => FULL,
		WRITE_READY => WR_READY_I,

		RD          => RD_REQ,
		EMPTY       => EMPTY,
		Q           => FIFO_Q,
		SS_REQ      => FIFO_SS_REQ,
		SS_WR       => SS_WR,
		SS_ADDR     => FIFO_SS_ADDR,
		SS_DIN      => SS_DIN,
		SS_DOUT     => FIFO_SS_DOUT,
		SS_ACK      => FIFO_SS_ACK
	);
	
	CDDA_REF <= 532034 when PALSW = '1' else 536931;
	
	CEGen : entity work.CEGen
	port map(
		CLK   		=> CLK,
		RST_N       => RST_N,		
		IN_CLK   	=> CDDA_REF,
		OUT_CLK   	=> 441,
		CE   			=> SAMPLE_CE
	);
	
	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			ATT <= "10000000000";
		elsif rising_edge(CLK) then
			if SS_REQ = '1' and SS_WR = '1' and SS_ADDR = "00000000000" then
				ATT <= unsigned(SS_DIN(17 downto 7));
			elsif EN = '1' then
				if FD_WR = '1' then
					ATT <= unsigned(FD_DI);
				end if;
			end if;
		end if;
	end process;
	
	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			RD_REQ <= '0';
			ATT_CUR <= "010000000000";
			OUTL <= (others => '0');
			OUTR <= (others => '0');
		elsif rising_edge(CLK) then
			RD_REQ <= '0';
			if SS_REQ = '1' and SS_WR = '1' and unsigned(SS_ADDR) < 3 then
				case SS_ADDR(1 downto 0) is
					when "00" =>
						RD_REQ <= SS_DIN(4);
						ATT_CUR <= unsigned(SS_DIN(29 downto 18));
					when "10" =>
						OUTL <= signed(SS_DIN(15 downto 0));
						OUTR <= signed(SS_DIN(31 downto 16));
					when others =>
						null;
				end case;
			elsif EN = '1' and SAMPLE_CE = '1' then	-- ~44.1kHz
				if EMPTY = '0' then
					RD_REQ <= '1';
					OUTL <= resize(shift_right(signed(FIFO_Q(15 downto 0)) * signed(ATT_CUR), 10), OUTL'length);
					OUTR <= resize(shift_right(signed(FIFO_Q(31 downto 16)) * signed(ATT_CUR), 10), OUTR'length);
				else
					OUTL <= (others => '0');
					OUTR <= (others => '0');
				end if;
				
				if ATT_CUR(10 downto 0) > ATT then
					ATT_CUR <= "0" & (ATT_CUR(10 downto 0) - 1);
				elsif ATT_CUR(10 downto 0) < ATT then
					ATT_CUR <= "0" & (ATT_CUR(10 downto 0) + 1);
				end if;
			end if;
		end if;
	end process;

	SL <= OUTL;
	SR <= OUTR;

end rtl;
