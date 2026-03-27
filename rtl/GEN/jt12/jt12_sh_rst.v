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
	Date: 1-31-2017
	*/


// stages must be greater than 2
module jt12_sh_rst #(parameter width=5, stages=32, rstval=1'b0 )
(
	input					rst,	
	input 					clk,
	input					clk_en /* synthesis direct_enable */,
	input					ss_apply,
	input		[width-1:0]	din,
	input		[width*stages-1:0] ss_state_in,
	output		[width*stages-1:0] ss_state_out,
   	output		[width-1:0]	drop
);

reg [stages-1:0] bits[width-1:0];

genvar i;
integer k;
generate
initial
	for (k=0; k < width; k=k+1) begin
		bits[k] = { stages{rstval}};
	end
endgenerate

generate
	for (i=0; i < width; i=i+1) begin: bit_shifter
		always @(posedge clk, posedge rst) 
			if( rst ) begin
				bits[i] <= {stages{rstval}};
			end else if(ss_apply) begin
				bits[i] <= ss_state_in[(i*stages) +: stages];
			end else if(clk_en) begin
				bits[i] <= {bits[i][stages-2:0], din[i]};
			end
		assign drop[i] = bits[i][stages-1];
		assign ss_state_out[(i*stages) +: stages] = bits[i];
	end
endgenerate

endmodule
