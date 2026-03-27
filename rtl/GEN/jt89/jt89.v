/*  This file is part of JT89.

    JT89 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT89 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT89.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: March, 8th 2017

    This work was originally based in the implementation found on the
    SMS core of MiST. Some of the changes, all according to data sheet:

        -Fixed volume
        -Fixed tone 2 rate option of noise generator
        -Fixed rate of noise generator
        -Fixed noise shift clear
        -Fixed noise generator update bug by which it gets updated
            multiple times if v='0'
        -Added all 0's prevention circuit to noise generator

    */

module jt89(
    input   clk,
(* direct_enable = 1 *) input   clk_en,
    input          rst,
    input          wr_n,
    input    [7:0] din,
    input          ss_req,
    input          ss_wr,
    input    [2:0] ss_addr,
    input   [31:0] ss_din,
    output  [31:0] ss_dout,
    output         ss_ack,
    output  signed [10:0] sound,
    output         ready
);

parameter interpol16=0;
localparam [2:0] JT89_SS_CTRL_ADDR = 3'b111;
localparam [31:0] JT89_SS_WORDS = 32'd4;

wire signed [ 8:0] ch0, ch1, ch2, noise;
wire [9:0] tone0_ss_cnt;
wire [9:0] tone1_ss_cnt;
wire [9:0] tone2_ss_cnt;
wire [15:0] noise_ss_shift;
wire [10:0] noise_ss_cnt;
wire tone0_out;
wire tone1_out;
wire out2;

reg [31:0] ss_shadow[0:3];
reg        ss_req_d;
reg [31:0] ss_dout_reg;
reg        ss_commit_pending;
wire       ss_apply = ss_commit_pending;

assign ready = 1'b1;
assign ss_dout = ss_dout_reg;
assign ss_ack = ss_req_d;
(* direct_enable = 1 *) reg cen_16;
(* direct_enable = 1 *) reg cen_4;

jt89_mixer #(.interpol16(interpol16)) mix(
    .clk    ( clk   ),
    .clk_en ( clk_en), // uses main clock enable
    .cen_16 ( cen_16),
    .cen_4  ( cen_4 ),
    .rst    ( rst   ),
    .ch0    ( ch0   ),
    .ch1    ( ch1   ),
    .ch2    ( ch2   ),
    .noise  ( noise ),
    .sound  ( sound )
);

// configuration registers
reg [9:0] tone0, tone1, tone2;
reg [3:0] vol0, vol1, vol2, vol3;
reg [2:0] ctrl3;
reg [2:0] regn;

reg [3:0] clk_div;

always @(posedge clk )
    if( rst ) begin
        cen_16 <= 1'b1;
        cen_4  <= 1'b1;
    end else if( ss_apply ) begin
        cen_16 <= ss_shadow[1][25];
        cen_4  <= ss_shadow[1][26];
    end else begin
        cen_16 <= clk_en & (&clk_div);
        cen_4  <= clk_en & (&clk_div[1:0]);
    end

always @(posedge clk )
    if( rst )
        clk_div <= 4'd0;
    else if( ss_apply )
        clk_div <= ss_shadow[1][22:19];
    else if( clk_en )
        clk_div <= clk_div + 1'b1;

reg clr_noise, last_wr;
wire [2:0] reg_sel = din[7] ? din[6:4] : regn;

