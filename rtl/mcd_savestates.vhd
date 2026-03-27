library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mcd_savestates is
	port(
		CLK              : in  std_logic;
		RST_N            : in  std_logic;
		SAVE_REQ         : in  std_logic;
		LOAD_REQ         : in  std_logic;
		SLOT             : in  std_logic_vector(1 downto 0);
		GEN_PAUSE_ACK    : in  std_logic;
		MCD_PAUSE_ACK    : in  std_logic;
		PAUSE_REQ        : out std_logic;
		BUSY             : out std_logic;
		VALID_SLOTS      : out std_logic_vector(3 downto 0);
		RAM_REQ          : out std_logic;
		RAM_WR           : out std_logic;
		RAM_TARGET       : out std_logic_vector(3 downto 0);
		RAM_ADDR         : out std_logic_vector(17 downto 0);
		RAM_DIN          : out std_logic_vector(15 downto 0);
		RAM_DOUT         : in  std_logic_vector(15 downto 0);
		RAM_ACK          : in  std_logic;
		Z80_REQ          : out std_logic;
		Z80_WR           : out std_logic;
		Z80_ADDR         : out std_logic_vector(2 downto 0);
		Z80_DIN          : out std_logic_vector(31 downto 0);
		Z80_DOUT         : in  std_logic_vector(31 downto 0);
		Z80_ACK          : in  std_logic;
		MAIN68K_REQ      : out std_logic;
		MAIN68K_WR       : out std_logic;
		MAIN68K_ADDR     : out std_logic_vector(5 downto 0);
		MAIN68K_DIN      : out std_logic_vector(31 downto 0);
		MAIN68K_DOUT     : in  std_logic_vector(31 downto 0);
		MAIN68K_ACK      : in  std_logic;
		SUB68K_REQ       : out std_logic;
		SUB68K_WR        : out std_logic;
		SUB68K_ADDR      : out std_logic_vector(5 downto 0);
		SUB68K_DIN       : out std_logic_vector(31 downto 0);
		SUB68K_DOUT      : in  std_logic_vector(31 downto 0);
		SUB68K_ACK       : in  std_logic;
		VDP_REQ          : out std_logic;
		VDP_WR           : out std_logic;
		VDP_ADDR         : out std_logic_vector(7 downto 0);
		VDP_DIN          : out std_logic_vector(15 downto 0);
		VDP_DOUT         : in  std_logic_vector(15 downto 0);
		VDP_ACK          : in  std_logic;
		PSG_REQ          : out std_logic;
		PSG_WR           : out std_logic;
		PSG_ADDR         : out std_logic_vector(2 downto 0);
		PSG_DIN          : out std_logic_vector(31 downto 0);
		PSG_DOUT         : in  std_logic_vector(31 downto 0);
		PSG_ACK          : in  std_logic;
		FM_REQ           : out std_logic;
		FM_WR            : out std_logic;
		FM_ADDR          : out std_logic_vector(6 downto 0);
		FM_DIN           : out std_logic_vector(31 downto 0);
		FM_DOUT          : in  std_logic_vector(31 downto 0);
		FM_ACK           : in  std_logic;
		CDC_REQ          : out std_logic;
		CDC_WR           : out std_logic;
		CDC_ADDR         : out std_logic_vector(3 downto 0);
		CDC_DIN          : out std_logic_vector(31 downto 0);
		CDC_DOUT         : in  std_logic_vector(31 downto 0);
		CDC_ACK          : in  std_logic;
		PCM_REQ          : out std_logic;
		PCM_WR           : out std_logic;
		PCM_ADDR         : out std_logic_vector(4 downto 0);
		PCM_DIN          : out std_logic_vector(31 downto 0);
		PCM_DOUT         : in  std_logic_vector(31 downto 0);
		PCM_ACK          : in  std_logic;
		CDDA_REQ         : out std_logic;
		CDDA_WR          : out std_logic;
		CDDA_ADDR        : out std_logic_vector(10 downto 0);
		CDDA_DIN         : out std_logic_vector(31 downto 0);
		CDDA_DOUT        : in  std_logic_vector(31 downto 0);
		CDDA_ACK         : in  std_logic;
		ASIC_REQ         : out std_logic;
		ASIC_WR          : out std_logic;
		ASIC_ADDR        : out std_logic_vector(5 downto 0);
		ASIC_DIN         : out std_logic_vector(31 downto 0);
		ASIC_DOUT        : in  std_logic_vector(31 downto 0);
		ASIC_ACK         : in  std_logic;
		TOP_REQ          : out std_logic;
		TOP_WR           : out std_logic;
		TOP_ADDR         : out std_logic_vector(3 downto 0);
		TOP_DIN          : out std_logic_vector(31 downto 0);
		TOP_DOUT         : in  std_logic_vector(31 downto 0);
		TOP_ACK          : in  std_logic;
		DDRAM_BUSY       : in  std_logic;
		DDRAM_DOUT       : in  std_logic_vector(63 downto 0);
		DDRAM_DOUT_READY : in  std_logic;
		DDRAM_BURSTCNT   : out std_logic_vector(7 downto 0);
		DDRAM_ADDR       : out std_logic_vector(28 downto 0);
		DDRAM_DIN        : out std_logic_vector(63 downto 0);
		DDRAM_BE         : out std_logic_vector(7 downto 0);
		DDRAM_RD         : out std_logic;
		DDRAM_WE         : out std_logic
	);
end mcd_savestates;

