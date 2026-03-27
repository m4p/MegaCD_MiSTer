module CDDA_FIFO
(
	input      CLK,
	input      nRESET,
	input      RD,
	input      WR,
	input      [31:0] DIN,
	input      SS_REQ,
	input      SS_WR,
	input      [10:0] SS_ADDR,
	input      [31:0] SS_DIN,
	output     FULL,
	output     EMPTY,
	output     WRITE_READY,
	output reg [31:0] Q,
	output reg [31:0] SS_DOUT,
	output     SS_ACK

);

localparam SECTOR_SIZE = 2352*8/32;
localparam BUFFER_AMOUNT = 5 * 1024*8/32;

reg OLD_WRITE, OLD_READ;
reg SS_REQ_D;
reg [10:0] SS_ADDR_D;

reg [12:0] FILLED_COUNT;
reg [12:0] READ_ADDR, WRITE_ADDR;
reg [31:0] BUFFER[BUFFER_AMOUNT];
reg [31:0] BUFFER_Q;

wire WRITE_REQ = ~OLD_WRITE & WR;
wire READ_REQ = ~OLD_READ & RD;

assign FULL = (FILLED_COUNT == BUFFER_AMOUNT);
assign EMPTY = ~|FILLED_COUNT;
assign WRITE_READY = (FILLED_COUNT <= (BUFFER_AMOUNT - SECTOR_SIZE)); // Ready to receive sector

always @(posedge CLK or negedge nRESET) begin
	if (~nRESET) begin
		OLD_WRITE <= 0;
		OLD_READ <= 0;
		READ_ADDR <= 0;
		WRITE_ADDR <= 0;
		FILLED_COUNT <= 0;
	end else begin
		OLD_WRITE <= WR;
		OLD_READ <= RD;

		if (SS_REQ && SS_WR) begin
			case (SS_ADDR)
				11'd0: begin
					OLD_WRITE <= SS_DIN[0];
					OLD_READ <= SS_DIN[1];
					FILLED_COUNT <= SS_DIN[14:2];
					READ_ADDR <= SS_DIN[27:15];
				end
				11'd1: WRITE_ADDR <= SS_DIN[12:0];
				11'd2: Q <= SS_DIN;
				default: begin
				end
			endcase
		end

		if (WRITE_REQ) begin
			if (WRITE_ADDR == BUFFER_AMOUNT-1) begin
				WRITE_ADDR <= 0;
			end else begin
				WRITE_ADDR <= WRITE_ADDR + 1'b1;
			end
		end

		if (READ_REQ) begin
			if (READ_ADDR == BUFFER_AMOUNT-1) begin
				READ_ADDR <= 0;
			end else begin
				READ_ADDR <= READ_ADDR + 1'b1;
			end
			Q <= BUFFER_Q;
		end

		FILLED_COUNT <= FILLED_COUNT + WRITE_REQ - READ_REQ;
	end
end

assign SS_ACK = SS_REQ_D;

always @(posedge CLK) begin
	BUFFER_Q <= BUFFER[READ_ADDR];
	if (WRITE_REQ) begin
		BUFFER[WRITE_ADDR] <= DIN;
	end
	if (SS_REQ && SS_WR && (SS_ADDR == 11'd3)) begin
		BUFFER_Q <= SS_DIN;
	end
	if (SS_REQ && SS_WR && (SS_ADDR >= 11'd4) && ((SS_ADDR - 11'd4) < BUFFER_AMOUNT)) begin
		BUFFER[SS_ADDR - 11'd4] <= SS_DIN;
	end
end

always @(posedge CLK or negedge nRESET) begin
	if (~nRESET) begin
		SS_REQ_D <= 0;
		SS_ADDR_D <= 0;
		SS_DOUT <= 0;
	end else begin
		SS_REQ_D <= SS_REQ;
		if (SS_REQ) begin
			SS_ADDR_D <= SS_ADDR;
			SS_DOUT <= 32'h00000000;
			case (SS_ADDR)
				11'd0: SS_DOUT <= {4'b0000, READ_ADDR, FILLED_COUNT, OLD_READ, OLD_WRITE};
				11'd1: SS_DOUT <= {19'b0000000000000000000, WRITE_ADDR};
				11'd2: SS_DOUT <= Q;
				11'd3: SS_DOUT <= BUFFER_Q;
				default: begin
					if ((SS_ADDR >= 11'd4) && ((SS_ADDR - 11'd4) < BUFFER_AMOUNT))
						SS_DOUT <= BUFFER[SS_ADDR - 11'd4];
				end
			endcase
		end

	end
end

endmodule
