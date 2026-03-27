library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;

entity PCM is
	port(
		CLK			: in std_logic;
		RST_N			: in std_logic;
		ENABLE		: in std_logic;
		CLKEN 		: in std_logic;
		
		PALSW			: in std_logic;
		
		A				: in std_logic_vector(12 downto 0);
		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		CS_N			: in std_logic;
		RD_N			: in std_logic;
		WR_N			: in std_logic;
		
		RAM_ADDR_A 	: out std_logic_vector(15 downto 0);
		RAM_DI_A		: in std_logic_vector(7 downto 0);
		RAM_DO_A		: out std_logic_vector(7 downto 0);
		RAM_WE_A		: out std_logic;
		RAM_ADDR_B  : out std_logic_vector(15 downto 0);
		RAM_DI_B		: in std_logic_vector(7 downto 0);
		SS_REQ      : in std_logic := '0';
		SS_WR       : in std_logic := '0';
		SS_ADDR     : in std_logic_vector(4 downto 0) := (others => '0');
		SS_DIN      : in std_logic_vector(31 downto 0) := (others => '0');
		SS_DOUT     : out std_logic_vector(31 downto 0);
		SS_ACK      : out std_logic;

		SL				: out signed(15 downto 0);
		SR				: out signed(15 downto 0)
	);
end PCM;

architecture rtl of PCM is
	
	type reg8x8_t is array(0 to 7) of std_logic_vector(7 downto 0);
	type reg8x16_t is array(0 to 7) of std_logic_vector(15 downto 0);
	type reg8x27_t is array(0 to 7) of std_logic_vector(26 downto 0);
	
	--IO
	signal OLD_WR_N	: std_logic;
	signal OLD_RD_N 	: std_logic;
	signal WR_F 		: std_logic;
	signal RD_F 		: std_logic;
	signal IO_WR 		: std_logic;
	signal IO_RD 		: std_logic;
	signal RAM_WR 		: std_logic;
	signal RAM_RD 		: std_logic;
	signal RAM_DI 		: std_logic_vector(7 downto 0);
	signal DO_I       : std_logic_vector(7 downto 0);
	
	--Registers
	signal WB 			: std_logic_vector(3 downto 0);
	signal CB 			: std_logic_vector(2 downto 0);
	signal ONOFF 		: std_logic;
	signal ENV 			: reg8x8_t;
	signal PAN 			: reg8x8_t;
	signal FD 			: reg8x16_t;
	signal LS 			: reg8x16_t;
	signal ST 			: reg8x8_t;
	signal CHOFF 		: std_logic_vector(7 downto 0);
	
	signal EN 			: std_logic;
	signal CLK_CNT		: unsigned(5 downto 0);
	signal SAMPLE_CE 	: std_logic;
	signal STEP 		: std_logic;
	signal WRA 			: reg8x27_t;
	signal CH 			: unsigned(2 downto 0);
	signal LSUM, RSUM : unsigned(16 downto 0);
	signal LOUT, ROUT : signed(15 downto 0);
		
	signal PCM_REF   : integer;

	constant PCM_SS_WORDS : integer := 27;
	constant PCM_SS_CTRL_ADDR : std_logic_vector(4 downto 0) := "11111";
	type ss_words_t is array(0 to PCM_SS_WORDS - 1) of std_logic_vector(31 downto 0);
	signal SS_SHADOW : ss_words_t := (others => (others => '0'));
	signal SS_REQ_D : std_logic := '0';
	signal SS_DOUT_REG : std_logic_vector(31 downto 0) := (others => '0');
	signal SS_COMMIT_PENDING : std_logic := '0';
	signal SS_APPLY : std_logic;

	impure function CLAMP16(a: unsigned(16 downto 0)) return unsigned is
		variable res: unsigned(15 downto 0); 
	begin
		if a(16 downto 15) = "01" then
			res := x"7FFF";
		elsif a(16 downto 15) = "10" then
			res := x"8000";
		else
			res := a(16) & a(14 downto 0);
		end if;
		return res;
	end function;