architecture rtl of mcd_savestates is

	constant SLOT_BASE_WORD    : integer := 16#07C00000#; -- 0x3E000000 / 8
	constant SLOT_STRIDE_WORDS : integer := 16#00040000#; -- 0x200000 / 8

	constant BLOCK_Z80      : integer := 0;
	constant BLOCK_MAIN68K  : integer := 1;
	constant BLOCK_SUB68K   : integer := 2;
	constant BLOCK_VDP      : integer := 3;
	constant BLOCK_CDC_STATE: integer := 4;
	constant BLOCK_PCM_STATE: integer := 5;
	constant BLOCK_CDDA_STATE: integer := 6;
	constant BLOCK_ASIC_STATE: integer := 7;
	constant BLOCK_Z80RAM   : integer := 8;
	constant BLOCK_BRAM     : integer := 9;
	constant BLOCK_WORDRAM0 : integer := 10;
	constant BLOCK_WORDRAM1 : integer := 11;
	constant BLOCK_CDC_RAM  : integer := 12;
	constant BLOCK_PCM_RAM  : integer := 13;
	constant BLOCK_GENRAM   : integer := 14;
	constant BLOCK_PRGRAM   : integer := 15;
	constant BLOCK_VRAM     : integer := 16;
	constant BLOCK_TOPCD    : integer := 17;
	constant BLOCK_PSG_STATE: integer := 18;
	constant BLOCK_FM_STATE : integer := 19;
	constant BLOCK_COUNT    : integer := 20;

	constant Z80_DWORDS      : integer := 8;
	constant M68K_DWORDS     : integer := 50;
	constant VDP_DWORDS      : integer := 76;
	constant PSG_STATE_DWORDS: integer := 4;
	constant FM_STATE_DWORDS : integer := 89;
	constant CDC_STATE_DWORDS: integer := 10;
	constant PCM_STATE_DWORDS: integer := 27;
	constant CDDA_STATE_DWORDS: integer := 1287;
	constant ASIC_STATE_DWORDS: integer := 54;
	constant Z80RAM_DWORDS   : integer := 2048;
	constant BRAM_DWORDS     : integer := 2048;
	constant WORDRAM_DWORDS  : integer := 32768;
	constant CDC_RAM_DWORDS  : integer := 4096;
	constant PCM_RAM_DWORDS  : integer := 16384;
	constant GENRAM_DWORDS   : integer := 16384;
	constant PRGRAM_DWORDS   : integer := 131072;
	constant VRAM_DWORDS     : integer := 16384;
	constant TOPCD_DWORDS    : integer := 4;
	constant TOTAL_DWORDS    : integer := Z80_DWORDS + M68K_DWORDS + M68K_DWORDS + VDP_DWORDS + PSG_STATE_DWORDS + CDC_STATE_DWORDS +
	                                       PCM_STATE_DWORDS + CDDA_STATE_DWORDS + ASIC_STATE_DWORDS +
	                                       Z80RAM_DWORDS + BRAM_DWORDS + WORDRAM_DWORDS + WORDRAM_DWORDS +
	                                       CDC_RAM_DWORDS + PCM_RAM_DWORDS + GENRAM_DWORDS + PRGRAM_DWORDS +
	                                       VRAM_DWORDS + TOPCD_DWORDS + FM_STATE_DWORDS;

	type state_t is (
		ST_SCAN_REQ,
		ST_SCAN_WAIT,
		ST_IDLE,
		ST_SAVE_WAIT_PAUSE,
		ST_SAVE_FETCH_REQ,
		ST_SAVE_FETCH_WAIT,
		ST_SAVE_HAVE_DWORD,
		ST_SAVE_DDR_REQ,
		ST_SAVE_DDR_WAIT,
		ST_SAVE_HEADER_REQ,
		ST_SAVE_HEADER_WAIT,
		ST_LOAD_HEADER_REQ,
		ST_LOAD_HEADER_WAIT,
		ST_LOAD_WAIT_PAUSE,
		ST_LOAD_DDR_REQ,
		ST_LOAD_DDR_WAIT,
		ST_LOAD_PREP,
		ST_LOAD_WRITE_REQ,
		ST_LOAD_WRITE_WAIT,
		ST_LOAD_AFTER_DWORD,
		ST_LOAD_COMMIT_REQ,
		ST_LOAD_COMMIT_WAIT
	);

	function slot_base(slot_idx : integer) return integer is
	begin
		return SLOT_BASE_WORD + (slot_idx * SLOT_STRIDE_WORDS);
	end function;

	function block_dwords(block_idx : integer) return integer is
	begin
		case block_idx is
			when BLOCK_Z80      => return Z80_DWORDS;
			when BLOCK_MAIN68K  => return M68K_DWORDS;
			when BLOCK_SUB68K   => return M68K_DWORDS;
			when BLOCK_VDP      => return VDP_DWORDS;
			when BLOCK_PSG_STATE=> return PSG_STATE_DWORDS;
			when BLOCK_FM_STATE => return FM_STATE_DWORDS;
			when BLOCK_CDC_STATE=> return CDC_STATE_DWORDS;
			when BLOCK_PCM_STATE=> return PCM_STATE_DWORDS;
			when BLOCK_CDDA_STATE=> return CDDA_STATE_DWORDS;
			when BLOCK_ASIC_STATE=> return ASIC_STATE_DWORDS;
			when BLOCK_Z80RAM   => return Z80RAM_DWORDS;
			when BLOCK_BRAM     => return BRAM_DWORDS;
			when BLOCK_WORDRAM0 => return WORDRAM_DWORDS;
			when BLOCK_WORDRAM1 => return WORDRAM_DWORDS;
			when BLOCK_CDC_RAM  => return CDC_RAM_DWORDS;
			when BLOCK_PCM_RAM  => return PCM_RAM_DWORDS;
			when BLOCK_GENRAM   => return GENRAM_DWORDS;
			when BLOCK_PRGRAM   => return PRGRAM_DWORDS;
			when BLOCK_VRAM     => return VRAM_DWORDS;
			when BLOCK_TOPCD    => return TOPCD_DWORDS;
			when others         => return 0;
		end case;
	end function;

	function block_has_commit(block_idx : integer) return boolean is
	begin
		return (block_idx = BLOCK_Z80) or (block_idx = BLOCK_MAIN68K) or
		       (block_idx = BLOCK_SUB68K) or (block_idx = BLOCK_PSG_STATE) or
		       (block_idx = BLOCK_FM_STATE) or
		       (block_idx = BLOCK_CDC_STATE) or
		       (block_idx = BLOCK_PCM_STATE) or (block_idx = BLOCK_ASIC_STATE);
	end function;

	function block_is_word32(block_idx : integer) return boolean is
	begin
		return (block_idx = BLOCK_Z80) or (block_idx = BLOCK_MAIN68K) or
		       (block_idx = BLOCK_SUB68K) or (block_idx = BLOCK_CDC_STATE) or
		       (block_idx = BLOCK_PCM_STATE) or (block_idx = BLOCK_CDDA_STATE) or
		       (block_idx = BLOCK_PSG_STATE) or
		       (block_idx = BLOCK_FM_STATE) or
		       (block_idx = BLOCK_ASIC_STATE) or
		       (block_idx = BLOCK_TOPCD);
	end function;

	function block_is_word16(block_idx : integer) return boolean is
	begin
		return (block_idx = BLOCK_VDP) or (block_idx = BLOCK_BRAM) or
		       (block_idx = BLOCK_WORDRAM0) or (block_idx = BLOCK_WORDRAM1) or
		       (block_idx = BLOCK_CDC_RAM) or (block_idx = BLOCK_GENRAM) or
		       (block_idx = BLOCK_PRGRAM) or (block_idx = BLOCK_VRAM);
	end function;

	function block_is_byte_ram(block_idx : integer) return boolean is
	begin
		return (block_idx = BLOCK_Z80RAM) or (block_idx = BLOCK_PCM_RAM);
	end function;

	subtype ram_target_t is std_logic_vector(3 downto 0);

	function block_ram_target(block_idx : integer) return ram_target_t is
	begin
		case block_idx is
			when BLOCK_Z80RAM   => return "0001";
			when BLOCK_BRAM     => return "0010";
			when BLOCK_WORDRAM0 => return "0011";
			when BLOCK_WORDRAM1 => return "0100";
			when BLOCK_CDC_RAM  => return "0101";
			when BLOCK_PCM_RAM  => return "0110";
			when BLOCK_GENRAM   => return "0111";
			when BLOCK_PRGRAM   => return "1000";
			when BLOCK_VRAM     => return "1001";
			when others         => return "0000";
		end case;
	end function;

	signal state             : state_t := ST_SCAN_REQ;
	signal pause_req_r       : std_logic := '0';
	signal valid_slots_r     : std_logic_vector(3 downto 0) := (others => '0');
	signal change_counter    : unsigned(31 downto 0) := x"00000001";
	signal selected_slot     : integer range 0 to 3 := 0;
	signal scan_slot         : integer range 0 to 3 := 0;
	signal block_idx         : integer range 0 to BLOCK_COUNT := 0;
	signal block_dword_idx   : integer range 0 to PRGRAM_DWORDS := 0;
	signal slot_word_cursor  : integer range 0 to (TOTAL_DWORDS / 2) := 0;
	signal piece_idx         : integer range 0 to 3 := 0;
	signal pair_low_valid    : std_logic := '0';
	signal pair_high_phase   : std_logic := '0';
	signal pair_buffer       : std_logic_vector(63 downto 0) := (others => '0');
	signal payload_dword     : std_logic_vector(31 downto 0) := (others => '0');
	signal load_dword        : std_logic_vector(31 downto 0) := (others => '0');
	signal z80_ctrl_shadow   : std_logic_vector(31 downto 0) := (others => '0');
	signal load_size_words   : unsigned(31 downto 0) := (others => '0');

	signal ram_req_r         : std_logic := '0';
	signal ram_wr_r          : std_logic := '0';
	signal ram_target_r      : std_logic_vector(3 downto 0) := (others => '0');
	signal ram_addr_r        : std_logic_vector(17 downto 0) := (others => '0');
	signal ram_din_r         : std_logic_vector(15 downto 0) := (others => '0');
	signal z80_req_r         : std_logic := '0';
	signal z80_wr_r          : std_logic := '0';
	signal z80_addr_r        : std_logic_vector(2 downto 0) := (others => '0');
	signal z80_din_r         : std_logic_vector(31 downto 0) := (others => '0');
	signal main68k_req_r     : std_logic := '0';
	signal main68k_wr_r      : std_logic := '0';
	signal main68k_addr_r    : std_logic_vector(5 downto 0) := (others => '0');
	signal main68k_din_r     : std_logic_vector(31 downto 0) := (others => '0');
	signal sub68k_req_r      : std_logic := '0';
	signal sub68k_wr_r       : std_logic := '0';
	signal sub68k_addr_r     : std_logic_vector(5 downto 0) := (others => '0');
	signal sub68k_din_r      : std_logic_vector(31 downto 0) := (others => '0');
	signal vdp_req_r         : std_logic := '0';
	signal vdp_wr_r          : std_logic := '0';
	signal vdp_addr_r        : std_logic_vector(7 downto 0) := (others => '0');
	signal vdp_din_r         : std_logic_vector(15 downto 0) := (others => '0');
	signal psg_req_r         : std_logic := '0';
	signal psg_wr_r          : std_logic := '0';
	signal psg_addr_r        : std_logic_vector(2 downto 0) := (others => '0');
	signal psg_din_r         : std_logic_vector(31 downto 0) := (others => '0');
	signal fm_req_r          : std_logic := '0';
	signal fm_wr_r           : std_logic := '0';
	signal fm_addr_r         : std_logic_vector(6 downto 0) := (others => '0');
	signal fm_din_r          : std_logic_vector(31 downto 0) := (others => '0');
	signal cdc_req_r         : std_logic := '0';
	signal cdc_wr_r          : std_logic := '0';
	signal cdc_addr_r        : std_logic_vector(3 downto 0) := (others => '0');
	signal cdc_din_r         : std_logic_vector(31 downto 0) := (others => '0');
	signal pcm_req_r         : std_logic := '0';
	signal pcm_wr_r          : std_logic := '0';
	signal pcm_addr_r        : std_logic_vector(4 downto 0) := (others => '0');
	signal pcm_din_r         : std_logic_vector(31 downto 0) := (others => '0');
	signal cdda_req_r        : std_logic := '0';
	signal cdda_wr_r         : std_logic := '0';
	signal cdda_addr_r       : std_logic_vector(10 downto 0) := (others => '0');
	signal cdda_din_r        : std_logic_vector(31 downto 0) := (others => '0');
	signal asic_req_r        : std_logic := '0';
	signal asic_wr_r         : std_logic := '0';
	signal asic_addr_r       : std_logic_vector(5 downto 0) := (others => '0');
	signal asic_din_r        : std_logic_vector(31 downto 0) := (others => '0');
	signal top_req_r         : std_logic := '0';
	signal top_wr_r          : std_logic := '0';
	signal top_addr_r        : std_logic_vector(3 downto 0) := (others => '0');
	signal top_din_r         : std_logic_vector(31 downto 0) := (others => '0');
	signal ddram_addr_r      : std_logic_vector(28 downto 0) := (others => '0');
	signal ddram_din_r       : std_logic_vector(63 downto 0) := (others => '0');
	signal ddram_rd_r        : std_logic := '0';
	signal ddram_we_r        : std_logic := '0';
	signal ddram_be_r        : std_logic_vector(7 downto 0) := x"FF";
	signal ddram_burstcnt_r  : std_logic_vector(7 downto 0) := x"01";

