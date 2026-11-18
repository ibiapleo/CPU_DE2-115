// PARTE C - ALU combinacional. MODULO OBRIGATORIO.
// Especificacao: docs/DIVISAO.md, Parte C
module module_alu (
    input  wire [2:0]  op,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,

    output reg signed [15:0] result,
    output reg overflow
);

reg signed [16:0] temp;
reg signed [31:0] produto;

always @(*) begin
	result = 0;
   overflow = 0;
   temp = 0;

	case (op)
		3'b000: result = b; // LOAD

		3'b001: begin
			temp = {a[15], a} + {b[15], b};

			result = temp[15:0];

			overflow = (temp[16] != temp[15]); // confere se houve overflow
		end
				
		3'b010: begin
			temp = {a[15], a} + {b[15], b};

			result = temp[15:0];

			overflow = (temp[16] != temp[15]); // confere se houve overflow
		end

		3'b011: begin
			temp = {a[15], a} - {b[15], b};
			result = temp[15:0];
			overflow = (temp[16] != temp[15]); // confere se houve overflow
		end
				
		3'b100: begin
			temp = {a[15], a} - {b[15], b};
			result = temp[15:0];
			overflow = (temp[16] != temp[15]); // confere se houve overflow
		end

		3'b101: begin 
			produto = a * b;
			result = produto[15:0];
			overflow = (produto[31:16] != {16{produto[15]}});
		end

		3'b110: result = 0; // clear

		3'b111: result = 0; // DISPLAY
	endcase

end

endmodule