always @(posedge clk)
    if( rst ) begin
        { vol0, vol1, vol2, vol3 } <= {16{1'b1}};
        { tone0, tone1, tone2 } <= 30'd0;
        ctrl3 <= 3'b100;
        regn <= 3'd0;
        clr_noise <= 1'b0;
        last_wr <= 1'b1;
    end
    else if( ss_apply ) begin
        tone0 <= ss_shadow[0][9:0];
        tone1 <= ss_shadow[0][19:10];
        tone2 <= ss_shadow[0][29:20];
        ctrl3 <= {ss_shadow[1][23], ss_shadow[0][31:30]};
        vol0 <= ss_shadow[1][3:0];
        vol1 <= ss_shadow[1][7:4];
        vol2 <= ss_shadow[1][11:8];
        vol3 <= ss_shadow[1][15:12];
        regn <= ss_shadow[1][18:16];
        clr_noise <= 1'b0;
        last_wr <= ss_shadow[1][24];
    end
    else begin
        last_wr <= wr_n;
        if( !wr_n && last_wr ) begin
            clr_noise <= din[7:4] == 4'b1110; // clear noise
            // when there is an access to the control register
            regn <= reg_sel;
            case( reg_sel )
                3'b00_0: if( din[7] ) tone0[3:0]<=din[3:0]; else tone0[9:4]<=din[5:0];
                3'b01_0: if( din[7] ) tone1[3:0]<=din[3:0]; else tone1[9:4]<=din[5:0];
                3'b10_0: if( din[7] ) tone2[3:0]<=din[3:0]; else tone2[9:4]<=din[5:0];
                3'b11_0: ctrl3 <= din[2:0];
                3'b00_1: vol0  <= din[3:0];
                3'b01_1: vol1  <= din[3:0];
                3'b10_1: vol2  <= din[3:0];
                3'b11_1: vol3  <= din[3:0];
            endcase
        end
        else clr_noise <= 1'b0;
    end

always @(posedge clk)
    if( rst ) begin
        ss_req_d <= 1'b0;
        ss_dout_reg <= 32'd0;
        ss_commit_pending <= 1'b0;
        ss_shadow[0] <= 32'd0;
        ss_shadow[1] <= 32'd0;
        ss_shadow[2] <= 32'd0;
        ss_shadow[3] <= 32'd0;
    end else begin
        ss_req_d <= ss_req;

        if( ss_req ) begin
            ss_dout_reg <= 32'd0;
            case( ss_addr )
                3'd0: begin
                    ss_dout_reg[9:0] <= tone0;
                    ss_dout_reg[19:10] <= tone1;
                    ss_dout_reg[29:20] <= tone2;
                    ss_dout_reg[31:30] <= ctrl3[1:0];
                end
                3'd1: begin
                    ss_dout_reg[3:0] <= vol0;
                    ss_dout_reg[7:4] <= vol1;
                    ss_dout_reg[11:8] <= vol2;
                    ss_dout_reg[15:12] <= vol3;
                    ss_dout_reg[18:16] <= regn;
                    ss_dout_reg[22:19] <= clk_div;
                    ss_dout_reg[23] <= ctrl3[2];
                    ss_dout_reg[24] <= last_wr;
                    ss_dout_reg[25] <= cen_16;
                    ss_dout_reg[26] <= cen_4;
                end
                3'd2: begin
                    ss_dout_reg[9:0] <= tone0_ss_cnt;
                    ss_dout_reg[10] <= tone0_out;
                    ss_dout_reg[20:11] <= tone1_ss_cnt;
                    ss_dout_reg[21] <= tone1_out;
                    ss_dout_reg[31:22] <= tone2_ss_cnt;
                end
                3'd3: begin
                    ss_dout_reg[0] <= out2;
                    ss_dout_reg[16:1] <= noise_ss_shift;
                    ss_dout_reg[27:17] <= noise_ss_cnt;
                end
                default: begin
                    if( ss_addr == JT89_SS_CTRL_ADDR ) ss_dout_reg <= JT89_SS_WORDS;
                end
            endcase
        end

        if( ss_req && ss_wr ) begin
            case( ss_addr )
                3'd0: ss_shadow[0] <= ss_din;
                3'd1: ss_shadow[1] <= ss_din;
                3'd2: ss_shadow[2] <= ss_din;
                3'd3: ss_shadow[3] <= ss_din;
                default: begin
                    if( ss_addr == JT89_SS_CTRL_ADDR && ss_din[31] ) ss_commit_pending <= 1'b1;
                end
            endcase
        end

        if( ss_apply ) ss_commit_pending <= 1'b0;
    end

jt89_tone u_tone0(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol0      ),
    .tone   ( tone0     ),
    .ss_apply( ss_apply ),
    .ss_cnt_in( ss_shadow[2][9:0] ),
    .ss_out_in( ss_shadow[2][10] ),
    .ss_cnt_out( tone0_ss_cnt ),
    .snd    ( ch0       ),
    .out    ( tone0_out )
);

jt89_tone u_tone1(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol1      ),
    .tone   ( tone1     ),
    .ss_apply( ss_apply ),
    .ss_cnt_in( ss_shadow[2][20:11] ),
    .ss_out_in( ss_shadow[2][21] ),
    .ss_cnt_out( tone1_ss_cnt ),
    .snd    ( ch1       ),
    .out    ( tone1_out )
);

jt89_tone u_tone2(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .vol    ( vol2      ),
    .tone   ( tone2     ),
    .ss_apply( ss_apply ),
    .ss_cnt_in( ss_shadow[2][31:22] ),
    .ss_out_in( ss_shadow[3][0] ),
    .ss_cnt_out( tone2_ss_cnt ),
    .snd    ( ch2       ),
    .out    ( out2      )
);

jt89_noise u_noise(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .clk_en ( cen_16    ),
    .clr    ( clr_noise ),
    .vol    ( vol3      ),
    .ctrl3  ( ctrl3     ),
    .tone2  ( tone2     ),
    .ss_apply( ss_apply ),
    .ss_shift_in( ss_shadow[3][16:1] ),
    .ss_cnt_in( ss_shadow[3][27:17] ),
    .ss_shift_out( noise_ss_shift ),
    .ss_cnt_out( noise_ss_cnt ),
    .snd    ( noise     )
);

endmodule
