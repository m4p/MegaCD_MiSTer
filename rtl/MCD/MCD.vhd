library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library STD;
use IEEE.NUMERIC_STD.ALL;

entity MCD is
	port(
		CLK				: in std_logic;
		RST_N				: in std_logic;
		ENABLE			: in std_logic;
		MCD_RST_N      : out std_logic;
		PALSW				: in std_logic;

		EXT_VA   		: in std_logic_vector(17 downto 1);
		EXT_VDI			: in std_logic_vector(15 downto 0);
		EXT_VDO			: out std_logic_vector(15 downto 0);
		EXT_AS_N			: in std_logic;
		EXT_RNW			: in std_logic;
		EXT_LDS_N		: in std_logic;
		EXT_UDS_N		: in std_logic;
		EXT_DTACK_N		: out std_logic;
		EXT_ASEL_N		: in std_logic;
		EXT_VCLK_CE		: in std_logic;
		EXT_RAS2_N		: in std_logic;
		EXT_ROM_N		: in std_logic;
		EXT_FDC_N		: in std_logic;
		
		PRG_A				: out std_logic_vector(17 downto 0);
		PRG_DI			: in std_logic_vector(15 downto 0);
		PRG_DO			: out std_logic_vector(15 downto 0);
		PRG_WRL_N		: out std_logic;	
		PRG_WRH_N		: out std_logic;	
		PRG_OE_N			: out std_logic;
		PRG_RFS			: out std_logic;
		PRG_RDY			: in std_logic;
		
		ROM_DI			: in std_logic_vector(15 downto 0);
		ROM_CE_N			: out std_logic;
		ROM_RDY			: in std_logic;
		
		BRAM_A			: out std_logic_vector(13 downto 1);
		BRAM_DI			: in std_logic_vector(7 downto 0);
		BRAM_DO			: out std_logic_vector(7 downto 0);
		BRAM_WE			: out std_logic;
		
		CDD_STAT			: in std_logic_vector(39 downto 0);
		CDD_COMM			: out std_logic_vector(39 downto 0);
		CDD_SEND			: out std_logic;
		CDD_REC			: in std_logic;
		CDD_DM			: in std_logic;
		
		CDC_DATA			: in std_logic_vector(15 downto 0);
		CDC_DAT_WR		: in std_logic;
		CDC_SC_WR		: in std_logic;
		CDC_CDDA_WR		: in std_logic;
		CDDA_WR_READY	: out std_logic;
		
		PCM_SL			: out signed(15 downto 0);
		PCM_SR			: out signed(15 downto 0);
		CDDA_SL			: out signed(15 downto 0);
		CDDA_SR			: out signed(15 downto 0);
		
		LED_RED			: out std_logic;
		LED_GREEN		: out std_logic;
		
		GG_RESET       : in std_logic;
		GG_EN          : in std_logic;
		GG_CODE        : in std_logic_vector(128 downto 0);
		GG_AVAILABLE   : out std_logic;

		DEBUG_PAUSE    : in std_logic;
		DEBUG_IDLE     : out std_logic;
		SAVESTATE_PAUSE: in std_logic;
		SAVESTATE_IDLE : out std_logic;
		SAVESTATE_RAM_REQ   : in std_logic;
		SAVESTATE_RAM_WR    : in std_logic;
		SAVESTATE_RAM_TARGET: in std_logic_vector(3 downto 0);
		SAVESTATE_RAM_ADDR  : in std_logic_vector(17 downto 0);
		SAVESTATE_RAM_DIN   : in std_logic_vector(15 downto 0);
		SAVESTATE_RAM_DOUT  : out std_logic_vector(15 downto 0);
		SAVESTATE_RAM_ACK   : out std_logic;
		SAVESTATE_CPU_REQ   : in std_logic := '0';
		SAVESTATE_CPU_WR    : in std_logic := '0';
		SAVESTATE_CPU_ADDR  : in std_logic_vector(5 downto 0) := (others => '0');
		SAVESTATE_CPU_DIN   : in std_logic_vector(31 downto 0) := (others => '0');
		SAVESTATE_CPU_DOUT  : out std_logic_vector(31 downto 0);
		SAVESTATE_CPU_ACK   : out std_logic;
		SAVESTATE_CDC_REQ   : in std_logic := '0';
		SAVESTATE_CDC_WR    : in std_logic := '0';
		SAVESTATE_CDC_ADDR  : in std_logic_vector(3 downto 0) := (others => '0');
		SAVESTATE_CDC_DIN   : in std_logic_vector(31 downto 0) := (others => '0');
		SAVESTATE_CDC_DOUT  : out std_logic_vector(31 downto 0);
		SAVESTATE_CDC_ACK   : out std_logic;
		SAVESTATE_PCM_REQ   : in std_logic := '0';
		SAVESTATE_PCM_WR    : in std_logic := '0';
		SAVESTATE_PCM_ADDR  : in std_logic_vector(4 downto 0) := (others => '0');
		SAVESTATE_PCM_DIN   : in std_logic_vector(31 downto 0) := (others => '0');
		SAVESTATE_PCM_DOUT  : out std_logic_vector(31 downto 0);
		SAVESTATE_PCM_ACK   : out std_logic;
		SAVESTATE_CDDA_REQ  : in std_logic := '0';
		SAVESTATE_CDDA_WR   : in std_logic := '0';
		SAVESTATE_CDDA_ADDR : in std_logic_vector(10 downto 0) := (others => '0');
		SAVESTATE_CDDA_DIN  : in std_logic_vector(31 downto 0) := (others => '0');
		SAVESTATE_CDDA_DOUT : out std_logic_vector(31 downto 0);
		SAVESTATE_CDDA_ACK  : out std_logic;
		SAVESTATE_ASIC_REQ  : in std_logic := '0';
		SAVESTATE_ASIC_WR   : in std_logic := '0';
		SAVESTATE_ASIC_ADDR : in std_logic_vector(5 downto 0) := (others => '0');
		SAVESTATE_ASIC_DIN  : in std_logic_vector(31 downto 0) := (others => '0');
		SAVESTATE_ASIC_DOUT : out std_logic_vector(31 downto 0);
		SAVESTATE_ASIC_ACK  : out std_logic;
		DEBUG_WORD_REQ : in std_logic;
		DEBUG_WORD_WE  : in std_logic;
		DEBUG_WORD_BANK: in std_logic;
		DEBUG_WORD_ADDR: in std_logic_vector(15 downto 0);
		DEBUG_WORD_DIN : in std_logic_vector(15 downto 0);
		DEBUG_WORD_DOUT: out std_logic_vector(15 downto 0);
		DEBUG_WORD_ACK : out std_logic;

		DBG_S68K_A		: out std_logic_vector(23 downto 0)
	);
