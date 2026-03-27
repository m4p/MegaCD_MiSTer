library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;

entity CDC is
	port(
		CLK			: in std_logic;
		RESET_N		: in std_logic;
		ENABLE		: in std_logic;
		CLKEN_P 		: in std_logic;
		CLKEN_N 		: in std_logic;
		
		DI				: in std_logic_vector(7 downto 0);
		DO				: out std_logic_vector(7 downto 0);
		CS_N			: in std_logic;
		RS				: in std_logic;
		RD_N			: in std_logic;
		WR_N			: in std_logic;
		INT_N			: out std_logic;
		
		HDO			: out std_logic_vector(7 downto 0);
		HRD_N			: in std_logic;
		DTEN_N		: out std_logic;
		WAIT_N		: out std_logic;
		
		CD_DI			: in std_logic_vector(15 downto 0);
		CD_WR			: in std_logic;

		RAM_A_WR   	: out std_logic_vector(15 downto 1);
		RAM_A_RD   	: out std_logic_vector(15 downto 0);
		RAM_DI		: in std_logic_vector(7 downto 0);
		RAM_DO		: out std_logic_vector(15 downto 0);
		RAM_WE		: out std_logic;
		SS_REQ      : in std_logic := '0';
		SS_WR       : in std_logic := '0';
		SS_ADDR     : in std_logic_vector(3 downto 0) := (others => '0');
		SS_DIN      : in std_logic_vector(31 downto 0) := (others => '0');
		SS_DOUT     : out std_logic_vector(31 downto 0);
		SS_ACK      : out std_logic
	);
end CDC;

architecture rtl of CDC is
	
	--IFSTAT bits
	constant STEN : integer := 0;
	constant DTEN : integer := 1;
	constant STBSY : integer := 2;
	constant DTBSY : integer := 3;
	constant DECI : integer := 5;
	constant DTEI : integer := 6;
	constant CMDI : integer := 7;
	
	--IFCTRL bits
	constant SOUTEN : integer := 0;
	constant DOUTEN : integer := 1;
	constant STWAI : integer := 2;
	constant DTWAI : integer := 3;
	constant CMDBK : integer := 4;
	constant DECIEN : integer := 5;
	constant DTEIEN : integer := 6;
	constant CMDIEN : integer := 7;
	
	--CTRL0 bits
	constant PRQ : integer := 0;
	constant QRQ : integer := 1;
	constant WRRQ : integer := 2;
	constant ERAMRQ : integer := 3;
	constant AUTORQ : integer := 4;
	constant EO1RQ : integer := 5;
	constant EDCRQ : integer := 6;
	constant DECEN : integer := 7;
	
	--CTRL1 bits
	constant SHDREN : integer := 0;
	constant MBCKRQ : integer := 1;
	constant FORMRQ : integer := 2;
	constant MODRQ : integer := 3;
	constant COWREN : integer := 4;
	constant OSCREN : integer := 5;
	constant SYDEN : integer := 6;
	constant SYIEN : integer := 7;
	
	--STAT0 bits
	constant UCEBLK : integer := 0;
	constant ERABLK : integer := 1;
	constant SBLK : integer := 2;
	constant WSHORT : integer := 3;
	constant LBLK : integer := 4;
	constant NOSYNC : integer := 5;
	constant ILSYNC : integer := 6;
	constant CRCOK : integer := 7;
	
	--STAT2 bits
	constant RFORM0 : integer := 0;
	constant RFORM1 : integer := 1;
	constant NOCOR : integer := 2;
	constant MODE : integer := 3;
	constant RMOD0 : integer := 4;
	constant RMOD1 : integer := 5;
	constant RMOD2 : integer := 6;
	constant RMOD3 : integer := 7;
	
	--STAT3 bits
	constant CBLK : integer := 5;
	constant WLONG : integer := 6;
	constant VALST : integer := 7;
	
	signal EN : std_logic;
	
	signal AR : std_logic_vector(3 downto 0);
	signal IFCTRL : std_logic_vector(7 downto 0);
	signal IFSTAT : std_logic_vector(7 downto 0) := x"FF";
	signal DO_I : std_logic_vector(7 downto 0);
	signal DBC : std_logic_vector(15 downto 0);
	signal DAC : std_logic_vector(15 downto 0);
	signal HEAD0 : std_logic_vector(7 downto 0);
	signal HEAD1 : std_logic_vector(7 downto 0);
	signal HEAD2 : std_logic_vector(7 downto 0);
	signal HEAD3 : std_logic_vector(7 downto 0);
	signal PT : std_logic_vector(15 downto 0);
	signal WA : std_logic_vector(15 downto 0);
	signal CTRL0 : std_logic_vector(7 downto 0);
	signal CTRL1 : std_logic_vector(7 downto 0);
	signal STAT0 : std_logic_vector(7 downto 0) := x"00";
	constant STAT1 : std_logic_vector(7 downto 0) := x"00";
	signal STAT2 : std_logic_vector(7 downto 0) := x"00";
	signal STAT3 : std_logic_vector(7 downto 0) := x"80";
	
	signal OLD_WR_N : std_logic;
	signal OLD_RD_N : std_logic;