begin

	EN <= ENABLE and CLKEN;
	DO <= DO_I;
	SL <= LOUT;
	SR <= ROUT;
	SS_APPLY <= SS_COMMIT_PENDING;
	SS_ACK <= SS_REQ_D;
	SS_DOUT <= SS_DOUT_REG;

	process(RST_N, CLK)
	begin
		if RST_N = '0' then
			SS_REQ_D <= '0';
			SS_DOUT_REG <= (others => '0');
			SS_COMMIT_PENDING <= '0';
			SS_SHADOW <= (others => (others => '0'));
		elsif rising_edge(CLK) then
			SS_REQ_D <= SS_REQ;
			if SS_REQ = '1' then
				SS_DOUT_REG <= (others => '0');
				case SS_ADDR is
					when "00000" =>
						SS_DOUT_REG(0) <= OLD_WR_N;
						SS_DOUT_REG(1) <= OLD_RD_N;
						SS_DOUT_REG(5 downto 2) <= WB;
						SS_DOUT_REG(8 downto 6) <= CB;
						SS_DOUT_REG(9) <= ONOFF;
						SS_DOUT_REG(17 downto 10) <= CHOFF;
						SS_DOUT_REG(18) <= STEP;
						SS_DOUT_REG(21 downto 19) <= std_logic_vector(CH);
						SS_DOUT_REG(29 downto 22) <= DO_I;
					when "00001" =>
						SS_DOUT_REG(7 downto 0) <= ENV(0);
						SS_DOUT_REG(15 downto 8) <= PAN(0);
						SS_DOUT_REG(23 downto 16) <= ENV(1);
						SS_DOUT_REG(31 downto 24) <= PAN(1);
					when "00010" =>
						SS_DOUT_REG(7 downto 0) <= ENV(2);
						SS_DOUT_REG(15 downto 8) <= PAN(2);
						SS_DOUT_REG(23 downto 16) <= ENV(3);
						SS_DOUT_REG(31 downto 24) <= PAN(3);
					when "00011" =>
						SS_DOUT_REG(7 downto 0) <= ENV(4);
						SS_DOUT_REG(15 downto 8) <= PAN(4);
						SS_DOUT_REG(23 downto 16) <= ENV(5);
						SS_DOUT_REG(31 downto 24) <= PAN(5);
					when "00100" =>
						SS_DOUT_REG(7 downto 0) <= ENV(6);
						SS_DOUT_REG(15 downto 8) <= PAN(6);
						SS_DOUT_REG(23 downto 16) <= ENV(7);
						SS_DOUT_REG(31 downto 24) <= PAN(7);
					when "00101" =>
						SS_DOUT_REG(15 downto 0) <= FD(0);
						SS_DOUT_REG(31 downto 16) <= LS(0);
					when "00110" =>
						SS_DOUT_REG(15 downto 0) <= FD(1);
						SS_DOUT_REG(31 downto 16) <= LS(1);
					when "00111" =>
						SS_DOUT_REG(15 downto 0) <= FD(2);
						SS_DOUT_REG(31 downto 16) <= LS(2);
					when "01000" =>
						SS_DOUT_REG(15 downto 0) <= FD(3);
						SS_DOUT_REG(31 downto 16) <= LS(3);
					when "01001" =>
						SS_DOUT_REG(15 downto 0) <= FD(4);
						SS_DOUT_REG(31 downto 16) <= LS(4);
					when "01010" =>
						SS_DOUT_REG(15 downto 0) <= FD(5);
						SS_DOUT_REG(31 downto 16) <= LS(5);
					when "01011" =>
						SS_DOUT_REG(15 downto 0) <= FD(6);
						SS_DOUT_REG(31 downto 16) <= LS(6);
					when "01100" =>
						SS_DOUT_REG(15 downto 0) <= FD(7);
						SS_DOUT_REG(31 downto 16) <= LS(7);
					when "01101" =>
						SS_DOUT_REG(7 downto 0) <= ST(0);
						SS_DOUT_REG(15 downto 8) <= ST(1);
						SS_DOUT_REG(23 downto 16) <= ST(2);
						SS_DOUT_REG(31 downto 24) <= ST(3);
					when "01110" =>
						SS_DOUT_REG(7 downto 0) <= ST(4);
						SS_DOUT_REG(15 downto 8) <= ST(5);
						SS_DOUT_REG(23 downto 16) <= ST(6);
						SS_DOUT_REG(31 downto 24) <= ST(7);
					when "01111" =>
						SS_DOUT_REG(26 downto 0) <= WRA(0);
					when "10000" =>
						SS_DOUT_REG(26 downto 0) <= WRA(1);
					when "10001" =>
						SS_DOUT_REG(26 downto 0) <= WRA(2);
					when "10010" =>
						SS_DOUT_REG(26 downto 0) <= WRA(3);
					when "10011" =>
						SS_DOUT_REG(26 downto 0) <= WRA(4);
					when "10100" =>
						SS_DOUT_REG(26 downto 0) <= WRA(5);
					when "10101" =>
						SS_DOUT_REG(26 downto 0) <= WRA(6);
					when "10110" =>
						SS_DOUT_REG(26 downto 0) <= WRA(7);
					when "10111" =>
						SS_DOUT_REG(16 downto 0) <= std_logic_vector(LSUM);
					when "11000" =>
						SS_DOUT_REG(16 downto 0) <= std_logic_vector(RSUM);
					when "11001" =>
						SS_DOUT_REG(15 downto 0) <= std_logic_vector(LOUT);
						SS_DOUT_REG(31 downto 16) <= std_logic_vector(ROUT);
					when "11010" =>
						SS_DOUT_REG(7 downto 0) <= RAM_DI;
					when others =>
						if SS_ADDR = PCM_SS_CTRL_ADDR then
							SS_DOUT_REG <= std_logic_vector(to_unsigned(PCM_SS_WORDS, 32));
						end if;
				end case;
			end if;

			if SS_REQ = '1' and SS_WR = '1' then
				case SS_ADDR is
					when "00000" => SS_SHADOW(0) <= SS_DIN;
					when "00001" => SS_SHADOW(1) <= SS_DIN;
					when "00010" => SS_SHADOW(2) <= SS_DIN;
					when "00011" => SS_SHADOW(3) <= SS_DIN;
					when "00100" => SS_SHADOW(4) <= SS_DIN;
					when "00101" => SS_SHADOW(5) <= SS_DIN;
					when "00110" => SS_SHADOW(6) <= SS_DIN;
					when "00111" => SS_SHADOW(7) <= SS_DIN;
					when "01000" => SS_SHADOW(8) <= SS_DIN;
					when "01001" => SS_SHADOW(9) <= SS_DIN;
					when "01010" => SS_SHADOW(10) <= SS_DIN;
					when "01011" => SS_SHADOW(11) <= SS_DIN;
					when "01100" => SS_SHADOW(12) <= SS_DIN;
					when "01101" => SS_SHADOW(13) <= SS_DIN;
					when "01110" => SS_SHADOW(14) <= SS_DIN;
					when "01111" => SS_SHADOW(15) <= SS_DIN;
					when "10000" => SS_SHADOW(16) <= SS_DIN;
					when "10001" => SS_SHADOW(17) <= SS_DIN;
					when "10010" => SS_SHADOW(18) <= SS_DIN;
					when "10011" => SS_SHADOW(19) <= SS_DIN;
					when "10100" => SS_SHADOW(20) <= SS_DIN;
					when "10101" => SS_SHADOW(21) <= SS_DIN;
					when "10110" => SS_SHADOW(22) <= SS_DIN;
					when "10111" => SS_SHADOW(23) <= SS_DIN;
					when "11000" => SS_SHADOW(24) <= SS_DIN;
					when "11001" => SS_SHADOW(25) <= SS_DIN;
					when "11010" => SS_SHADOW(26) <= SS_DIN;
					when others =>
						if SS_ADDR = PCM_SS_CTRL_ADDR and SS_DIN(31) = '1' then
							SS_COMMIT_PENDING <= '1';
						end if;
				end case;
			end if;

			if SS_APPLY = '1' then
				SS_COMMIT_PENDING <= '0';
			end if;
		end if;
	end process;

	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			OLD_WR_N <= '1';
			OLD_RD_N <= '1';
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				OLD_WR_N <= SS_SHADOW(0)(0);
				OLD_RD_N <= SS_SHADOW(0)(1);
			elsif EN = '1' then
				OLD_WR_N <= WR_N;
				OLD_RD_N <= RD_N;
			end if;
		end if;
	end process;
	
	WR_F <= not WR_N and OLD_WR_N;
	RD_F <= not RD_N and OLD_RD_N;
	
	IO_WR <= '1' when CS_N = '0' and WR_F = '1' and A(12 downto 4) = "000000000" else '0';
	IO_RD <= '1' when CS_N = '0' and RD_F = '1' and A(12 downto 4) = "000000001" else '0';
	RAM_WR <= '1' when CS_N = '0' and WR_F = '1' and A(12) = '1' else '0';
	RAM_RD <= '1' when CS_N = '0' and RD_F = '1' and A(12) = '1' else '0';
	
	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			WB <= (others => '0');
			CB <= (others => '0');
			ONOFF <= '0';
			ENV <= (others => (others => '0'));
			PAN <= (others => (others => '1'));
			FD <= (others => (others => '0'));
			LS <= (others => (others => '0'));
			ST <= (others => (others => '0'));
			CHOFF <= (others => '0');
			DO_I <= (others => '0');
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				WB <= SS_SHADOW(0)(5 downto 2);
				CB <= SS_SHADOW(0)(8 downto 6);
				ONOFF <= SS_SHADOW(0)(9);
				CHOFF <= SS_SHADOW(0)(17 downto 10);
				DO_I <= SS_SHADOW(0)(29 downto 22);
				ENV(0) <= SS_SHADOW(1)(7 downto 0);
				PAN(0) <= SS_SHADOW(1)(15 downto 8);
				ENV(1) <= SS_SHADOW(1)(23 downto 16);
				PAN(1) <= SS_SHADOW(1)(31 downto 24);
				ENV(2) <= SS_SHADOW(2)(7 downto 0);
				PAN(2) <= SS_SHADOW(2)(15 downto 8);
				ENV(3) <= SS_SHADOW(2)(23 downto 16);
				PAN(3) <= SS_SHADOW(2)(31 downto 24);
				ENV(4) <= SS_SHADOW(3)(7 downto 0);
				PAN(4) <= SS_SHADOW(3)(15 downto 8);
				ENV(5) <= SS_SHADOW(3)(23 downto 16);
				PAN(5) <= SS_SHADOW(3)(31 downto 24);
				ENV(6) <= SS_SHADOW(4)(7 downto 0);
				PAN(6) <= SS_SHADOW(4)(15 downto 8);
				ENV(7) <= SS_SHADOW(4)(23 downto 16);
				PAN(7) <= SS_SHADOW(4)(31 downto 24);
				FD(0) <= SS_SHADOW(5)(15 downto 0);
				LS(0) <= SS_SHADOW(5)(31 downto 16);
				FD(1) <= SS_SHADOW(6)(15 downto 0);
				LS(1) <= SS_SHADOW(6)(31 downto 16);
				FD(2) <= SS_SHADOW(7)(15 downto 0);
				LS(2) <= SS_SHADOW(7)(31 downto 16);
				FD(3) <= SS_SHADOW(8)(15 downto 0);
				LS(3) <= SS_SHADOW(8)(31 downto 16);
				FD(4) <= SS_SHADOW(9)(15 downto 0);
				LS(4) <= SS_SHADOW(9)(31 downto 16);
				FD(5) <= SS_SHADOW(10)(15 downto 0);
				LS(5) <= SS_SHADOW(10)(31 downto 16);
				FD(6) <= SS_SHADOW(11)(15 downto 0);
				LS(6) <= SS_SHADOW(11)(31 downto 16);
				FD(7) <= SS_SHADOW(12)(15 downto 0);
				LS(7) <= SS_SHADOW(12)(31 downto 16);
				ST(0) <= SS_SHADOW(13)(7 downto 0);
				ST(1) <= SS_SHADOW(13)(15 downto 8);
				ST(2) <= SS_SHADOW(13)(23 downto 16);
				ST(3) <= SS_SHADOW(13)(31 downto 24);
				ST(4) <= SS_SHADOW(14)(7 downto 0);
				ST(5) <= SS_SHADOW(14)(15 downto 8);
				ST(6) <= SS_SHADOW(14)(23 downto 16);
				ST(7) <= SS_SHADOW(14)(31 downto 24);
			elsif EN = '1' then
				if IO_WR = '1' then
					case A(3 downto 0) is
						when x"0" =>			--ENV
							ENV(to_integer(unsigned(CB))) <= DI;
						when x"1" =>			--PAN
							PAN(to_integer(unsigned(CB))) <= DI;
						when x"2" =>			--FDL
							FD(to_integer(unsigned(CB)))(7 downto 0) <= DI;
						when x"3" =>			--FDH
							FD(to_integer(unsigned(CB)))(15 downto 8) <= DI;
						when x"4" =>			--LSL
							LS(to_integer(unsigned(CB)))(7 downto 0) <= DI;
						when x"5" =>			--LSH
							LS(to_integer(unsigned(CB)))(15 downto 8) <= DI;
						when x"6" =>			--ST
							ST(to_integer(unsigned(CB))) <= DI;
						when x"7" =>			--Control register
							if DI(6) = '0' then
								WB <= DI(3 downto 0);
							else 
								CB <= DI(2 downto 0);
							end if;
							ONOFF <= DI(7);
						when x"8" =>			--Channel ON/OFF
							CHOFF <= DI;
						when others => null;
					end case;
				elsif IO_RD = '1' then
					case A(3 downto 0) is
						when x"0" =>			--
							DO_I <= WRA(0)(18 downto 11);
						when x"1" =>			--
							DO_I <= WRA(0)(26 downto 19);
						when x"2" =>			--
							DO_I <= WRA(1)(18 downto 11);
						when x"3" =>			--
							DO_I <= WRA(1)(26 downto 19);
						when x"4" =>			--
							DO_I <= WRA(2)(18 downto 11);
						when x"5" =>			--
							DO_I <= WRA(2)(26 downto 19);
						when x"6" =>			--
							DO_I <= WRA(3)(18 downto 11);
						when x"7" =>			--
							DO_I <= WRA(3)(26 downto 19);
						when x"8" =>			--
							DO_I <= WRA(4)(18 downto 11);
						when x"9" =>			--
							DO_I <= WRA(4)(26 downto 19);
						when x"A" =>			--
							DO_I <= WRA(5)(18 downto 11);
						when x"B" =>			--
							DO_I <= WRA(5)(26 downto 19);
						when x"C" =>			--
							DO_I <= WRA(6)(18 downto 11);
						when x"D" =>			--
							DO_I <= WRA(6)(26 downto 19);
						when x"E" =>			--
							DO_I <= WRA(7)(18 downto 11);
						when x"F" =>			--
							DO_I <= WRA(7)(26 downto 19);
						when others => null;
					end case;
				elsif RAM_RD = '1' then
					DO_I <= RAM_DI_A;
				end if;
			end if;
		end if;
	end process;
	
	RAM_ADDR_A <= WB & A(11 downto 0);
	RAM_DO_A <= DI;
	RAM_WE_A <= RAM_WR;
	
	PCM_REF <= 53203423 when PALSW = '1' else 53693175;

	CEGen : entity work.CEGen
	port map(
		CLK   		=> CLK,
		RST_N       => RST_N,		
		IN_CLK   	=> PCM_REF,
		OUT_CLK   	=> 520832,				--12500000/384=32552*8*2=520832
		CE   			=> SAMPLE_CE
	);
	
	process( RST_N, CLK )
	variable WD : unsigned(7 downto 0);
	variable MUL16 : unsigned(15 downto 0);
	variable MUL19L, MUL19R : unsigned(18 downto 0);
	variable SUM17L, SUM17R : unsigned(16 downto 0);
	begin
		if RST_N = '0' then
			CH <= (others => '0');
			WRA <= (others => (others => '0'));
			LOUT <= (others => '0');
			ROUT <= (others => '0');
			LSUM <= (others => '0');
			RSUM <= (others => '0');
			STEP <= '0';
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				CH <= unsigned(SS_SHADOW(0)(21 downto 19));
				WRA(0) <= SS_SHADOW(15)(26 downto 0);
				WRA(1) <= SS_SHADOW(16)(26 downto 0);
				WRA(2) <= SS_SHADOW(17)(26 downto 0);
				WRA(3) <= SS_SHADOW(18)(26 downto 0);
				WRA(4) <= SS_SHADOW(19)(26 downto 0);
				WRA(5) <= SS_SHADOW(20)(26 downto 0);
				WRA(6) <= SS_SHADOW(21)(26 downto 0);
				WRA(7) <= SS_SHADOW(22)(26 downto 0);
				LOUT <= signed(SS_SHADOW(25)(15 downto 0));
				ROUT <= signed(SS_SHADOW(25)(31 downto 16));
				LSUM <= unsigned(SS_SHADOW(23)(16 downto 0));
				RSUM <= unsigned(SS_SHADOW(24)(16 downto 0));
				STEP <= SS_SHADOW(0)(18);
				RAM_DI <= SS_SHADOW(26)(7 downto 0);
			else
				RAM_DI <= RAM_DI_B;
			end if;
			if SS_APPLY = '0' and ENABLE = '1' and SAMPLE_CE = '1' then
				STEP <= not STEP;
				if STEP = '0' then
					if CHOFF(to_integer(CH)) = '1' or ONOFF = '0' then
						WRA(to_integer(CH)) <= ST(to_integer(CH)) & "0000000000000000000";
					elsif RAM_DI = x"FF" then
						WRA(to_integer(CH)) <= LS(to_integer(CH)) & "00000000000";
					end if;
				else
					CH <= CH + 1;
					
					if CHOFF(to_integer(CH)) = '0' and ONOFF = '1' then
						WD := unsigned(RAM_DI);
					else
						WD := (others => '0');
					end if;
					
					MUL16 := resize( WD(6 downto 0) * unsigned(ENV(to_integer(CH))), MUL16'length );
					MUL19L := resize( MUL16 * unsigned(PAN(to_integer(CH))(3 downto 0)), MUL19L'length );
					MUL19R := resize( MUL16 * unsigned(PAN(to_integer(CH))(7 downto 4)), MUL19R'length );
					
					if WD(7) = '1' then
						SUM17L := resize( LSUM + MUL19L(18 downto 5), SUM17L'length );
						SUM17R := resize( RSUM + MUL19R(18 downto 5), SUM17R'length );
					else
						SUM17L := resize( LSUM - MUL19L(18 downto 5), SUM17L'length );
						SUM17R := resize( RSUM - MUL19R(18 downto 5), SUM17R'length );
					end if;
					
					if CH = 7 then
						LOUT <= signed( CLAMP16(SUM17L) );
						ROUT <= signed( CLAMP16(SUM17R) );
						LSUM <= (others => '0');
						RSUM <= (others => '0');
					else
						LSUM <= SUM17L;
						RSUM <= SUM17R;
					end if;
					
					if CHOFF(to_integer(CH)) = '0' and ONOFF = '1' then
						WRA(to_integer(CH)) <= std_logic_vector( unsigned(WRA(to_integer(CH))) + unsigned(FD(to_integer(CH))) );
					end if;
				end if;
			end if;
		end if;
	end process;

	RAM_ADDR_B <= WRA(to_integer(CH))(26 downto 11);

end rtl;
