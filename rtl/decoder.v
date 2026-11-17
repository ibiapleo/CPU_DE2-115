`default_nettype none
`include "defines.vh"
module decoder (
    input  wire [17:0] instr,
    output wire [2:0]  opcode,
    output wire [3:0]  rd,
    output wire [3:0]  rs1,
    output wire [3:0]  rs2,
    output wire [15:0] imm,
    output wire        use_imm,     // LOAD, ADDI, SUBI, MUL
    output wire        reg_write,   // LOAD, ADD, ADDI, SUB, SUBI, MUL
    output wire        is_clear,
    output wire        is_display
);
    assign opcode = instr[17:15];
    assign rd     = instr[14:11];
    assign rs1    = instr[10:7];
    assign rs2    = instr[6:3];

    // Imediato em sinal-magnitude: instr[6] = sinal (1 = negativo), instr[5:0] = |Imm|
    wire        imm_sinal = instr[6];
    wire [15:0] imm_mag   = {10'd0, instr[5:0]};
    assign imm = imm_sinal ? (~imm_mag + 16'd1) : imm_mag;

    assign is_clear   = (opcode == `OP_CLEAR);
    assign is_display = (opcode == `OP_DISPLAY);
    assign use_imm    = (opcode == `OP_LOAD) || (opcode == `OP_ADDI) ||
                        (opcode == `OP_SUBI) || (opcode == `OP_MUL);
    assign reg_write  = ~(is_clear | is_display);
endmodule
`default_nettype wire