--	signal OLD_HRD_N : std_logic;
	signal WR_F : std_logic;
	signal RD_F : std_logic;
--	signal HRD_R : std_logic;
--	signal HRD_F : std_logic;
	signal REG_WR : std_logic;
	signal REG_RD : std_logic;
	
	type TransferState_t is (
		TS_IDLE,
		TS_WAIT,
		TS_RAM_READ,
		TS_FIFO,
		TS_SEND_WAIT,
		TS_SEND
	);

	function ts_to_slv(ts : TransferState_t) return std_logic_vector is
	begin
		case ts is
			when TS_IDLE      => return "000";
			when TS_WAIT      => return "001";
			when TS_RAM_READ  => return "010";
			when TS_FIFO      => return "011";
			when TS_SEND_WAIT => return "100";
			when others       => return "101";
		end case;
	end function;

	function slv_to_ts(v : std_logic_vector(2 downto 0)) return TransferState_t is
	begin
		case v is
			when "000" => return TS_IDLE;
			when "001" => return TS_WAIT;
			when "010" => return TS_RAM_READ;
			when "011" => return TS_FIFO;
			when "100" => return TS_SEND_WAIT;
			when others => return TS_SEND;
		end case;
	end function;

	signal TS : TransferState_t;
	signal TRANS_RUN : std_logic;
	signal FIFO_DATA0 : std_logic_vector(8 downto 0);
--	signal FIFO_DATA1 : std_logic_vector(8 downto 0);
--	signal FIFO_RD_POS : std_logic;
--	signal FIFO_WR_POS : std_logic;
	signal DT_EN : std_logic;
	signal DTEN_N_I : std_logic;
	signal WAIT_N_I : std_logic;
	
	signal CD_WR_OLD : std_logic;
	signal WORD_CNT : unsigned(10 downto 0);
	signal RAM_POS : unsigned(11 downto 0);
	signal DEC_POS : unsigned(11 downto 0);
	signal DEC_ADDR : std_logic_vector(15 downto 0);
	signal DEC_DAT : std_logic_vector(15 downto 0);
	signal DEC_WR : std_logic;
	signal DEC_WR_EN : std_logic;
	signal DEC_HEAD01 : std_logic_vector(15 downto 0);
	signal DEC_HEAD23 : std_logic_vector(15 downto 0);

	constant CDC_SS_WORDS : integer := 10;
	constant CDC_SS_CTRL_ADDR : std_logic_vector(3 downto 0) := x"F";
	type ss_words_t is array(0 to CDC_SS_WORDS - 1) of std_logic_vector(31 downto 0);
	signal SS_SHADOW : ss_words_t := (others => (others => '0'));
	signal SS_REQ_D : std_logic := '0';
	signal SS_ADDR_D : std_logic_vector(3 downto 0) := (others => '0');
	signal SS_COMMIT_PENDING : std_logic := '0';
	signal SS_APPLY : std_logic;
	
