`include "mcd_debug_defs.vh"

module mcd_debug_bridge
(
	input             clk_sys,
	input             reset,

	input             dbg_reg_wr,
	input      [5:0]  dbg_reg_addr,
	input      [15:0] dbg_reg_wdata,
	output reg [15:0] dbg_reg_rdata,

	input             mcd_bank23,

	output            pause_req,
	input             gen_pause_ack,
	input             mcd_pause_ack,

	output            sdr_hold,

	output reg        sdr_req,
	output reg [24:1] sdr_addr,
	output reg        sdr_rd,
	output reg        sdr_wrl,
	output reg        sdr_wrh,
	output reg [15:0] sdr_din,
	input      [15:0] sdr_dout,
	input             sdr_busy,
	input             sdr_grant,

	output            bram_hold,

	output reg        bram_req,
	output reg        bram_we,
	output reg [11:0] bram_addr,
	output reg [15:0] bram_din,
	input      [15:0] bram_dout,
	input             bram_ack,
	input             bram_grant,

	output reg        word_req,
	output reg        word_we,
	output reg        word_bank,
	output reg [15:0] word_addr,
	output reg [15:0] word_din,
	input      [15:0] word_dout,
	input             word_ack
);

localparam ST_IDLE             = 5'd0;
localparam ST_WAIT_PAUSE       = 5'd1;
localparam ST_BYTE_DISPATCH    = 5'd2;
localparam ST_SDR_PULSE        = 5'd3;
localparam ST_SDR_WAIT_BUSY    = 5'd4;
localparam ST_SDR_WAIT_DONE    = 5'd5;
localparam ST_BRAM_READ_REQ    = 5'd6;
localparam ST_BRAM_READ_WAIT   = 5'd7;
localparam ST_BRAM_WRITE_REQ   = 5'd8;
localparam ST_BRAM_WRITE_WAIT  = 5'd9;
localparam ST_WORD_READ_REQ    = 5'd10;
localparam ST_WORD_READ_WAIT   = 5'd11;
localparam ST_WORD_WRITE_REQ   = 5'd12;
localparam ST_WORD_WRITE_WAIT  = 5'd13;
localparam ST_FINISH           = 5'd14;

reg [15:0] access_mode_active = `MCD_DBG_ACCESS_PAUSED;
reg [15:0] access_mode_staged = `MCD_DBG_ACCESS_PAUSED;
reg [7:0]  command_reg;
reg [7:0]  target_reg;
reg [31:0] addr_reg;
reg [31:0] length_reg;
reg [31:0] wdata_reg;
reg [15:0] exec_id_reg;
reg [15:0] active_exec_id;

reg [15:0] done_id_reg;
reg [15:0] error_reg;
reg [15:0] warning_reg;
reg        busy_reg;
reg        done_reg;
reg        error_flag_reg;
reg        warning_flag_reg;
reg        data_valid_reg;
reg        pause_hold_reg;

reg [4:0]  state;
reg [7:0]  op_cmd;
reg [7:0]  op_target;
reg [31:0] op_addr;
reg [31:0] op_length;
reg [31:0] op_wdata;
reg [31:0] op_index;
reg [7:0]  current_byte;
reg [15:0] scratch_word;
reg [15:0] data_window [0:15];
integer i;

wire paused = pause_hold_reg && gen_pause_ack && mcd_pause_ack;
wire pause_wait = pause_hold_reg && ~paused;

assign pause_req = pause_hold_reg;
assign sdr_hold = (state == ST_SDR_PULSE) || (state == ST_SDR_WAIT_BUSY) || (state == ST_SDR_WAIT_DONE);
assign bram_hold = (state == ST_BRAM_READ_REQ) || (state == ST_BRAM_READ_WAIT) ||
                   (state == ST_BRAM_WRITE_REQ) || (state == ST_BRAM_WRITE_WAIT);

function automatic [15:0] target_caps(input [7:0] target);
	begin
		case (target)
			`MCD_DBG_TARGET_MD68K_RAM:
				target_caps = `MCD_DBG_CAP_LIVE_READ | `MCD_DBG_CAP_PAUSED_READ |
				              `MCD_DBG_CAP_PAUSED_WRITE | `MCD_DBG_CAP_ARBITRATED;
			`MCD_DBG_TARGET_SUBCPU_RAM,
			`MCD_DBG_TARGET_PRGRAM:
				target_caps = `MCD_DBG_CAP_LIVE_READ | `MCD_DBG_CAP_PAUSED_READ |
				              `MCD_DBG_CAP_PAUSED_WRITE | `MCD_DBG_CAP_ARBITRATED;
			`MCD_DBG_TARGET_WORDRAM:
				target_caps = `MCD_DBG_CAP_PAUSED_READ | `MCD_DBG_CAP_PAUSED_WRITE |
				              `MCD_DBG_CAP_RAW_PHYSICAL;
			`MCD_DBG_TARGET_BACKUP_RAM:
				target_caps = `MCD_DBG_CAP_LIVE_READ | `MCD_DBG_CAP_PAUSED_READ |
				              `MCD_DBG_CAP_PAUSED_WRITE | `MCD_DBG_CAP_ARBITRATED;
			default:
				target_caps = 16'h0000;
		endcase
	end
endfunction

function automatic is_valid_access_mode(input [15:0] mode);
	begin
		is_valid_access_mode = (mode == `MCD_DBG_ACCESS_PAUSED) ||
		                       (mode == `MCD_DBG_ACCESS_LIVE);
	end
endfunction

function automatic [31:0] target_limit(input [7:0] target);
	begin
		case (target)
			`MCD_DBG_TARGET_MD68K_RAM:  target_limit = 32'h0001_0000;
			`MCD_DBG_TARGET_SUBCPU_RAM,
			`MCD_DBG_TARGET_PRGRAM:     target_limit = 32'h0008_0000;
			`MCD_DBG_TARGET_WORDRAM:    target_limit = 32'h0004_0000;
			`MCD_DBG_TARGET_BACKUP_RAM: target_limit = 32'h0000_2000;
			default:                    target_limit = 32'h0000_0000;
		endcase
	end
endfunction

function automatic target_valid(input [7:0] target);
	begin
		target_valid = |target_caps(target);
	end
endfunction

function automatic target_is_sdram(input [7:0] target);
	begin
		target_is_sdram = (target == `MCD_DBG_TARGET_MD68K_RAM) ||
		                  (target == `MCD_DBG_TARGET_SUBCPU_RAM) ||
		                  (target == `MCD_DBG_TARGET_PRGRAM);
	end
endfunction

function automatic target_is_wordram(input [7:0] target);
	begin
		target_is_wordram = (target == `MCD_DBG_TARGET_WORDRAM);
	end
endfunction

function automatic target_is_backup(input [7:0] target);
	begin
		target_is_backup = (target == `MCD_DBG_TARGET_BACKUP_RAM);
	end
endfunction

function automatic [24:1] sdram_phys_addr(input [7:0] target, input [31:0] byte_addr, input bank23);
	begin
		case (target)
			`MCD_DBG_TARGET_MD68K_RAM:
				sdram_phys_addr = {9'b010000000, byte_addr[15:1]};
			default:
				sdram_phys_addr = {(bank23 ? 6'b100000 : 6'b011111), byte_addr[18:1]};
		endcase
	end
endfunction

function automatic [7:0] get_write_byte(input [7:0] cmd, input [31:0] wdata, input [31:0] index);
	begin
		case (cmd)
			`MCD_DBG_CMD_WRITE8:
				get_write_byte = wdata[7:0];
			`MCD_DBG_CMD_WRITE16:
				get_write_byte = index[0] ? wdata[7:0] : wdata[15:8];
			default:
				case (index[1:0])
					2'd0: get_write_byte = wdata[31:24];
					2'd1: get_write_byte = wdata[23:16];
					2'd2: get_write_byte = wdata[15:8];
					default: get_write_byte = wdata[7:0];
				endcase
		endcase
	end
endfunction

function automatic [7:0] select_byte(input [7:0] target, input [15:0] word_value, input [31:0] byte_addr);
	begin
		if (target_is_backup(target))
			select_byte = byte_addr[0] ? word_value[15:8] : word_value[7:0];
		else
			select_byte = byte_addr[0] ? word_value[7:0] : word_value[15:8];
	end
endfunction

function automatic [15:0] merge_byte(input [7:0] target, input [15:0] word_value, input [31:0] byte_addr, input [7:0] byte_value);
	begin
		merge_byte = word_value;
		if (target_is_backup(target)) begin
			if (byte_addr[0]) merge_byte[15:8] = byte_value;
			else              merge_byte[7:0]  = byte_value;
		end else begin
			if (byte_addr[0]) merge_byte[7:0]  = byte_value;
			else              merge_byte[15:8] = byte_value;
		end
	end
endfunction

function automatic [15:0] pack_window_word(input [3:0] index);
	begin
		pack_window_word = data_window[index];
	end
endfunction

task automatic clear_data_window;
	begin
		for (i = 0; i < 16; i = i + 1) data_window[i] = 16'h0000;
	end
endtask

task automatic set_error(input [15:0] err_code);
	begin
		error_reg      <= err_code;
		error_flag_reg <= 1'b1;
		busy_reg       <= 1'b0;
		done_reg       <= 1'b1;
		state          <= ST_IDLE;
		done_id_reg    <= active_exec_id;
	end
endtask

task automatic finish_ok;
	begin
		busy_reg    <= 1'b0;
		done_reg    <= 1'b1;
		state       <= ST_IDLE;
		done_id_reg <= active_exec_id;
	end
endtask

always @(*) begin
	integer data_index;

	dbg_reg_rdata = 16'h0000;
	case (dbg_reg_addr)
		`MCD_DBG_REG_VERSION:     dbg_reg_rdata = `MCD_DBG_VERSION;
		`MCD_DBG_REG_STATUS:      dbg_reg_rdata = {8'h00,
		                                           1'b0,
		                                           data_valid_reg,
		                                           warning_flag_reg,
		                                           access_mode_active == `MCD_DBG_ACCESS_LIVE,
		                                           pause_wait,
		                                           paused,
		                                           error_flag_reg,
		                                           done_reg,
		                                           busy_reg};
		`MCD_DBG_REG_ERROR:       dbg_reg_rdata = error_reg;
		`MCD_DBG_REG_WARNING:     dbg_reg_rdata = warning_reg;
		`MCD_DBG_REG_ACCESS_MODE: dbg_reg_rdata = access_mode_active;
		`MCD_DBG_REG_COMMAND:     dbg_reg_rdata = {8'h00, command_reg};
		`MCD_DBG_REG_TARGET:      dbg_reg_rdata = {8'h00, target_reg};
		`MCD_DBG_REG_ADDR_LO:     dbg_reg_rdata = addr_reg[15:0];
		`MCD_DBG_REG_ADDR_HI:     dbg_reg_rdata = addr_reg[31:16];
		`MCD_DBG_REG_LENGTH_LO:   dbg_reg_rdata = length_reg[15:0];
		`MCD_DBG_REG_LENGTH_HI:   dbg_reg_rdata = length_reg[31:16];
		`MCD_DBG_REG_WDATA_LO:    dbg_reg_rdata = wdata_reg[15:0];
		`MCD_DBG_REG_WDATA_HI:    dbg_reg_rdata = wdata_reg[31:16];
		`MCD_DBG_REG_EXEC_ID:     dbg_reg_rdata = exec_id_reg;
		`MCD_DBG_REG_DONE_ID:     dbg_reg_rdata = done_id_reg;
		default: begin
			if (dbg_reg_addr >= `MCD_DBG_REG_DATA_BASE && dbg_reg_addr <= `MCD_DBG_REG_DATA_LAST) begin
				data_index = dbg_reg_addr - `MCD_DBG_REG_DATA_BASE;
				dbg_reg_rdata = pack_window_word(data_index[3:0]);
			end
		end
	endcase
end

always @(posedge clk_sys) begin
	reg [31:0] current_addr;

	current_addr = op_addr + op_index;

	sdr_req <= 1'b0;
	sdr_rd  <= 1'b0;
	sdr_wrl <= 1'b0;
	sdr_wrh <= 1'b0;
	bram_req <= 1'b0;
	word_req <= 1'b0;

	if (reset) begin
		access_mode_active <= `MCD_DBG_ACCESS_PAUSED;
		access_mode_staged <= `MCD_DBG_ACCESS_PAUSED;
		command_reg      <= `MCD_DBG_CMD_NONE;
		target_reg       <= 8'h00;
		addr_reg         <= 32'h0000_0000;
		length_reg       <= 32'h0000_0000;
		wdata_reg        <= 32'h0000_0000;
		exec_id_reg      <= 16'h0000;
		active_exec_id   <= 16'h0000;
		done_id_reg      <= 16'h0000;
		error_reg        <= `MCD_DBG_ERR_NONE;
		warning_reg      <= `MCD_DBG_WARN_NONE;
		busy_reg         <= 1'b0;
		done_reg         <= 1'b0;
		error_flag_reg   <= 1'b0;
		warning_flag_reg <= 1'b0;
		data_valid_reg   <= 1'b0;
		pause_hold_reg   <= 1'b0;
		state            <= ST_IDLE;
		op_cmd           <= `MCD_DBG_CMD_NONE;
		op_target        <= 8'h00;
		op_addr          <= 32'h0000_0000;
		op_length        <= 32'h0000_0000;
		op_wdata         <= 32'h0000_0000;
		op_index         <= 32'h0000_0000;
		current_byte     <= 8'h00;
		scratch_word     <= 16'h0000;
		sdr_addr         <= 24'h0;
		sdr_din          <= 16'h0000;
		bram_addr        <= 12'h000;
		bram_din         <= 16'h0000;
		bram_we          <= 1'b0;
		word_addr        <= 16'h0000;
		word_din         <= 16'h0000;
		word_we          <= 1'b0;
		word_bank        <= 1'b0;
		clear_data_window();
	end else begin
		if (dbg_reg_wr) begin
			case (dbg_reg_addr)
				`MCD_DBG_REG_ACCESS_MODE: access_mode_staged <= dbg_reg_wdata;
				`MCD_DBG_REG_COMMAND:     command_reg <= dbg_reg_wdata[7:0];
				`MCD_DBG_REG_TARGET:      target_reg <= dbg_reg_wdata[7:0];
				`MCD_DBG_REG_ADDR_LO:     addr_reg[15:0] <= dbg_reg_wdata;
				`MCD_DBG_REG_ADDR_HI:     addr_reg[31:16] <= dbg_reg_wdata;
				`MCD_DBG_REG_LENGTH_LO:   length_reg[15:0] <= dbg_reg_wdata;
				`MCD_DBG_REG_LENGTH_HI:   length_reg[31:16] <= dbg_reg_wdata;
				`MCD_DBG_REG_WDATA_LO:    wdata_reg[15:0] <= dbg_reg_wdata;
				`MCD_DBG_REG_WDATA_HI:    wdata_reg[31:16] <= dbg_reg_wdata;
				`MCD_DBG_REG_EXEC_ID:     exec_id_reg <= dbg_reg_wdata;
				default: ;
			endcase
		end

		case (state)
			ST_IDLE: begin
				if (done_reg && dbg_reg_wr && dbg_reg_addr == `MCD_DBG_REG_EXEC_ID)
					done_reg <= 1'b0;

				if (dbg_reg_wr && dbg_reg_addr == `MCD_DBG_REG_EXEC_ID && dbg_reg_wdata != done_id_reg && !busy_reg) begin
					active_exec_id    <= dbg_reg_wdata;
					op_cmd           <= command_reg;
					op_target        <= target_reg;
					op_addr          <= addr_reg;
					op_length        <= length_reg;
					op_wdata         <= wdata_reg;
					op_index         <= 32'h0000_0000;
					busy_reg         <= 1'b1;
					done_reg         <= 1'b0;
					error_flag_reg   <= 1'b0;
					error_reg        <= `MCD_DBG_ERR_NONE;
					warning_flag_reg <= 1'b0;
					warning_reg      <= `MCD_DBG_WARN_NONE;
					data_valid_reg   <= 1'b0;
					clear_data_window();

					case (command_reg)
						`MCD_DBG_CMD_PAUSE: begin
							pause_hold_reg <= 1'b1;
							if (paused) finish_ok();
							else state <= ST_WAIT_PAUSE;
						end

						`MCD_DBG_CMD_RESUME: begin
							pause_hold_reg <= 1'b0;
							finish_ok();
						end

						`MCD_DBG_CMD_SET_ACCESS_MODE: begin
							if (!is_valid_access_mode(access_mode_staged))
								set_error(`MCD_DBG_ERR_INVALID_MODE);
							else begin
								access_mode_active <= access_mode_staged;
								finish_ok();
							end
						end

						`MCD_DBG_CMD_GET_ACCESS_MODE: begin
							data_window[0] <= access_mode_active;
							data_valid_reg <= 1'b1;
							finish_ok();
						end

						`MCD_DBG_CMD_GET_TARGET_CAPS: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else begin
								data_window[0] <= target_caps(target_reg);
								data_valid_reg <= 1'b1;
								finish_ok();
							end
						end

						`MCD_DBG_CMD_READ8: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_READ))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_READ))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if (addr_reg >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd1;
								if (target_caps(target_reg) & `MCD_DBG_CAP_ARBITRATED) begin
									warning_reg <= `MCD_DBG_WARN_ARBITRATED_VALUE;
									warning_flag_reg <= 1'b1;
								end
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_READ16: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if (addr_reg[0]) set_error(`MCD_DBG_ERR_ALIGNMENT);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_READ))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_READ))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if ((addr_reg + 32'd1) >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd2;
								if (target_caps(target_reg) & `MCD_DBG_CAP_ARBITRATED) begin
									warning_reg <= `MCD_DBG_WARN_ARBITRATED_VALUE;
									warning_flag_reg <= 1'b1;
								end
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_READ32: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if (addr_reg[0]) set_error(`MCD_DBG_ERR_ALIGNMENT);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_READ))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_READ))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if ((addr_reg + 32'd3) >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd4;
								if (target_caps(target_reg) & `MCD_DBG_CAP_ARBITRATED) begin
									warning_reg <= `MCD_DBG_WARN_ARBITRATED_VALUE;
									warning_flag_reg <= 1'b1;
								end
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_WRITE8: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_WRITE))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_WRITE))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if (addr_reg >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd1;
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_WRITE16: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if (addr_reg[0]) set_error(`MCD_DBG_ERR_ALIGNMENT);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_WRITE))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_WRITE))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if ((addr_reg + 32'd1) >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd2;
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_WRITE32: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if (addr_reg[0]) set_error(`MCD_DBG_ERR_ALIGNMENT);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_WRITE))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_WRITE))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if ((addr_reg + 32'd3) >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= 32'd4;
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						`MCD_DBG_CMD_READ_BLOCK: begin
							if (!target_valid(target_reg)) set_error(`MCD_DBG_ERR_INVALID_TARGET);
							else if (!length_reg || (length_reg > 32))
								set_error(`MCD_DBG_ERR_LENGTH);
							else if ((access_mode_active == `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_LIVE_READ))
								set_error(`MCD_DBG_ERR_LIVE_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !(target_caps(target_reg) & `MCD_DBG_CAP_PAUSED_READ))
								set_error(`MCD_DBG_ERR_PAUSED_UNSUPPORTED);
							else if ((access_mode_active != `MCD_DBG_ACCESS_LIVE) && !paused)
								set_error(`MCD_DBG_ERR_NOT_PAUSED);
							else if ((addr_reg + length_reg - 1) >= target_limit(target_reg))
								set_error(`MCD_DBG_ERR_INVALID_ADDR);
							else begin
								op_length <= length_reg;
								if (target_caps(target_reg) & `MCD_DBG_CAP_ARBITRATED) begin
									warning_reg <= `MCD_DBG_WARN_ARBITRATED_VALUE;
									warning_flag_reg <= 1'b1;
								end
								if (target_caps(target_reg) & `MCD_DBG_CAP_RAW_PHYSICAL) begin
									warning_reg <= `MCD_DBG_WARN_RAW_PHYSICAL_MAPPING;
									warning_flag_reg <= 1'b1;
								end
								state <= ST_BYTE_DISPATCH;
							end
						end

						default:
							set_error(`MCD_DBG_ERR_INVALID_CMD);
					endcase
				end
			end

			ST_WAIT_PAUSE: begin
				if (paused) finish_ok();
			end

			ST_BYTE_DISPATCH: begin
				current_addr = op_addr + op_index;
				current_byte = get_write_byte(op_cmd, op_wdata, op_index);

				if (target_is_sdram(op_target)) begin
					if (sdr_grant) begin
						sdr_addr <= sdram_phys_addr(op_target, current_addr, mcd_bank23);
						if (op_cmd == `MCD_DBG_CMD_READ8 || op_cmd == `MCD_DBG_CMD_READ16 ||
						    op_cmd == `MCD_DBG_CMD_READ32 || op_cmd == `MCD_DBG_CMD_READ_BLOCK) begin
							sdr_din <= 16'h0000;
							state <= ST_SDR_PULSE;
							sdr_rd <= 1'b1;
							sdr_req <= 1'b1;
						end else begin
							sdr_din <= current_addr[0] ? {8'h00, current_byte} : {current_byte, 8'h00};
							sdr_req <= 1'b1;
							if (current_addr[0]) sdr_wrl <= 1'b1;
							else                 sdr_wrh <= 1'b1;
							state <= ST_SDR_PULSE;
						end
					end
				end else if (target_is_backup(op_target)) begin
					if (bram_grant) begin
						bram_addr <= current_addr[12:1];
						bram_we <= 1'b0;
						bram_req <= 1'b1;
						state <= ST_BRAM_READ_REQ;
					end
				end else if (target_is_wordram(op_target)) begin
					word_bank <= current_addr[17];
					word_addr <= current_addr[16:1];
					word_we <= 1'b0;
					word_req <= 1'b1;
					state <= ST_WORD_READ_REQ;
				end else begin
					set_error(`MCD_DBG_ERR_INVALID_TARGET);
				end
			end

			ST_SDR_PULSE: begin
				state <= ST_SDR_WAIT_BUSY;
			end

			ST_SDR_WAIT_BUSY: begin
				if (sdr_busy) state <= ST_SDR_WAIT_DONE;
			end

			ST_SDR_WAIT_DONE: begin
				if (!sdr_busy) begin
					if (op_cmd == `MCD_DBG_CMD_READ8 || op_cmd == `MCD_DBG_CMD_READ16 ||
					    op_cmd == `MCD_DBG_CMD_READ32 || op_cmd == `MCD_DBG_CMD_READ_BLOCK) begin
						data_window[op_index[4:1]][8 * ~op_index[0] +: 8] <= select_byte(op_target, sdr_dout, current_addr);
						data_valid_reg <= 1'b1;
						if (op_index == (op_length - 1)) finish_ok();
						else begin
							op_index <= op_index + 1'd1;
							state <= ST_BYTE_DISPATCH;
						end
					end else begin
						if (op_index == (op_length - 1)) finish_ok();
						else begin
							op_index <= op_index + 1'd1;
							state <= ST_BYTE_DISPATCH;
						end
					end
				end
			end

			ST_BRAM_READ_REQ: begin
				state <= ST_BRAM_READ_WAIT;
			end

			ST_BRAM_READ_WAIT: begin
				if (bram_ack) begin
					scratch_word <= bram_dout;
					if (op_cmd == `MCD_DBG_CMD_READ8 || op_cmd == `MCD_DBG_CMD_READ16 ||
					    op_cmd == `MCD_DBG_CMD_READ32 || op_cmd == `MCD_DBG_CMD_READ_BLOCK) begin
						data_window[op_index[4:1]][8 * ~op_index[0] +: 8] <= select_byte(op_target, bram_dout, current_addr);
						data_valid_reg <= 1'b1;
						if (op_index == (op_length - 1)) finish_ok();
						else begin
							op_index <= op_index + 1'd1;
							state <= ST_BYTE_DISPATCH;
						end
					end else begin
						bram_din <= merge_byte(op_target, bram_dout, current_addr, current_byte);
						bram_we <= 1'b1;
						bram_req <= 1'b1;
						state <= ST_BRAM_WRITE_REQ;
					end
				end
			end

			ST_BRAM_WRITE_REQ: begin
				state <= ST_BRAM_WRITE_WAIT;
			end

			ST_BRAM_WRITE_WAIT: begin
				if (bram_ack) begin
					bram_we <= 1'b0;
					if (op_index == (op_length - 1)) finish_ok();
					else begin
						op_index <= op_index + 1'd1;
						state <= ST_BYTE_DISPATCH;
					end
				end
			end

			ST_WORD_READ_REQ: begin
				state <= ST_WORD_READ_WAIT;
			end

			ST_WORD_READ_WAIT: begin
				if (word_ack) begin
					scratch_word <= word_dout;
					if (op_cmd == `MCD_DBG_CMD_READ8 || op_cmd == `MCD_DBG_CMD_READ16 ||
					    op_cmd == `MCD_DBG_CMD_READ32 || op_cmd == `MCD_DBG_CMD_READ_BLOCK) begin
						data_window[op_index[4:1]][8 * ~op_index[0] +: 8] <= select_byte(op_target, word_dout, current_addr);
						data_valid_reg <= 1'b1;
						if (op_index == (op_length - 1)) finish_ok();
						else begin
							op_index <= op_index + 1'd1;
							state <= ST_BYTE_DISPATCH;
						end
					end else begin
						word_din <= merge_byte(op_target, word_dout, current_addr, current_byte);
						word_we <= 1'b1;
						word_req <= 1'b1;
						state <= ST_WORD_WRITE_REQ;
					end
				end
			end

			ST_WORD_WRITE_REQ: begin
				state <= ST_WORD_WRITE_WAIT;
			end

			ST_WORD_WRITE_WAIT: begin
				if (word_ack) begin
					word_we <= 1'b0;
					if (op_index == (op_length - 1)) finish_ok();
					else begin
						op_index <= op_index + 1'd1;
						state <= ST_BYTE_DISPATCH;
					end
				end
			end

			default:
				state <= ST_IDLE;
		endcase
	end
end

endmodule
