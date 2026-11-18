// PARTE C - Monta os 32 caracteres ASCII da tela (combinacional).
// Especificacao: docs/DIVISAO.md, Parte C
// Layout: caractere i (0..31) em screen[255-8*i -: 8]; 0..15 = linha 1, 16..31 = linha 2.
module lcd_formatter (
    input  wire [1:0]   kind,
    input  wire [2:0]   opcode,
    input  wire [3:0]   reg_num,
    input  wire [15:0]  value,     // com sinal
    output wire [255:0] screen
);

wire [19:0] bcd;
wire [15:0] magnitude = value[15] ? (~value + 16'd1) : value;

bin2bcd u_bin2bcd (.bin(magnitude), .bcd(bcd));

reg [255:0] screen_temp = "------    [----]          +00000";

always @(*) begin
	screen_temp = "                                "; // tela em branco antes de escrever (evita latch)

	if (kind == 0) begin
		screen_temp = "------    [----]          +00000";
	end
	else begin
		case (opcode)
			3'b000: screen_temp[255 : 208] = "LOAD  "; // 6 caracteres: mesma qtd dos -----
			
			3'b001: screen_temp[255 : 208] = "ADD   ";
			
			3'b010: screen_temp[255 : 208] = "ADDI  ";
			
			3'b011: screen_temp[255 : 208] = "SUB   ";
			
			3'b100: screen_temp[255 : 208] = "SUBI  ";
			
			3'b101: screen_temp[255 : 208] = "MUL   ";
			
			3'b110: screen_temp = "CLEAR                           "; // ja escreve a mensagem inteira
			
			3'b111: screen_temp[255 : 208] = "DPL   ";
		endcase
		
		if (opcode != 3'b110 && kind != 2) begin
			screen_temp[175:128] = {"[", ("0" + reg_num[3]), ("0" + reg_num[2]), ("0" + reg_num[1]), ("0" + reg_num[0]), "]"};
			
			if (value[15]) begin
				screen_temp[47:40] = "-";
			end
			else begin
				screen_temp[47:40] = "+";
			end
			
			screen_temp[39:0] = {("0" + bcd[19:16]), ("0" + bcd[15:12]), ("0" + bcd[11:8]), ("0" + bcd[7:4]), ("0" + bcd[3:0])};
		 end
	end
end

assign screen = screen_temp;

endmodule