--	signal DECI_WAIT_CNT : unsigned(15 downto 0);
--	signal DECI_SET : std_logic;
	signal OLD_WRRQ : std_logic;
	
begin

	EN <= ENABLE and (CLKEN_N or CLKEN_P);
	DO <= DO_I;
	DTEN_N <= DTEN_N_I;
	WAIT_N <= WAIT_N_I;
	SS_APPLY <= SS_COMMIT_PENDING;
	SS_ACK <= SS_REQ_D;

	process(RESET_N, CLK)
	begin
		if RESET_N = '0' then
			SS_REQ_D <= '0';
			SS_ADDR_D <= (others => '0');
			SS_COMMIT_PENDING <= '0';
			SS_SHADOW <= (others => (others => '0'));
		elsif rising_edge(CLK) then
			SS_REQ_D <= SS_REQ;
			if SS_REQ = '1' then
				SS_ADDR_D <= SS_ADDR;
			end if;

			if SS_REQ = '1' and SS_WR = '1' then
				case SS_ADDR is
					when x"0" => SS_SHADOW(0) <= SS_DIN;
					when x"1" => SS_SHADOW(1) <= SS_DIN;
					when x"2" => SS_SHADOW(2) <= SS_DIN;
					when x"3" => SS_SHADOW(3) <= SS_DIN;
					when x"4" => SS_SHADOW(4) <= SS_DIN;
					when x"5" => SS_SHADOW(5) <= SS_DIN;
					when x"6" => SS_SHADOW(6) <= SS_DIN;
					when x"7" => SS_SHADOW(7) <= SS_DIN;
					when x"8" => SS_SHADOW(8) <= SS_DIN;
					when x"9" => SS_SHADOW(9) <= SS_DIN;
					when others =>
						if SS_ADDR = CDC_SS_CTRL_ADDR and SS_DIN(31) = '1' then
							SS_COMMIT_PENDING <= '1';
						end if;
				end case;
			end if;

			if SS_APPLY = '1' then
				SS_COMMIT_PENDING <= '0';
			end if;
		end if;
	end process;

	process(SS_ADDR_D, AR, OLD_WR_N, OLD_RD_N, DT_EN, CD_WR_OLD, DEC_WR_EN, TS, DTEN_N_I, WAIT_N_I, FIFO_DATA0,
	        DO_I, IFCTRL, IFSTAT, CTRL0, CTRL1, STAT0, STAT2, STAT3, HEAD0, HEAD1, HEAD2, HEAD3, DBC, DAC,
	        PT, WA, DEC_HEAD01, DEC_HEAD23, DEC_DAT, WORD_CNT, RAM_POS, DEC_POS)
	begin
		SS_DOUT <= (others => '0');
		case SS_ADDR_D is
			when x"0" =>
				SS_DOUT(3 downto 0) <= AR;
				SS_DOUT(4) <= OLD_WR_N;
				SS_DOUT(5) <= OLD_RD_N;
				SS_DOUT(6) <= DT_EN;
				SS_DOUT(7) <= CD_WR_OLD;
				SS_DOUT(8) <= DEC_WR_EN;
				SS_DOUT(11 downto 9) <= ts_to_slv(TS);
				SS_DOUT(12) <= DTEN_N_I;
				SS_DOUT(13) <= WAIT_N_I;
				SS_DOUT(14) <= FIFO_DATA0(8);
				SS_DOUT(23 downto 16) <= DO_I;
			when x"1" =>
				SS_DOUT(7 downto 0) <= IFCTRL;
				SS_DOUT(15 downto 8) <= IFSTAT;
				SS_DOUT(23 downto 16) <= CTRL0;
				SS_DOUT(31 downto 24) <= CTRL1;
			when x"2" =>
				SS_DOUT(7 downto 0) <= STAT0;
				SS_DOUT(15 downto 8) <= STAT2;
				SS_DOUT(23 downto 16) <= STAT3;
				SS_DOUT(31 downto 24) <= HEAD0;
			when x"3" =>
				SS_DOUT(7 downto 0) <= HEAD1;
				SS_DOUT(15 downto 8) <= HEAD2;
				SS_DOUT(23 downto 16) <= HEAD3;
			when x"4" =>
				SS_DOUT(15 downto 0) <= DBC;
				SS_DOUT(31 downto 16) <= DAC;
			when x"5" =>
				SS_DOUT(15 downto 0) <= PT;
				SS_DOUT(31 downto 16) <= WA;
			when x"6" =>
				SS_DOUT(15 downto 0) <= DEC_HEAD01;
				SS_DOUT(31 downto 16) <= DEC_HEAD23;
			when x"7" =>
				SS_DOUT(15 downto 0) <= DEC_DAT;
				SS_DOUT(23 downto 16) <= FIFO_DATA0(7 downto 0);
			when x"8" =>
				SS_DOUT(10 downto 0) <= std_logic_vector(WORD_CNT);
				SS_DOUT(23 downto 12) <= std_logic_vector(RAM_POS);
			when x"9" =>
				SS_DOUT(11 downto 0) <= std_logic_vector(DEC_POS);
			when others =>
				if SS_ADDR_D = CDC_SS_CTRL_ADDR then
					SS_DOUT <= std_logic_vector(to_unsigned(CDC_SS_WORDS, 32));
				end if;
		end case;
	end process;

	process( RESET_N, CLK )
	begin
		if RESET_N = '0' then
			OLD_WR_N <= '1';
			OLD_RD_N <= '1';
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				OLD_WR_N <= SS_SHADOW(0)(4);
				OLD_RD_N <= SS_SHADOW(0)(5);
			elsif EN = '1' then
				OLD_WR_N <= WR_N;
				OLD_RD_N <= RD_N;
			end if;
		end if;
	end process;
	
	WR_F <= not WR_N and OLD_WR_N;
	RD_F <= not RD_N and OLD_RD_N;
	
	REG_WR <= not CS_N and WR_F and RS;
	REG_RD <= not CS_N and RD_F and RS;
	
	process( RESET_N, CLK )
	begin
		if RESET_N = '0' then
			AR <= (others => '0');
			IFCTRL <= (others => '0');
			CTRL0 <= (others => '0');
			CTRL1 <= (others => '0');
			STAT0(CRCOK) <= '0';
			STAT2(MODE) <= '0';
			STAT2(NOCOR) <= '0';
			DO_I <= (others => '0');
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				AR <= SS_SHADOW(0)(3 downto 0);
				IFCTRL <= SS_SHADOW(1)(7 downto 0);
				CTRL0 <= SS_SHADOW(1)(23 downto 16);
				CTRL1 <= SS_SHADOW(1)(31 downto 24);
				STAT0 <= SS_SHADOW(2)(7 downto 0);
				STAT2 <= SS_SHADOW(2)(15 downto 8);
				DO_I <= SS_SHADOW(0)(23 downto 16);
			elsif EN = '1' then
				if CS_N = '0' and WR_F = '1' then
					if RS = '0' then
						AR <= DI(3 downto 0);
					else
						case AR is
							when x"0" =>			--R0
							when x"1" =>			--R1 IFCTRL
								IFCTRL <= DI;	
							when x"A" =>			--R10 CTRL0
								CTRL0 <= DI;
								STAT0(CRCOK) <= DI(DECEN);
								if DI(AUTORQ) = '1' then
									STAT2(MODE) <= CTRL1(MODRQ);
								else
									STAT2(MODE) <= CTRL1(MODRQ);
									STAT2(NOCOR) <= CTRL1(FORMRQ);
								end if;
							when x"B" =>			--R11 CTRL1
								CTRL1 <= DI;
								if CTRL0(AUTORQ) = '1' then
									STAT2(MODE) <= DI(MODRQ);
								else
									STAT2(MODE) <= DI(MODRQ);
									STAT2(NOCOR) <= DI(FORMRQ);
								end if;
							when x"F" =>			--R15 RESET
								IFCTRL <= (others => '0');
								CTRL0 <= (others => '0');
								CTRL1 <= (others => '0');
							when others => null;
						end case;
						if AR /= x"0" then
							AR <= std_logic_vector( unsigned(AR) + 1 );
						end if;
					end if;
				elsif CS_N = '0' and RD_F = '1' then
					if RS = '0' then
						DO_I <= x"0" & AR;
					else
						case AR is
							when x"0" =>			--R0
								
							when x"1" =>			--R1 IFSTAT
								DO_I <= IFSTAT;
							when x"2" =>			--R2 DBCL
								DO_I <= DBC(7 downto 0);
							when x"3" =>			--R3 DBCH
								DO_I <= DBC(15 downto 8);
							when x"4" =>			--R4 HEAD0
								DO_I <= HEAD0;
							when x"5" =>			--R5 HEAD1
								DO_I <= HEAD1;
							when x"6" =>			--R6 HEAD2
								DO_I <= HEAD2;
							when x"7" =>			--R6 HEAD3
								DO_I <= HEAD3;
							when x"8" =>			--R8 PTL
								DO_I <= PT(7 downto 0);
							when x"9" =>			--R9 PTH
								DO_I <= PT(15 downto 8);
							when x"A" =>			--R10 WAL
								DO_I <= WA(7 downto 0);
							when x"B" =>			--R11 WAH
								DO_I <= WA(15 downto 8);
							when x"C" =>			--R12 STAT0
								DO_I <= STAT0;
							when x"D" =>			--R13 STAT1
								DO_I <= STAT1;
							when x"E" =>			--R14 STAT2
								DO_I <= STAT2;
							when x"F" =>			--R15 STAT3
								DO_I <= STAT3;
							when others => null;
						end case;
					end if;
					if AR /= x"0" then
						AR <= std_logic_vector( unsigned(AR) + 1 );
					end if;
				end if;
			end if;
		end if;
	end process;
	
	
	process( RESET_N, CLK )
	variable CD_BYTE : std_logic_vector(7 downto 0);
	begin
		if RESET_N = '0' then
			PT <= (others => '0');
			WA <= (others => '0');
			IFSTAT(DECI) <= '1';
			STAT3(VALST) <= '1';
			HEAD0 <= (others => '0');
			HEAD1 <= (others => '0');
			HEAD2 <= (others => '0');
			HEAD3 <= x"01";
			
			CD_WR_OLD <= '0';
			WORD_CNT <= (others => '0');
			RAM_POS <= (others => '0');
			DEC_POS <= (others => '0');
			DEC_DAT <= (others => '0');
			DEC_WR <= '0';
			DEC_WR_EN <= '0';
			DEC_HEAD01 <= (others => '0');
			DEC_HEAD23 <= (others => '0');
			
