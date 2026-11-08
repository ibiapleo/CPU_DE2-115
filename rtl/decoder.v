// PARTE B - Unico lugar que conhece a posicao dos bits da instrucao.
// Especificacao: docs/DIVISAO.md, Parte B e docs/DIVISAO.md
`default_nettype none
`include "defines.vh"
module decoder (
    input  wire [17:0] instr,
    output wire [2:0]  opcode,
    output wire [3:0]  rd,
    output wire [3:0]  rs1,
    output wire [3:0]  rs2,
    output wire [15:0] imm,         // complemento de 2
    output wire        use_imm,     // LOAD, ADDI, SUBI, MUL
    output wire        reg_write,   // LOAD, ADD, ADDI, SUB, SUBI, MUL
    output wire        is_clear,
    output wire        is_display
);
    // TODO (Parte B): extrair os campos conforme docs/DIVISAO.md
    assign opcode     = 3'd0;
    assign rd         = 4'd0;
    assign rs1        = 4'd0;
    assign rs2        = 4'd0;
    assign imm        = 16'd0;
    assign use_imm    = 1'b0;
    assign reg_write  = 1'b0;
    assign is_clear   = 1'b0;
    assign is_display = 1'b0;
endmodule
`default_nettype wire