begin

	PAUSE_REQ <= pause_req_r;
	BUSY <= '0' when state = ST_IDLE else '1';
	VALID_SLOTS <= valid_slots_r;
	RAM_REQ <= ram_req_r;
	RAM_WR <= ram_wr_r;
	RAM_TARGET <= ram_target_r;
	RAM_ADDR <= ram_addr_r;
	RAM_DIN <= ram_din_r;
	Z80_REQ <= z80_req_r;
	Z80_WR <= z80_wr_r;
	Z80_ADDR <= z80_addr_r;
	Z80_DIN <= z80_din_r;
	MAIN68K_REQ <= main68k_req_r;
	MAIN68K_WR <= main68k_wr_r;
	MAIN68K_ADDR <= main68k_addr_r;
	MAIN68K_DIN <= main68k_din_r;
	SUB68K_REQ <= sub68k_req_r;
	SUB68K_WR <= sub68k_wr_r;
	SUB68K_ADDR <= sub68k_addr_r;
	SUB68K_DIN <= sub68k_din_r;
	VDP_REQ <= vdp_req_r;
	VDP_WR <= vdp_wr_r;
	VDP_ADDR <= vdp_addr_r;
	VDP_DIN <= vdp_din_r;
	PSG_REQ <= psg_req_r;
	PSG_WR <= psg_wr_r;
	PSG_ADDR <= psg_addr_r;
	PSG_DIN <= psg_din_r;
	FM_REQ <= fm_req_r;
	FM_WR <= fm_wr_r;
	FM_ADDR <= fm_addr_r;
	FM_DIN <= fm_din_r;
	CDC_REQ <= cdc_req_r;
	CDC_WR <= cdc_wr_r;
	CDC_ADDR <= cdc_addr_r;
	CDC_DIN <= cdc_din_r;
	PCM_REQ <= pcm_req_r;
	PCM_WR <= pcm_wr_r;
	PCM_ADDR <= pcm_addr_r;
	PCM_DIN <= pcm_din_r;
	CDDA_REQ <= cdda_req_r;
	CDDA_WR <= cdda_wr_r;
	CDDA_ADDR <= cdda_addr_r;
	CDDA_DIN <= cdda_din_r;
	ASIC_REQ <= asic_req_r;
	ASIC_WR <= asic_wr_r;
	ASIC_ADDR <= asic_addr_r;
	ASIC_DIN <= asic_din_r;
	TOP_REQ <= top_req_r;
	TOP_WR <= top_wr_r;
	TOP_ADDR <= top_addr_r;
	TOP_DIN <= top_din_r;
	DDRAM_ADDR <= ddram_addr_r;
	DDRAM_DIN <= ddram_din_r;
	DDRAM_RD <= ddram_rd_r;
	DDRAM_WE <= ddram_we_r;
	DDRAM_BE <= ddram_be_r;
	DDRAM_BURSTCNT <= ddram_burstcnt_r;

	process(CLK)
		variable slot_sel_v : integer range 0 to 3;
	begin
		if rising_edge(CLK) then
			ram_req_r <= '0';
			ram_wr_r <= '0';
			ram_target_r <= (others => '0');
			ram_addr_r <= (others => '0');
			ram_din_r <= (others => '0');
			z80_req_r <= '0';
			z80_wr_r <= '0';
			z80_addr_r <= (others => '0');
			z80_din_r <= (others => '0');
			main68k_req_r <= '0';
			main68k_wr_r <= '0';
			main68k_addr_r <= (others => '0');
			main68k_din_r <= (others => '0');
			sub68k_req_r <= '0';
			sub68k_wr_r <= '0';
			sub68k_addr_r <= (others => '0');
			sub68k_din_r <= (others => '0');
			vdp_req_r <= '0';
			vdp_wr_r <= '0';
			vdp_addr_r <= (others => '0');
			vdp_din_r <= (others => '0');
			psg_req_r <= '0';
			psg_wr_r <= '0';
			psg_addr_r <= (others => '0');
			psg_din_r <= (others => '0');
			fm_req_r <= '0';
			fm_wr_r <= '0';
			fm_addr_r <= (others => '0');
			fm_din_r <= (others => '0');
			cdc_req_r <= '0';
			cdc_wr_r <= '0';
			cdc_addr_r <= (others => '0');
			cdc_din_r <= (others => '0');
			pcm_req_r <= '0';
			pcm_wr_r <= '0';
			pcm_addr_r <= (others => '0');
			pcm_din_r <= (others => '0');
			cdda_req_r <= '0';
			cdda_wr_r <= '0';
			cdda_addr_r <= (others => '0');
			cdda_din_r <= (others => '0');
			asic_req_r <= '0';
			asic_wr_r <= '0';
			asic_addr_r <= (others => '0');
			asic_din_r <= (others => '0');
			top_req_r <= '0';
			top_wr_r <= '0';
			top_addr_r <= (others => '0');
			top_din_r <= (others => '0');
			ddram_rd_r <= '0';
			ddram_we_r <= '0';
			ddram_be_r <= x"FF";
			ddram_burstcnt_r <= x"01";

			if RST_N = '0' then
				state <= ST_SCAN_REQ;
				pause_req_r <= '0';
				valid_slots_r <= (others => '0');
				change_counter <= x"00000001";
				selected_slot <= 0;
				scan_slot <= 0;
				block_idx <= 0;
				block_dword_idx <= 0;
				slot_word_cursor <= 0;
				piece_idx <= 0;
				pair_low_valid <= '0';
				pair_high_phase <= '0';
				pair_buffer <= (others => '0');
				payload_dword <= (others => '0');
				load_dword <= (others => '0');
				z80_ctrl_shadow <= (others => '0');
				load_size_words <= (others => '0');
			else
				case state is
					when ST_SCAN_REQ =>
						ddram_addr_r <= std_logic_vector(to_unsigned(slot_base(scan_slot), 29));
						ddram_rd_r <= '1';
						state <= ST_SCAN_WAIT;

					when ST_SCAN_WAIT =>
						if DDRAM_DOUT_READY = '1' then
							if DDRAM_DOUT(63 downto 32) /= x"00000000" then
								valid_slots_r(scan_slot) <= '1';
							else
								valid_slots_r(scan_slot) <= '0';
							end if;
							if scan_slot = 3 then
								state <= ST_IDLE;
							else
								scan_slot <= scan_slot + 1;
								state <= ST_SCAN_REQ;
							end if;
						end if;

					when ST_IDLE =>
						pause_req_r <= '0';
						pair_low_valid <= '0';
						pair_high_phase <= '0';
						piece_idx <= 0;
						slot_sel_v := to_integer(unsigned(SLOT));
						if SAVE_REQ = '1' then
							selected_slot <= slot_sel_v;
							block_idx <= 0;
							block_dword_idx <= 0;
							slot_word_cursor <= 0;
							pair_buffer <= (others => '0');
							pair_low_valid <= '0';
							piece_idx <= 0;
							pause_req_r <= '1';
							state <= ST_SAVE_WAIT_PAUSE;
						elsif LOAD_REQ = '1' and valid_slots_r(slot_sel_v) = '1' then
							selected_slot <= slot_sel_v;
							pause_req_r <= '0';
							state <= ST_LOAD_HEADER_REQ;
						end if;

					when ST_SAVE_WAIT_PAUSE =>
						pause_req_r <= '1';
						if GEN_PAUSE_ACK = '1' and MCD_PAUSE_ACK = '1' then
							block_idx <= 0;
							block_dword_idx <= 0;
							slot_word_cursor <= 0;
							pair_low_valid <= '0';
							piece_idx <= 0;
							state <= ST_SAVE_FETCH_REQ;
						end if;

					when ST_SAVE_FETCH_REQ =>
						if block_is_word32(block_idx) then
							if block_idx = BLOCK_Z80 then
								z80_req_r <= '1';
								z80_wr_r <= '0';
								z80_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 3));
							elsif block_idx = BLOCK_MAIN68K then
								main68k_req_r <= '1';
								main68k_wr_r <= '0';
								main68k_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
							elsif block_idx = BLOCK_SUB68K then
								sub68k_req_r <= '1';
								sub68k_wr_r <= '0';
								sub68k_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
							elsif block_idx = BLOCK_PSG_STATE then
								psg_req_r <= '1';
								psg_wr_r <= '0';
								psg_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 3));
							elsif block_idx = BLOCK_FM_STATE then
								fm_req_r <= '1';
								fm_wr_r <= '0';
								fm_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 7));
							elsif block_idx = BLOCK_CDC_STATE then
								cdc_req_r <= '1';
								cdc_wr_r <= '0';
								cdc_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 4));
							elsif block_idx = BLOCK_PCM_STATE then
								pcm_req_r <= '1';
								pcm_wr_r <= '0';
								pcm_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 5));
							elsif block_idx = BLOCK_ASIC_STATE then
								asic_req_r <= '1';
								asic_wr_r <= '0';
								asic_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
							elsif block_idx = BLOCK_CDDA_STATE then
								cdda_req_r <= '1';
								cdda_wr_r <= '0';
								cdda_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 11));
							else
								top_req_r <= '1';
								top_wr_r <= '0';
								top_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 4));
							end if;
						elsif block_idx = BLOCK_VDP then
							vdp_req_r <= '1';
							vdp_wr_r <= '0';
							vdp_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 2) + piece_idx, 8));
						elsif block_is_byte_ram(block_idx) then
							ram_req_r <= '1';
							ram_wr_r <= '0';
							ram_target_r <= block_ram_target(block_idx);
							ram_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 4) + piece_idx, 18));
						else
							ram_req_r <= '1';
							ram_wr_r <= '0';
							ram_target_r <= block_ram_target(block_idx);
							ram_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 2) + piece_idx, 18));
						end if;
						state <= ST_SAVE_FETCH_WAIT;

					when ST_SAVE_FETCH_WAIT =>
						if block_idx = BLOCK_Z80 and Z80_ACK = '1' then
							payload_dword <= Z80_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_MAIN68K and MAIN68K_ACK = '1' then
							payload_dword <= MAIN68K_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_SUB68K and SUB68K_ACK = '1' then
							payload_dword <= SUB68K_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_PSG_STATE and PSG_ACK = '1' then
							payload_dword <= PSG_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_FM_STATE and FM_ACK = '1' then
							payload_dword <= FM_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_CDC_STATE and CDC_ACK = '1' then
							payload_dword <= CDC_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_PCM_STATE and PCM_ACK = '1' then
							payload_dword <= PCM_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_ASIC_STATE and ASIC_ACK = '1' then
							payload_dword <= ASIC_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_CDDA_STATE and CDDA_ACK = '1' then
							payload_dword <= CDDA_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_TOPCD and TOP_ACK = '1' then
							payload_dword <= TOP_DOUT;
							state <= ST_SAVE_HAVE_DWORD;
						elsif block_idx = BLOCK_VDP and VDP_ACK = '1' then
							if piece_idx = 0 then
								payload_dword(15 downto 0) <= VDP_DOUT;
								piece_idx <= 1;
								state <= ST_SAVE_FETCH_REQ;
							else
								payload_dword(31 downto 16) <= VDP_DOUT;
								piece_idx <= 0;
								state <= ST_SAVE_HAVE_DWORD;
							end if;
						elsif (block_is_byte_ram(block_idx) or block_is_word16(block_idx)) and RAM_ACK = '1' then
							if block_is_byte_ram(block_idx) then
								if piece_idx = 0 then
									payload_dword(7 downto 0) <= RAM_DOUT(7 downto 0);
									piece_idx <= 1;
									state <= ST_SAVE_FETCH_REQ;
								elsif piece_idx = 1 then
									payload_dword(15 downto 8) <= RAM_DOUT(7 downto 0);
									piece_idx <= 2;
									state <= ST_SAVE_FETCH_REQ;
								elsif piece_idx = 2 then
									payload_dword(23 downto 16) <= RAM_DOUT(7 downto 0);
									piece_idx <= 3;
									state <= ST_SAVE_FETCH_REQ;
								else
									payload_dword(31 downto 24) <= RAM_DOUT(7 downto 0);
									piece_idx <= 0;
									state <= ST_SAVE_HAVE_DWORD;
								end if;
							else
								if piece_idx = 0 then
									payload_dword(15 downto 0) <= RAM_DOUT;
									piece_idx <= 1;
									state <= ST_SAVE_FETCH_REQ;
								else
									payload_dword(31 downto 16) <= RAM_DOUT;
									piece_idx <= 0;
									state <= ST_SAVE_HAVE_DWORD;
								end if;
							end if;
						end if;

					when ST_SAVE_HAVE_DWORD =>
						if pair_low_valid = '0' then
							pair_buffer(31 downto 0) <= payload_dword;
							pair_low_valid <= '1';
							if (block_dword_idx + 1) < block_dwords(block_idx) then
								block_dword_idx <= block_dword_idx + 1;
								state <= ST_SAVE_FETCH_REQ;
							else
								pair_buffer(63 downto 32) <= (others => '0');
								pair_low_valid <= '0';
								state <= ST_SAVE_DDR_REQ;
							end if;
						else
							pair_buffer(63 downto 32) <= payload_dword;
							pair_low_valid <= '0';
							state <= ST_SAVE_DDR_REQ;
						end if;

					when ST_SAVE_DDR_REQ =>
						ddram_addr_r <= std_logic_vector(to_unsigned(slot_base(selected_slot) + 1 + slot_word_cursor, 29));
						ddram_din_r <= pair_buffer;
						ddram_we_r <= '1';
						state <= ST_SAVE_DDR_WAIT;

					when ST_SAVE_DDR_WAIT =>
						if DDRAM_BUSY = '0' then
							slot_word_cursor <= slot_word_cursor + 1;
							if (block_dword_idx + 1) < block_dwords(block_idx) then
								block_dword_idx <= block_dword_idx + 1;
								state <= ST_SAVE_FETCH_REQ;
							elsif (block_idx + 1) < BLOCK_COUNT then
								block_idx <= block_idx + 1;
								block_dword_idx <= 0;
								state <= ST_SAVE_FETCH_REQ;
							else
								state <= ST_SAVE_HEADER_REQ;
							end if;
						end if;

					when ST_SAVE_HEADER_REQ =>
						ddram_addr_r <= std_logic_vector(to_unsigned(slot_base(selected_slot), 29));
						ddram_din_r <= std_logic_vector(to_unsigned(TOTAL_DWORDS, 32)) & std_logic_vector(change_counter);
						ddram_we_r <= '1';
						state <= ST_SAVE_HEADER_WAIT;

					when ST_SAVE_HEADER_WAIT =>
						if DDRAM_BUSY = '0' then
							valid_slots_r(selected_slot) <= '1';
							change_counter <= change_counter + 1;
							pause_req_r <= '0';
							state <= ST_IDLE;
						end if;

					when ST_LOAD_HEADER_REQ =>
						ddram_addr_r <= std_logic_vector(to_unsigned(slot_base(selected_slot), 29));
						ddram_rd_r <= '1';
						state <= ST_LOAD_HEADER_WAIT;

					when ST_LOAD_HEADER_WAIT =>
						if DDRAM_DOUT_READY = '1' then
							load_size_words <= unsigned(DDRAM_DOUT(63 downto 32));
							if unsigned(DDRAM_DOUT(63 downto 32)) >= to_unsigned(TOTAL_DWORDS, 32) and
							   DDRAM_DOUT(63 downto 32) /= x"00000000" then
								block_idx <= 0;
								block_dword_idx <= 0;
								slot_word_cursor <= 0;
								piece_idx <= 0;
								pair_high_phase <= '0';
								pause_req_r <= '1';
								state <= ST_LOAD_WAIT_PAUSE;
							else
								pause_req_r <= '0';
								state <= ST_IDLE;
							end if;
						end if;

					when ST_LOAD_WAIT_PAUSE =>
						pause_req_r <= '1';
						if GEN_PAUSE_ACK = '1' and MCD_PAUSE_ACK = '1' then
							state <= ST_LOAD_DDR_REQ;
						end if;

					when ST_LOAD_DDR_REQ =>
						ddram_addr_r <= std_logic_vector(to_unsigned(slot_base(selected_slot) + 1 + slot_word_cursor, 29));
						ddram_rd_r <= '1';
						state <= ST_LOAD_DDR_WAIT;

					when ST_LOAD_DDR_WAIT =>
						if DDRAM_DOUT_READY = '1' then
							pair_buffer <= DDRAM_DOUT;
							load_dword <= DDRAM_DOUT(31 downto 0);
							pair_high_phase <= '0';
							piece_idx <= 0;
							state <= ST_LOAD_PREP;
						end if;

					when ST_LOAD_PREP =>
						if block_idx = BLOCK_Z80 and block_dword_idx = 0 then
							z80_ctrl_shadow <= load_dword;
							state <= ST_LOAD_AFTER_DWORD;
						else
							piece_idx <= 0;
							state <= ST_LOAD_WRITE_REQ;
						end if;

					when ST_LOAD_WRITE_REQ =>
						if block_is_word32(block_idx) then
							if block_idx = BLOCK_Z80 then
								z80_req_r <= '1';
								z80_wr_r <= '1';
								z80_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 3));
								z80_din_r <= load_dword;
							elsif block_idx = BLOCK_MAIN68K then
								main68k_req_r <= '1';
								main68k_wr_r <= '1';
								main68k_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
								main68k_din_r <= load_dword;
							elsif block_idx = BLOCK_SUB68K then
								sub68k_req_r <= '1';
								sub68k_wr_r <= '1';
								sub68k_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
								sub68k_din_r <= load_dword;
							elsif block_idx = BLOCK_PSG_STATE then
								psg_req_r <= '1';
								psg_wr_r <= '1';
								psg_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 3));
								psg_din_r <= load_dword;
							elsif block_idx = BLOCK_FM_STATE then
								fm_req_r <= '1';
								fm_wr_r <= '1';
								fm_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 7));
								fm_din_r <= load_dword;
							elsif block_idx = BLOCK_CDC_STATE then
								cdc_req_r <= '1';
								cdc_wr_r <= '1';
								cdc_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 4));
								cdc_din_r <= load_dword;
							elsif block_idx = BLOCK_PCM_STATE then
								pcm_req_r <= '1';
								pcm_wr_r <= '1';
								pcm_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 5));
								pcm_din_r <= load_dword;
							elsif block_idx = BLOCK_ASIC_STATE then
								asic_req_r <= '1';
								asic_wr_r <= '1';
								asic_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 6));
								asic_din_r <= load_dword;
							elsif block_idx = BLOCK_CDDA_STATE then
								cdda_req_r <= '1';
								cdda_wr_r <= '1';
								cdda_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 11));
								cdda_din_r <= load_dword;
							else
								top_req_r <= '1';
								top_wr_r <= '1';
								top_addr_r <= std_logic_vector(to_unsigned(block_dword_idx, 4));
								top_din_r <= load_dword;
							end if;
						elsif block_idx = BLOCK_VDP then
							vdp_req_r <= '1';
							vdp_wr_r <= '1';
							vdp_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 2) + piece_idx, 8));
							if piece_idx = 0 then
								vdp_din_r <= load_dword(15 downto 0);
							else
								vdp_din_r <= load_dword(31 downto 16);
							end if;
						elsif block_is_byte_ram(block_idx) then
							ram_req_r <= '1';
							ram_wr_r <= '1';
							ram_target_r <= block_ram_target(block_idx);
							ram_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 4) + piece_idx, 18));
							case piece_idx is
								when 0 => ram_din_r <= x"00" & load_dword(7 downto 0);
								when 1 => ram_din_r <= x"00" & load_dword(15 downto 8);
								when 2 => ram_din_r <= x"00" & load_dword(23 downto 16);
								when others => ram_din_r <= x"00" & load_dword(31 downto 24);
							end case;
						else
							ram_req_r <= '1';
							ram_wr_r <= '1';
							ram_target_r <= block_ram_target(block_idx);
							ram_addr_r <= std_logic_vector(to_unsigned((block_dword_idx * 2) + piece_idx, 18));
							if piece_idx = 0 then
								ram_din_r <= load_dword(15 downto 0);
							else
								ram_din_r <= load_dword(31 downto 16);
							end if;
						end if;
						state <= ST_LOAD_WRITE_WAIT;

					when ST_LOAD_WRITE_WAIT =>
						if block_idx = BLOCK_Z80 and Z80_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_MAIN68K and MAIN68K_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_SUB68K and SUB68K_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_PSG_STATE and PSG_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_FM_STATE and FM_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_CDC_STATE and CDC_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_PCM_STATE and PCM_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_ASIC_STATE and ASIC_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_CDDA_STATE and CDDA_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_TOPCD and TOP_ACK = '1' then
							state <= ST_LOAD_AFTER_DWORD;
						elsif block_idx = BLOCK_VDP and VDP_ACK = '1' then
							if piece_idx = 0 then
								piece_idx <= 1;
								state <= ST_LOAD_WRITE_REQ;
							else
								piece_idx <= 0;
								state <= ST_LOAD_AFTER_DWORD;
							end if;
						elsif (block_is_byte_ram(block_idx) or block_is_word16(block_idx)) and RAM_ACK = '1' then
							if block_is_byte_ram(block_idx) then
								if piece_idx < 3 then
									piece_idx <= piece_idx + 1;
									state <= ST_LOAD_WRITE_REQ;
								else
									piece_idx <= 0;
									state <= ST_LOAD_AFTER_DWORD;
								end if;
							else
								if piece_idx = 0 then
									piece_idx <= 1;
									state <= ST_LOAD_WRITE_REQ;
								else
									piece_idx <= 0;
									state <= ST_LOAD_AFTER_DWORD;
								end if;
							end if;
						end if;

					when ST_LOAD_AFTER_DWORD =>
						if (block_dword_idx + 1) < block_dwords(block_idx) then
							block_dword_idx <= block_dword_idx + 1;
							if pair_high_phase = '0' then
								pair_high_phase <= '1';
								load_dword <= pair_buffer(63 downto 32);
								state <= ST_LOAD_PREP;
							else
								pair_high_phase <= '0';
								slot_word_cursor <= slot_word_cursor + 1;
								state <= ST_LOAD_DDR_REQ;
							end if;
						else
							if pair_high_phase = '1' then
								slot_word_cursor <= slot_word_cursor + 1;
							end if;
							if block_has_commit(block_idx) then
								state <= ST_LOAD_COMMIT_REQ;
							elsif (block_idx + 1) < BLOCK_COUNT then
								block_idx <= block_idx + 1;
								block_dword_idx <= 0;
								pair_high_phase <= '0';
								state <= ST_LOAD_DDR_REQ;
							else
								pause_req_r <= '0';
								state <= ST_IDLE;
							end if;
						end if;

					when ST_LOAD_COMMIT_REQ =>
						if block_idx = BLOCK_Z80 then
							z80_req_r <= '1';
							z80_wr_r <= '1';
							z80_addr_r <= "000";
							z80_din_r <= z80_ctrl_shadow or x"80000000";
						elsif block_idx = BLOCK_MAIN68K then
							main68k_req_r <= '1';
							main68k_wr_r <= '1';
							main68k_addr_r <= "111111";
							main68k_din_r <= x"80000000";
						elsif block_idx = BLOCK_SUB68K then
							sub68k_req_r <= '1';
							sub68k_wr_r <= '1';
							sub68k_addr_r <= "111111";
							sub68k_din_r <= x"80000000";
						elsif block_idx = BLOCK_PSG_STATE then
							psg_req_r <= '1';
							psg_wr_r <= '1';
							psg_addr_r <= "111";
							psg_din_r <= x"80000000";
						elsif block_idx = BLOCK_FM_STATE then
							fm_req_r <= '1';
							fm_wr_r <= '1';
							fm_addr_r <= "1111111";
							fm_din_r <= x"80000000";
						elsif block_idx = BLOCK_CDC_STATE then
							cdc_req_r <= '1';
							cdc_wr_r <= '1';
							cdc_addr_r <= "1111";
							cdc_din_r <= x"80000000";
						elsif block_idx = BLOCK_PCM_STATE then
							pcm_req_r <= '1';
							pcm_wr_r <= '1';
							pcm_addr_r <= "11111";
							pcm_din_r <= x"80000000";
						elsif block_idx = BLOCK_ASIC_STATE then
							asic_req_r <= '1';
							asic_wr_r <= '1';
							asic_addr_r <= "111111";
							asic_din_r <= x"80000000";
						else
							null;
						end if;
						state <= ST_LOAD_COMMIT_WAIT;

					when ST_LOAD_COMMIT_WAIT =>
						if (block_idx = BLOCK_Z80 and Z80_ACK = '1') or
						   (block_idx = BLOCK_MAIN68K and MAIN68K_ACK = '1') or
						   (block_idx = BLOCK_SUB68K and SUB68K_ACK = '1') or
						   (block_idx = BLOCK_PSG_STATE and PSG_ACK = '1') or
						   (block_idx = BLOCK_FM_STATE and FM_ACK = '1') or
						   (block_idx = BLOCK_CDC_STATE and CDC_ACK = '1') or
						   (block_idx = BLOCK_PCM_STATE and PCM_ACK = '1') or
						   (block_idx = BLOCK_ASIC_STATE and ASIC_ACK = '1') then
							if (block_idx + 1) < BLOCK_COUNT then
								block_idx <= block_idx + 1;
								block_dword_idx <= 0;
								pair_high_phase <= '0';
								state <= ST_LOAD_DDR_REQ;
							else
								pause_req_r <= '0';
								state <= ST_IDLE;
							end if;
						end if;

				end case;
			end if;
		end if;
	end process;

end rtl;