--			DECI_SET <= '0';
--			DECI_WAIT_CNT <= (others => '0');
		elsif rising_edge(CLK) then
			DEC_WR <= '0';
			if SS_APPLY = '1' then
				PT <= SS_SHADOW(5)(15 downto 0);
				WA <= SS_SHADOW(5)(31 downto 16);
				IFSTAT(DECI) <= SS_SHADOW(1)(8 + DECI);
				STAT3 <= SS_SHADOW(2)(23 downto 16);
				HEAD0 <= SS_SHADOW(2)(31 downto 24);
				HEAD1 <= SS_SHADOW(3)(7 downto 0);
				HEAD2 <= SS_SHADOW(3)(15 downto 8);
				HEAD3 <= SS_SHADOW(3)(23 downto 16);
				CD_WR_OLD <= SS_SHADOW(0)(7);
				WORD_CNT <= unsigned(SS_SHADOW(8)(10 downto 0));
				RAM_POS <= unsigned(SS_SHADOW(8)(23 downto 12));
				DEC_POS <= unsigned(SS_SHADOW(9)(11 downto 0));
				DEC_DAT <= SS_SHADOW(7)(15 downto 0);
				DEC_WR_EN <= SS_SHADOW(0)(8);
				DEC_HEAD01 <= SS_SHADOW(6)(15 downto 0);
				DEC_HEAD23 <= SS_SHADOW(6)(31 downto 16);
			elsif EN = '1' then
				if REG_WR = '1' then
					case AR is
						when x"8" =>			--R8 WAL
							WA(7 downto 0) <= DI;
						when x"9" =>			--R9 WAH
							WA(15 downto 8) <= DI;
						when x"C" =>			--R12 PTL
							PT(7 downto 0) <= DI;
						when x"D" =>			--R13 PTH
							PT(15 downto 8) <= DI;
						when x"F" =>			--R15 RESET
							IFSTAT(DECI) <= '1';
							STAT3(VALST) <= '1';
						when others => null;
					end case;
				elsif REG_RD = '1' then
					case AR is
						when x"F" =>			--R15 STAT3
							IFSTAT(DECI) <= '1';
							STAT3(VALST) <= '1';
						when others => null;
					end case;
				end if;
				
				DEC_WR_EN <= CTRL0(WRRQ);
			
				if CTRL0(DECEN) = '1' then
					CD_WR_OLD <= CD_WR;
					if CD_WR = '1' and CD_WR_OLD = '0' then
						DEC_DAT <= CD_DI;
						DEC_POS <= RAM_POS;
					
						WORD_CNT <= WORD_CNT + 1;
						if WORD_CNT = 0 then