end MCD;

architecture rtl of MCD is

	signal S68K_A   		: std_logic_vector(23 downto 1);
	signal S68K_DI			: std_logic_vector(15 downto 0);
	signal S68K_DO			: std_logic_vector(15 downto 0);
	signal S68K_AS_N		: std_logic;
	signal S68K_RNW		: std_logic;
	signal S68K_UDS_N		: std_logic;
	signal S68K_LDS_N		: std_logic;
	signal S68K_DTACK_N	: std_logic;
	signal S68K_IPL_N		: std_logic_vector(2 downto 0);
	signal S68K_VPA_N		: std_logic;
	signal S68K_FC			: std_logic_vector(2 downto 0);
	signal S68K_HALT_N	: std_logic;
	signal S68K_RESET_N	: std_logic;
	signal S68K_CE_F		: std_logic;
	signal S68K_CE_R		: std_logic;
	
	signal WORDRAM0_A   	: std_logic_vector(15 downto 0);
	signal WORDRAM0_DI	: std_logic_vector(15 downto 0);
	signal WORDRAM0_DO	: std_logic_vector(15 downto 0);
	signal WORDRAM0_WR	: std_logic;
	signal WORDRAM1_A   	: std_logic_vector(15 downto 0);
	signal WORDRAM1_DI	: std_logic_vector(15 downto 0);
	signal WORDRAM1_DO	: std_logic_vector(15 downto 0);
	signal WORDRAM1_WR	: std_logic;
	
	signal PCM_A			: std_logic_vector(12 downto 0);
	signal PCM_DO			: std_logic_vector(7 downto 0);
	signal PCM_DI			: std_logic_vector(7 downto 0);
	signal PCM_WE_N		: std_logic;
	signal PCM_N			: std_logic;
	
	signal PRAM_N			: std_logic;
	signal BRAM_N			: std_logic;
	signal BROM_N			: std_logic;
	signal CDC_N			: std_logic;
	signal COE_N			: std_logic;
	signal CLWE_N			: std_logic;
	signal CUWE_N			: std_logic;
	signal INT_N			: std_logic;
	signal ERES_N			: std_logic;
	
	signal ASIC_DO			: std_logic_vector(15 downto 0);
	
	signal CDC_DO			: std_logic_vector(7 downto 0);
	signal CDC_HDO			: std_logic_vector(7 downto 0);
	signal CDC_HRD_N		: std_logic;
	signal CDC_DTEN_N		: std_logic;
	signal CDC_WAIT_N		: std_logic;
	signal CDC_INT_N		: std_logic;
	signal CDC_RAM_A_WR	: std_logic_vector(15 downto 1);
	signal CDC_RAM_A_RD	: std_logic_vector(15 downto 0);
	signal CDC_RAM_DI		: std_logic_vector(7 downto 0);
	signal CDC_RAM_DO		: std_logic_vector(15 downto 0);
	signal CDC_RAM_WE		: std_logic;
	
	signal PCM_RAM_ADDR_A: std_logic_vector(15 downto 0);
	signal PCM_RAM_ADDR_B: std_logic_vector(15 downto 0);
	signal PCM_RAM_DI_A	: std_logic_vector(7 downto 0);
	signal PCM_RAM_DI_B	: std_logic_vector(7 downto 0);
	signal PCM_RAM_DO_A	: std_logic_vector(7 downto 0);
	signal PCM_RAM_WE_A	: std_logic;
	
	signal ASIC_FD_DAT	: std_logic_vector(10 downto 0);
	signal ASIC_FD_WR		: std_logic;
	signal ASIC_DEBUG_IDLE: std_logic;
	signal PAUSE_ACTIVE   : std_logic;
	signal SAVESTATE_RAM_REQ_D    : std_logic;
	signal SAVESTATE_RAM_TARGET_D : std_logic_vector(3 downto 0);

	signal RUN_EN         : std_logic;

	signal PRG_A_I        : std_logic_vector(17 downto 0);
	signal PRG_DO_I       : std_logic_vector(15 downto 0);
	signal PRG_WRL_N_I    : std_logic;
	signal PRG_WRH_N_I    : std_logic;
	signal PRG_OE_N_I     : std_logic;
	signal PRG_RFS_I      : std_logic;
	signal PCM_A_I        : std_logic_vector(12 downto 0);
	signal PCM_DO_I       : std_logic_vector(7 downto 0);
	signal PCM_WE_N_I     : std_logic;
	signal PCM_N_I        : std_logic;

	signal WORDRAM0_ADDR_I : std_logic_vector(15 downto 0);
	signal WORDRAM0_DATA_I : std_logic_vector(15 downto 0);
	signal WORDRAM0_WREN_I : std_logic;
	signal WORDRAM1_ADDR_I : std_logic_vector(15 downto 0);
	signal WORDRAM1_DATA_I : std_logic_vector(15 downto 0);
	signal WORDRAM1_WREN_I : std_logic;
	signal CDC_RAM_ADDR_B_I : std_logic_vector(12 downto 0);
	signal CDC_RAM_DO_I     : std_logic_vector(15 downto 0);
	signal CDC_RAM_WE_I     : std_logic;
	signal CDC_RAM_Q_B      : std_logic_vector(15 downto 0);
	signal PCM_RAM_ADDR_B_I : std_logic_vector(15 downto 0);
	signal PCM_RAM_DO_B_I   : std_logic_vector(7 downto 0);
	signal PCM_RAM_WE_B_I   : std_logic;

	signal DEBUG_WORD_REQ_D  : std_logic;
	signal DEBUG_WORD_BANK_D : std_logic;

	signal GENIE_DATA    : std_logic_vector(15 downto 0);
	
	component CODES
		generic
		(
			ADDR_WIDTH    : integer := 16;
			DATA_WIDTH    : integer := 8;
			BIG_ENDIAN    : integer := 0
		);
		port
		(
			clk           : in  std_logic;
			reset         : in  std_logic;
			enable        : in  std_logic;
			available     : out std_logic;
			code          : in  std_logic_vector(128 downto 0);
			addr_in       : in  std_logic_vector(23 downto 0);
			data_in       : in  std_logic_vector(15 downto 0);
			data_out      : out std_logic_vector(15 downto 0)
	  );
	end component; 
	
