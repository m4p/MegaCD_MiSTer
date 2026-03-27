/*  This file is part of JT12.

	JT12 is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	JT12 is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with JT12.  If not, see <http://www.gnu.org/licenses/>.

	Author: Jose Tejada Gomez. Twitter: @topapate
	Version: 1.0
	Date: 29-10-2018

	*/

module jt12_eg_cnt(
	input rst,
	input clk,
	input clk_en /* synthesis direct_enable */,
	input ss_apply,
	input zero,
	output reg [14:0] eg_cnt,
	input [16:0] ss_state_in,
	output [16:0] ss_state_out
);

reg	[1:0] eg_cnt_base;

always @(posedge clk, posedge rst) begin : envelope_counter
	if( rst ) begin
		eg_cnt_base	<= 2'd0;
		eg_cnt		<=15'd0;
	end else if( ss_apply ) begin
		eg_cnt_base <= ss_state_in[1:0];
		eg_cnt <= ss_state_in[16:2];
	end else begin
		if( zero && clk_en ) begin
			// envelope counter increases every 3 output samples,
			// there is one sample every 24 clock ticks
			if( eg_cnt_base == 2'd2 ) begin
				eg_cnt 		<= eg_cnt + 1'b1;
				eg_cnt_base	<= 2'd0;
			end
			else eg_cnt_base <= eg_cnt_base + 1'b1;
		end
	end
end

assign ss_state_out[1:0] = eg_cnt_base;
assign ss_state_out[16:2] = eg_cnt;

endmodule // jt12_eg_cnt