--							DEC_WR_EN <= CTRL0(WRRQ);
						elsif WORD_CNT = 12/2 then
							DEC_HEAD01 <= CD_DI;
							if CTRL0(WRRQ) = '0' then
								HEAD0 <= CD_DI(7 downto 0);
								HEAD1 <= CD_DI(15 downto 8);
							end if;
							DEC_WR <= '1';
							RAM_POS <= RAM_POS + 2;
						elsif WORD_CNT = 14/2 then
							DEC_HEAD23 <= CD_DI;
							if CTRL0(WRRQ) = '0' then
								HEAD2 <= CD_DI(7 downto 0);
								HEAD3 <= CD_DI(15 downto 8);
							end if;
							DEC_WR <= '1';
							RAM_POS <= RAM_POS + 2;
						elsif WORD_CNT >= 16/2 and WORD_CNT <= (16+2048)/2-1 then
							DEC_WR <= '1';
							RAM_POS <= RAM_POS + 2;
						elsif WORD_CNT = 2352/2-1 then
--							DECI_SET <= '1';
							IFSTAT(DECI) <= '0';
							STAT3(VALST) <= '0';
						end if;
						
						if WORD_CNT = 2352/2-1 then
							WORD_CNT <= (others => '0');
							RAM_POS <= (others => '0');
