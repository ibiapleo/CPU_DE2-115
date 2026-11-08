// Constantes compartilhadas.
`ifndef DEFINES_VH
`define DEFINES_VH

// Opcodes (sempre em instr[17:15]) - ver docs/DIVISAO.md
`define OP_LOAD    3'b000
`define OP_ADD     3'b001
`define OP_ADDI    3'b010
`define OP_SUB     3'b011
`define OP_SUBI    3'b100
`define OP_MUL     3'b101
`define OP_CLEAR   3'b110
`define OP_DISPLAY 3'b111

// Tipos de tela do LCD (disp_kind) - ver docs/DIVISAO.md, Parte C
`define DISP_INICIAL   2'd0
`define DISP_RESULTADO 2'd1
`define DISP_SO_NOME   2'd2

`endif