begin

	PAUSE_ACTIVE <= DEBUG_PAUSE or SAVESTATE_PAUSE;
	RUN_EN <= ENABLE and not PAUSE_ACTIVE;

	gg : CODES
	generic map(
		ADDR_WIDTH  => 24,
		DATA_WIDTH  => 16,
		BIG_ENDIAN  => 1
	)
	port map(
		clk         => CLK,
		reset       => GG_RESET,
		enable      => not GG_EN,
		available   => GG_AVAILABLE,
		code        => GG_CODE,
		addr_in     => S68K_A & '0',
		data_in     => S68K_DI,
		data_out    => GENIE_DATA
	);

	S68K :  entity work.M68K_WRAP
	port map(
		CLK   		=> CLK,
		RST_N      	=> RST_N,
		
		RESET_I_N	=> S68K_RESET_N,
		CLKEN_P   	=> S68K_CE_R and not PAUSE_ACTIVE,
		CLKEN_N		=> S68K_CE_F and not PAUSE_ACTIVE,
		A   			=> S68K_A,
		DI   			=> GENIE_DATA,
		DO   			=> S68K_DO,
		AS_N   		=> S68K_AS_N,
		RNW   		=> S68K_RNW,
		UDS_N   		=> S68K_UDS_N,
		LDS_N   		=> S68K_LDS_N,
		DTACK_N		=> S68K_DTACK_N,
		IPL_N   		=> S68K_IPL_N,
		VPA_N   		=> S68K_VPA_N,
		FC   			=> S68K_FC,
		HALT_I_N		=> S68K_HALT_N,
		BERR_N   	=> '1',
		BR_N   		=> '1',
		BGACK_N   	=> '1',
		SS_REQ		=> SAVESTATE_PAUSE and SAVESTATE_CPU_REQ,
		SS_WR			=> SAVESTATE_CPU_WR,
		SS_ADDR		=> SAVESTATE_CPU_ADDR,
		SS_DIN		=> SAVESTATE_CPU_DIN,
		SS_DOUT		=> SAVESTATE_CPU_DOUT,
		SS_ACK		=> SAVESTATE_CPU_ACK
	);
	
	S68K_DI(7 downto 0) <= CDC_DO when CDC_N = '0' else
								  BRAM_DI when BRAM_N = '0' else
								  PCM_DO when PCM_N = '0' else
								  ASIC_DO(7 downto 0);
	S68K_DI(15 downto 8) <= ASIC_DO(15 downto 8);
	
	ASIC : entity work.ASIC
	port map(
		CLK   			=> CLK,
		RST_N       	=> RST_N,
		ENABLE      	=> RUN_EN,
		
		S68K_A   		=> S68K_A(23 downto 1),
		S68K_DI   		=> S68K_DO,
		S68K_DO   		=> ASIC_DO,
		S68K_AS_N   	=> S68K_AS_N,
		S68K_RNW   		=> S68K_RNW,
		S68K_UDS_N   	=> S68K_UDS_N,
		S68K_LDS_N   	=> S68K_LDS_N,
		S68K_DTACK_N	=> S68K_DTACK_N,
		S68K_IPL_N   	=> S68K_IPL_N,
		S68K_VPA_N   	=> S68K_VPA_N,
		S68K_FC   		=> S68K_FC(1 downto 0),
		S68K_HALT_N   	=> S68K_HALT_N,
		S68K_RESET_N   => S68K_RESET_N,
		S68K_CE_F  	 	=> S68K_CE_F,
		S68K_CE_R   	=> S68K_CE_R,
		
		EXT_VA   		=> EXT_VA,
		EXT_VDI   		=> EXT_VDI,
		EXT_VDO   		=> EXT_VDO,
		EXT_AS_N   		=> EXT_AS_N,
		EXT_RNW   		=> EXT_RNW,
		EXT_UDS_N   	=> EXT_UDS_N,
		EXT_LDS_N   	=> EXT_LDS_N,
		EXT_DTACK_N   	=> EXT_DTACK_N,
		EXT_ASEL_N   	=> EXT_ASEL_N,
		EXT_VCLK_CE   	=> EXT_VCLK_CE,
		EXT_RAS2_N   	=> EXT_RAS2_N,
		EXT_ROM_N   	=> EXT_ROM_N,
		EXT_FDC_N   	=> EXT_FDC_N,
		
		PRG_A   			=> PRG_A_I,
		PRG_DI  			=> PRG_DI,
		PRG_DO  			=> PRG_DO_I,
		PRG_WRL_N  		=> PRG_WRL_N_I,
		PRG_WRH_N  		=> PRG_WRH_N_I,
		PRG_OE_N  		=> PRG_OE_N_I,
		PRG_RFS  		=> PRG_RFS_I,
		PRG_RDY  		=> PRG_RDY,

		PCM_A   			=> PCM_A_I,
		PCM_DI   		=> PCM_DI,
		PCM_WE_N   		=> PCM_WE_N_I,
		PCM_N   			=> PCM_N_I,
		
		ROM_DI   		=> ROM_DI,
		ROM_CE_N   		=> ROM_CE_N,
		ROM_RDY   		=> ROM_RDY,
		
		--PRAM_N  			=> PRAM_N,
		BRAM_N   		=> BRAM_N,
		--BROM_N   		=> BROM_N,
		CDC_N	  	 		=> CDC_N,
		COE_N	  	 		=> COE_N,
		CLWE_N   		=> CLWE_N,
		--CUWE_N   		=> CUWE_N,
		CDC_INT_N	   => CDC_INT_N,
		ERES_N   		=> ERES_N,
		
		CDC_HDI	   	=> CDC_HDO,
		CDC_HRD_N	   => CDC_HRD_N,
		CDC_DTEN_N	   => CDC_DTEN_N,
		CDC_WAIT_N	   => CDC_WAIT_N,
		
		CD_DI   			=> CDC_DATA,
		CD_SC_WR			=> CDC_SC_WR,
		
		CDD_STAT 		=> CDD_STAT,
		CDD_COMM 		=> CDD_COMM,
		CDD_SEND 		=> CDD_SEND,
		CDD_REC 			=> CDD_REC,
		CDD_DM 			=> CDD_DM,
		
		WORDRAM0_A   	=> WORDRAM0_A,
		WORDRAM0_DI   	=> WORDRAM0_DI,
		WORDRAM0_DO   	=> WORDRAM0_DO,
		WORDRAM0_WR   	=> WORDRAM0_WR,
		WORDRAM1_A    	=> WORDRAM1_A,
		WORDRAM1_DI   	=> WORDRAM1_DI,
		WORDRAM1_DO   	=> WORDRAM1_DO,
		WORDRAM1_WR   	=> WORDRAM1_WR,
		
		FD_DAT 			=> ASIC_FD_DAT,
		FD_WR 			=> ASIC_FD_WR,

		LED_RED   		=> LED_RED,
		LED_GREEN   	=> LED_GREEN,
		DEBUG_IDLE    => ASIC_DEBUG_IDLE,
		SS_REQ        => SAVESTATE_PAUSE and SAVESTATE_ASIC_REQ,
		SS_WR         => SAVESTATE_ASIC_WR,
		SS_ADDR       => SAVESTATE_ASIC_ADDR,
		SS_DIN        => SAVESTATE_ASIC_DIN,
		SS_DOUT       => SAVESTATE_ASIC_DOUT,
		SS_ACK        => SAVESTATE_ASIC_ACK
	);

	MCD_RST_N <= ERES_N;
	DEBUG_IDLE <= ASIC_DEBUG_IDLE;
	SAVESTATE_IDLE <= ASIC_DEBUG_IDLE;

	PRG_A <= PRG_A_I;
	PRG_DO <= PRG_DO_I;
	PRG_WRL_N <= '1' when PAUSE_ACTIVE = '1' else PRG_WRL_N_I;
	PRG_WRH_N <= '1' when PAUSE_ACTIVE = '1' else PRG_WRH_N_I;
	PRG_OE_N <= '1' when PAUSE_ACTIVE = '1' else PRG_OE_N_I;
	PRG_RFS <= '0' when PAUSE_ACTIVE = '1' else PRG_RFS_I;

	PCM_A <= PCM_A_I;
	PCM_DO <= PCM_DO_I;
	PCM_WE_N <= '1' when PAUSE_ACTIVE = '1' else PCM_WE_N_I;
	PCM_N <= '1' when PAUSE_ACTIVE = '1' else PCM_N_I;

	BRAM_A <= S68K_A(13 downto 1);
	BRAM_DO <= S68K_DO(7 downto 0);
	BRAM_WE <= '0' when PAUSE_ACTIVE = '1' else not (CLWE_N or BRAM_N);

	WORDRAM0_ADDR_I <= SAVESTATE_RAM_ADDR(15 downto 0) when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0011" else
	                   DEBUG_WORD_ADDR when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '0' else WORDRAM0_A;
	WORDRAM0_DATA_I <= SAVESTATE_RAM_DIN when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0011" else
	                   DEBUG_WORD_DIN when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '0' else WORDRAM0_DO;
	WORDRAM0_WREN_I <= SAVESTATE_RAM_WR when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0011" else
	                   DEBUG_WORD_WE when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '0' else
	                   '0' when DEBUG_PAUSE = '1' else WORDRAM0_WR;

	WORDRAM1_ADDR_I <= SAVESTATE_RAM_ADDR(15 downto 0) when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0100" else
	                   DEBUG_WORD_ADDR when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '1' else WORDRAM1_A;
	WORDRAM1_DATA_I <= SAVESTATE_RAM_DIN when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0100" else
	                   DEBUG_WORD_DIN when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '1' else WORDRAM1_DO;
	WORDRAM1_WREN_I <= SAVESTATE_RAM_WR when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0100" else
	                   DEBUG_WORD_WE when DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' and DEBUG_WORD_BANK = '1' else
	                   '0' when DEBUG_PAUSE = '1' else WORDRAM1_WR;

	CDC_RAM_ADDR_B_I <= SAVESTATE_RAM_ADDR(12 downto 0) when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0101" else
	                    CDC_RAM_A_WR(13 downto 1);
	CDC_RAM_DO_I <= SAVESTATE_RAM_DIN when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0101" else
	                CDC_RAM_DO;
	CDC_RAM_WE_I <= SAVESTATE_RAM_WR when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0101" else
	                CDC_RAM_WE;

	PCM_RAM_ADDR_B_I <= SAVESTATE_RAM_ADDR(15 downto 0) when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0110" else
	                    PCM_RAM_ADDR_B;
	PCM_RAM_DO_B_I <= SAVESTATE_RAM_DIN(7 downto 0);
	PCM_RAM_WE_B_I <= SAVESTATE_RAM_WR when SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' and SAVESTATE_RAM_TARGET = "0110" else
	                    '0';


	WORDRAM0 : entity work.spram
	generic map(16,16)
	port map(
		clock		=> CLK,
		address	=> WORDRAM0_ADDR_I,
		data		=> WORDRAM0_DATA_I,
		wren		=> WORDRAM0_WREN_I,
		q			=> WORDRAM0_DI
	);

	WORDRAM1 : entity work.spram
	generic map(16,16)
	port map(
		clock		=> CLK,
		address	=> WORDRAM1_ADDR_I,
		data		=> WORDRAM1_DATA_I,
		wren		=> WORDRAM1_WREN_I,
		q			=> WORDRAM1_DI
	);

	process( RST_N, CLK )
	begin
		if RST_N = '0' then
			DEBUG_WORD_REQ_D <= '0';
			DEBUG_WORD_BANK_D <= '0';
			SAVESTATE_RAM_REQ_D <= '0';
			SAVESTATE_RAM_TARGET_D <= (others => '0');
		elsif rising_edge(CLK) then
			DEBUG_WORD_REQ_D <= DEBUG_PAUSE and DEBUG_WORD_REQ;
			if DEBUG_PAUSE = '1' and DEBUG_WORD_REQ = '1' then
				DEBUG_WORD_BANK_D <= DEBUG_WORD_BANK;
			end if;
			SAVESTATE_RAM_REQ_D <= SAVESTATE_PAUSE and SAVESTATE_RAM_REQ;
			if SAVESTATE_PAUSE = '1' and SAVESTATE_RAM_REQ = '1' then
				SAVESTATE_RAM_TARGET_D <= SAVESTATE_RAM_TARGET;
			end if;
		end if;
	end process;

	DEBUG_WORD_ACK <= DEBUG_WORD_REQ_D;
	DEBUG_WORD_DOUT <= WORDRAM1_DI when DEBUG_WORD_BANK_D = '1' else WORDRAM0_DI;
	SAVESTATE_RAM_ACK <= SAVESTATE_RAM_REQ_D;
	SAVESTATE_RAM_DOUT <= WORDRAM0_DI when SAVESTATE_RAM_TARGET_D = "0011" else
	                      WORDRAM1_DI when SAVESTATE_RAM_TARGET_D = "0100" else
	                      CDC_RAM_Q_B when SAVESTATE_RAM_TARGET_D = "0101" else
	                      x"00" & PCM_RAM_DI_B when SAVESTATE_RAM_TARGET_D = "0110" else
	                      (others => '0');
	
	
	CDC : entity work.CDC
	port map(
		CLK   		=> CLK,
		RESET_N     => ERES_N,
		ENABLE      => RUN_EN,
		
		CLKEN_P   	=> S68K_CE_R,
		CLKEN_N		=> S68K_CE_F,
		DI   			=> S68K_DO(7 downto 0),
		DO   			=> CDC_DO,
		CS_N   		=> CDC_N,
		RS   			=> S68K_A(1),
		RD_N   		=> COE_N,
		WR_N   		=> CLWE_N,
		INT_N   		=> CDC_INT_N,
		
		HDO   		=> CDC_HDO,
		HRD_N   		=> CDC_HRD_N,
		DTEN_N   	=> CDC_DTEN_N,
		WAIT_N   	=> CDC_WAIT_N,
		
		CD_DI   		=> CDC_DATA,
		CD_WR   		=> CDC_DAT_WR,

		RAM_A_WR   	=> CDC_RAM_A_WR,
		RAM_A_RD   	=> CDC_RAM_A_RD,
		RAM_DI   	=> CDC_RAM_DI,
		RAM_DO   	=> CDC_RAM_DO,
		RAM_WE   	=> CDC_RAM_WE,
		SS_REQ      => SAVESTATE_PAUSE and SAVESTATE_CDC_REQ,
		SS_WR       => SAVESTATE_CDC_WR,
		SS_ADDR     => SAVESTATE_CDC_ADDR,
		SS_DIN      => SAVESTATE_CDC_DIN,
		SS_DOUT     => SAVESTATE_CDC_DOUT,
		SS_ACK      => SAVESTATE_CDC_ACK
	);
	
	CDC_RAM : entity work.dpram_dif
	generic map(14,8,13,16)
	port map(
		clock			=> CLK,
		address_a	=> CDC_RAM_A_RD(13 downto 0),
		q_a			=> CDC_RAM_DI,

		address_b	=> CDC_RAM_ADDR_B_I,
		data_b		=> CDC_RAM_DO_I,
		wren_b		=> CDC_RAM_WE_I,
		q_b			=> CDC_RAM_Q_B
	);
	
	
	PCM : entity work.PCM
	port map(
		CLK   		=> CLK,
		RST_N       => ERES_N,
		ENABLE      => RUN_EN,
		PALSW			=> PALSW,
		
		CLKEN			=> S68K_CE_F,
		A   			=> PCM_A,--S68K_A(13 downto 1),
		DI   			=> PCM_DI,--S68K_DO(7 downto 0),
		DO   			=> PCM_DO,
		CS_N   		=> PCM_N,
		RD_N   		=> COE_N,
		WR_N   		=> PCM_WE_N,--CLWE_N,
		
		RAM_ADDR_A  => PCM_RAM_ADDR_A,
		RAM_DI_A   	=> PCM_RAM_DI_A,
		RAM_DO_A		=> PCM_RAM_DO_A,
		RAM_WE_A		=> PCM_RAM_WE_A,
		RAM_ADDR_B	=> PCM_RAM_ADDR_B,
		RAM_DI_B		=> PCM_RAM_DI_B,
		SS_REQ      => SAVESTATE_PAUSE and SAVESTATE_PCM_REQ,
		SS_WR       => SAVESTATE_PCM_WR,
		SS_ADDR     => SAVESTATE_PCM_ADDR,
		SS_DIN      => SAVESTATE_PCM_DIN,
		SS_DOUT     => SAVESTATE_PCM_DOUT,
		SS_ACK      => SAVESTATE_PCM_ACK,

		SL   			=> PCM_SL,
		SR   			=> PCM_SR
	);
	
	PCM_RAM : entity work.dpram
	generic map(16)
	port map(
		clock			=> CLK,
		address_a	=> PCM_RAM_ADDR_A,
		data_a		=> PCM_RAM_DO_A,
		wren_a		=> PCM_RAM_WE_A,
		q_a			=> PCM_RAM_DI_A,

		address_b	=> PCM_RAM_ADDR_B_I,
		data_b		=> PCM_RAM_DO_B_I,
		wren_b		=> PCM_RAM_WE_B_I,
		q_b			=> PCM_RAM_DI_B
	);
	
	CD_DAC : entity work.CD_DAC
	port map(
		CLK   		=> CLK,
		RST_N       => ERES_N,
		ENABLE      => RUN_EN,
		
		PALSW			=> PALSW,
		
		CD_DI   		=> CDC_DATA,
		CD_WR   		=> CDC_CDDA_WR,

		FD_DI   		=> ASIC_FD_DAT,
		FD_WR   		=> ASIC_FD_WR,
		SS_REQ      => SAVESTATE_PAUSE and SAVESTATE_CDDA_REQ,
		SS_WR       => SAVESTATE_CDDA_WR,
		SS_ADDR     => SAVESTATE_CDDA_ADDR,
		SS_DIN      => SAVESTATE_CDDA_DIN,
		SS_DOUT     => SAVESTATE_CDDA_DOUT,
		SS_ACK      => SAVESTATE_CDDA_ACK,

		WR_READY		=> CDDA_WR_READY,
		
		SL   			=> CDDA_SL,
		SR   			=> CDDA_SR
	);
	
	DBG_S68K_A <= S68K_A & "0";

end rtl;