--							DEC_WR_EN <= CTRL0(WRRQ);
						end if;
--						if CTRL0(WRRQ) = '0' then
--							DEC_WR_EN <= '0';
--						end if;

						if DEC_WR_EN = '1' then
----							WA <= std_logic_vector( unsigned(WA) + 2 );
							if WORD_CNT = 2352/2-1 then
								WA <= std_logic_vector( unsigned(WA) + 2352 );
								PT <= std_logic_vector( unsigned(PT) + 2352 );
								HEAD0 <= DEC_HEAD01(7 downto 0);
								HEAD1 <= DEC_HEAD01(15 downto 8);
								HEAD2 <= DEC_HEAD23(7 downto 0);
								HEAD3 <= DEC_HEAD23(15 downto 8);
							end if;
						end if;
					end if;
				else
					WORD_CNT <= (others => '0');
					RAM_POS <= (others => '0');
				end if;
			end if;
		end if;
	end process;
	
	DEC_ADDR <= std_logic_vector( unsigned(PT) + 2352 + DEC_POS );
	RAM_A_WR <= DEC_ADDR(15 downto 1);
	RAM_DO <= DEC_DAT;
	RAM_WE <= DEC_WR and DEC_WR_EN and CTRL0(DECEN);

	process( RESET_N, CLK )
	begin
		if RESET_N = '0' then
