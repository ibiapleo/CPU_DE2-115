`timescale 1ns/1ps
`default_nettype none
`include "defines.vh"
module tb_decoder;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    integer erros = 0;

    reg  [17:0] instr;
    wire [2:0]  opcode;
    wire [3:0]  rd, rs1, rs2;
    wire [15:0] imm;
    wire        use_imm, reg_write, is_clear, is_display;

    decoder dut (
        .instr(instr), .opcode(opcode), .rd(rd), .rs1(rs1), .rs2(rs2), .imm(imm),
        .use_imm(use_imm), .reg_write(reg_write),
        .is_clear(is_clear), .is_display(is_display)
    );

    // Aplica uma instrucao e compara todas as saidas com o esperado
    task checa;
        input [17:0]       t_instr;
        input [2:0]        e_op;
        input [3:0]        e_rd, e_rs1, e_rs2;
        input signed [15:0] e_imm;
        input              e_use_imm, e_reg_write, e_clear, e_display;
        input [8*24-1:0]   nome;
        begin
            instr = t_instr;
            #1;
            if (opcode !== e_op || rd !== e_rd || rs1 !== e_rs1 || rs2 !== e_rs2 ||
                imm !== e_imm || use_imm !== e_use_imm || reg_write !== e_reg_write ||
                is_clear !== e_clear || is_display !== e_display) begin
                erros = erros + 1;
                $display("ERRO: %0s (instr=%b)", nome, t_instr);
                $display("      obtido   op=%b rd=%0d rs1=%0d rs2=%0d imm=%0d use_imm=%b reg_write=%b clear=%b display=%b",
                         opcode, rd, rs1, rs2, $signed(imm), use_imm, reg_write, is_clear, is_display);
                $display("      esperado op=%b rd=%0d rs1=%0d rs2=%0d imm=%0d use_imm=%b reg_write=%b clear=%b display=%b",
                         e_op, e_rd, e_rs1, e_rs2, e_imm, e_use_imm, e_reg_write, e_clear, e_display);
            end
        end
    endtask

    initial begin
        $dumpfile("tb_decoder.vcd");
        $dumpvars(0, tb_decoder);

        // Sequencia de testes esperados
        //     instr                      op    rd  rs1 rs2  imm  use reg clr dpl
        checa(18'b000_0010_0000_0_001100, 3'b000, 2, 0, 1,   12, 1, 1, 0, 0, "1  LOAD R2, 12");
        checa(18'b001_0001_0000_0010_000, 3'b001, 1, 0, 2,   16, 0, 1, 0, 0, "2  ADD R1, R0, R2");
        checa(18'b100_0011_0001_0_010100, 3'b100, 3, 1, 2,   20, 1, 1, 0, 0, "3  SUBI R3, R1, 20");
        checa(18'b101_0100_0011_1_000101, 3'b101, 4, 3, 8,   -5, 1, 1, 0, 0, "4  MUL R4, R3, -5");
        checa(18'b011_0101_0100_0001_000, 3'b011, 5, 4, 1,    8, 0, 1, 0, 0, "5  SUB R5, R4, R1");
        checa(18'b010_0110_0101_1_111111, 3'b010, 6, 5, 15, -63, 1, 1, 0, 0, "6  ADDI R6, R5, -63");
        checa(18'b111_0000_0010_0_000000, 3'b111, 0, 2, 0,    0, 0, 0, 0, 1, "7  DISPLAY R2");
        checa(18'b000_0111_0000_0_111111, 3'b000, 7, 0, 7,   63, 1, 1, 0, 0, "8  LOAD R7, 63");
        checa(18'b101_0111_0111_0_111111, 3'b101, 7, 7, 7,   63, 1, 1, 0, 0, "9  MUL R7, R7, 63");
        checa(18'b110_0000_0000_0_000000, 3'b110, 0, 0, 0,    0, 0, 0, 1, 0, "11 CLEAR");
        checa(18'b111_0000_0111_0_000000, 3'b111, 0, 7, 0,    0, 0, 0, 0, 1, "12 DISPLAY R7");

        // Casos de borda
        checa(18'b000_1111_0000_1_000000, 3'b000, 15, 0, 8,   0, 1, 1, 0, 0, "-0 vira 0, rd=15");
        checa(18'b010_1111_1111_0_111111, 3'b010, 15, 15, 7, 63, 1, 1, 0, 0, "ADDI R15, R15, +63");
        checa(18'b100_0000_0000_1_000001, 3'b100, 0, 0, 8,   -1, 1, 1, 0, 0, "SUBI imm=-1");
        checa(18'b001_1111_1111_1111_111, 3'b001, 15, 15, 15, -63, 0, 1, 0, 0, "ADD R15, R15, R15");
        checa(18'b011_1010_0101_1100_000, 3'b011, 10, 5, 12, -32, 0, 1, 0, 0, "SUB R10, R5, R12");
        checa(18'b110_1111_1111_1_111111, 3'b110, 15, 15, 15, -63, 0, 0, 1, 0, "CLEAR com lixo nos bits");

        if (erros == 0) $display("tb_decoder: OK");
        else            $display("tb_decoder: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
`default_nettype wire
