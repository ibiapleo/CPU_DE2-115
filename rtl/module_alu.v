// PARTE C - ALU combinacional. MODULO OBRIGATORIO.
// Especificacao: docs/DIVISAO.md, Parte C
`default_nettype none
`include "defines.vh"
module module_alu (
    input  wire [2:0]  op,         // opcode da instrucao
    input  wire [15:0] a,          // com sinal (complemento de 2)
    input  wire [15:0] b,          // com sinal
    output wire [15:0] result,
    output wire        overflow    // opcional (LED de debug)
);
    // TODO (Parte C): LOAD -> b; ADD/ADDI -> a+b; SUB/SUBI -> a-b; MUL -> 16 LSB de a*b; resto -> 0
    assign result   = 16'd0;
    assign overflow = 1'b0;
endmodule
`default_nettype wire