--			OLD_HRD_N <= '1';
			DT_EN <= '0';
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				DT_EN <= SS_SHADOW(0)(6);
			elsif EN = '1' then
				DT_EN <= not DT_EN;
				if DT_EN = '1' then
--					OLD_HRD_N <= HRD_N;
				end if;
			end if;
		end if;
	end process;
	
--	HRD_R <= HRD_N and not OLD_HRD_N;
--	HRD_F <= not HRD_N and OLD_HRD_N;
	
	process( RESET_N, CLK )
	begin
		if RESET_N = '0' then
			DBC <= (others => '0');
			DAC <= (others => '0');
			TS <= TS_IDLE;
			IFSTAT(DTEN) <= '1';
			IFSTAT(DTEI) <= '1';
			IFSTAT(DTBSY) <= '1';
			DTEN_N_I <= '1';
			WAIT_N_I <= '0';
			FIFO_DATA0 <= (others => '0');
--			FIFO_DATA1 <= (others => '0');
--			FIFO_WR_POS <= '0';
--			FIFO_RD_POS <= '0';
			
		elsif rising_edge(CLK) then
			if SS_APPLY = '1' then
				DBC <= SS_SHADOW(4)(15 downto 0);
				DAC <= SS_SHADOW(4)(31 downto 16);
				TS <= slv_to_ts(SS_SHADOW(0)(11 downto 9));
				IFSTAT(DTEN) <= SS_SHADOW(1)(8 + DTEN);
				IFSTAT(DTEI) <= SS_SHADOW(1)(8 + DTEI);
				IFSTAT(DTBSY) <= SS_SHADOW(1)(8 + DTBSY);
				DTEN_N_I <= SS_SHADOW(0)(12);
				WAIT_N_I <= SS_SHADOW(0)(13);
				FIFO_DATA0(8) <= SS_SHADOW(0)(14);
				FIFO_DATA0(7 downto 0) <= SS_SHADOW(7)(23 downto 16);
			elsif EN = '1' then
				if REG_WR = '1' then
					case AR is
						when x"2" =>			--R2 DBCL
							DBC(7 downto 0) <= DI;
						when x"3" =>			--R3 DBCH
							DBC(15 downto 8) <= DI;
						when x"4" =>			--R4 DACL
							DAC(7 downto 0) <= DI;
						when x"5" =>			--R5 DACH
							DAC(15 downto 8) <= DI;
						when x"6" =>			--R6 DTTRG
--							IFSTAT(DTBSY) <= '0';
--							IFSTAT(DTEI) <= '1';
--							DBC(15 downto 12) <= "0000";
						when x"7" =>			--R6 DTACK
							IFSTAT(DTEI) <= '1';
							DBC(15 downto 12) <= "0000";
						when x"F" =>			--R15 RESET
--							IFSTAT(DTEN) <= '1';
--							IFSTAT(DTEI) <= '1';
--							IFSTAT(DTBSY) <= '1';
						when others => null;
					end case;
				end if;
				
				
				if (REG_WR = '1' and AR = x"F") or (REG_WR = '1' and AR = x"1" and DI(DOUTEN) = '0') then
					IFSTAT(DTBSY) <= '1';
					IFSTAT(DTEN) <= '1';
					IFSTAT(DTEI) <= '1';
					DTEN_N_I <= '1';
					
--					FIFO_RD_POS <= '0';
					FIFO_DATA0(8) <= '0';
--					FIFO_DATA1(8) <= '0';
					TS <= TS_IDLE;
				elsif REG_WR = '1' and AR = x"6" then
					if IFCTRL(DOUTEN) = '1' then
						IFSTAT(DTBSY) <= '0';
--						IFSTAT(DTEN) <= '0';
						DBC(15 downto 12) <= "0000";
						
--						FIFO_RD_POS <= '0';
						FIFO_DATA0(8) <= '0';
--						FIFO_DATA1(8) <= '0';
					end if;
