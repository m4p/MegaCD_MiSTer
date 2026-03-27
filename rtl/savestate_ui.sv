module savestate_ui
(
	input             clk,
	input      [10:0] ps2_key,
	input             allow_ss,
	input      [1:0]  status_slot,
	input             autoincslot,
	input      [1:0]  osd_saveload,
	input      [3:0]  valid_slots,
	output reg        ss_save,
	output reg        ss_load,
	output reg  [1:0] selected_slot
);

reg old_state;
reg alt;
reg [1:0] old_osd;

wire pressed = ps2_key[9];

always @(posedge clk) begin
	old_state <= ps2_key[10];
	old_osd <= osd_saveload;

	ss_save <= 1'b0;
	ss_load <= 1'b0;

	if (!allow_ss) begin
		selected_slot <= status_slot;
		alt <= 1'b0;
	end else begin
		if (old_state != ps2_key[10]) begin
			case (ps2_key[7:0])
				8'h11: alt <= pressed;
				8'h05: begin
					selected_slot <= 2'd0;
					ss_save <= pressed & alt;
					ss_load <= pressed & ~alt & valid_slots[0];
				end
				8'h06: begin
					selected_slot <= 2'd1;
					ss_save <= pressed & alt;
					ss_load <= pressed & ~alt & valid_slots[1];
				end
				8'h04: begin
					selected_slot <= 2'd2;
					ss_save <= pressed & alt;
					ss_load <= pressed & ~alt & valid_slots[2];
				end
				8'h0C: begin
					selected_slot <= 2'd3;
					ss_save <= pressed & alt;
					ss_load <= pressed & ~alt & valid_slots[3];
				end
			endcase
		end

		if (selected_slot != status_slot) selected_slot <= status_slot;

		if (~old_osd[0] & osd_saveload[0]) begin
			ss_save <= 1'b1;
			if (autoincslot && selected_slot != 2'd3) selected_slot <= selected_slot + 1'b1;
		end

		if (~old_osd[1] & osd_saveload[1]) begin
			ss_load <= valid_slots[selected_slot];
		end
	end
end

endmodule