--				elsif REG_WR = '1' and AR = x"7" then
--					IFSTAT(DTEI) <= '1';
--					DBC(15 downto 12) <= "0000";
				elsif IFCTRL(DOUTEN) = '1' and DT_EN = '1' then--
					case TS is
						when TS_IDLE =>
							if IFSTAT(DTBSY) = '0' then
								WAIT_N_I <= '1';
								TS <= TS_WAIT;
							end if;
							
						when TS_WAIT =>
--							if FIFO_DATA0(8) = '0' then
--								FIFO_WR_POS <= '0';
								TS <= TS_FIFO;--TS_RAM_READ;
--							elsif FIFO_DATA1(8) = '0' then
--								FIFO_WR_POS <= '1';
--								TS <= TS_RAM_READ;
--							elsif DBC(11 downto 0) = x"000" then--IFSTAT(DTEN) = '1'
--								TS <= TS_IDLE;
--							end if;
							
						when TS_RAM_READ =>
							TS <= TS_FIFO;
						
						when TS_FIFO =>
--							if FIFO_WR_POS = '0' then
								FIFO_DATA0 <= "1" & RAM_DI;
								if IFSTAT(DTEN) = '1' then
									IFSTAT(DTEN) <= '0';
									DTEN_N_I <= '0';
								end if;
--							else
--								FIFO_DATA1 <= "1" & RAM_DI;
--							end if;
							DAC <= std_logic_vector( unsigned(DAC) + 1 );
							TS <= TS_SEND_WAIT;
							
						when TS_SEND_WAIT =>
							if HRD_N = '0' then
								WAIT_N_I <= '0';
								TS <= TS_SEND;
							end if;
						
						when TS_SEND =>
							if HRD_N = '1' then
								WAIT_N_I <= '1';
								
								DBC(11 downto 0) <= std_logic_vector( unsigned(DBC(11 downto 0)) - 1 );
--								FIFO_RD_POS <= not FIFO_RD_POS;
--								if FIFO_RD_POS = '0' then
--									FIFO_DATA0(8) <= '0';
--								else
--									FIFO_DATA1(8) <= '0';
--								end if;
						
								if DBC(11 downto 0) = x"000" then
									IFSTAT(DTEN) <= '1';
									IFSTAT(DTBSY) <= '1';
									IFSTAT(DTEI) <= '0';
									DTEN_N_I <= '1';
									DBC(15 downto 12) <= "1111";
									TS <= TS_IDLE;
								else
									TS <= TS_WAIT;
								end if;
							end if;
							
						when others => null;
					end case;
				
--					if HRD_F = '1' then
--						WAIT_N <= '0';
--					elsif HRD_R = '1' then
--						DBC(11 downto 0) <= std_logic_vector( unsigned(DBC(11 downto 0)) - 1 );
--						FIFO_RD_POS <= not FIFO_RD_POS;
--						if FIFO_RD_POS = '0' then
--							FIFO_DATA0(8) <= '0';
--						else
--							FIFO_DATA1(8) <= '0';
--						end if;
--						if DBC(11 downto 0) = x"000" then
--							IFSTAT(DTEN) <= '1';
--							IFSTAT(DTBSY) <= '1';
--							IFSTAT(DTEI) <= '0';
--							DTEN_N <= '1';
----							FIFO_RD_POS <= '0';
----							FIFO_DATA0(8) <= '0';
----							FIFO_DATA1(8) <= '0';
--							DBC(15 downto 12) <= "1111";
--							TS <= TS_IDLE;
--						end if;
--						WAIT_N <= '1';
--					end if;
				end if;
			end if;
		end if;
	end process;
	
	HDO <= FIFO_DATA0(7 downto 0);-- when FIFO_RD_POS = '0' else FIFO_DATA1(7 downto 0);
	
	RAM_A_RD <= DAC;
	
	
	INT_N <= (IFSTAT(DTEI) or not IFCTRL(DTEIEN)) and (IFSTAT(DECI) or not IFCTRL(DECIEN));
	
end rtl;

