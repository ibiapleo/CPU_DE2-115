// Testbench de lcd_formatter - especificacao em docs/DIVISAO.md, testes em docs/DIVISAO.md
`timescale 1ns/1ps
`default_nettype none
`include "defines.vh"
module tb_lcd_formatter;
    reg clk = 1'b0;
    always #10 clk = ~clk;   // 50 MHz
    integer erros = 0;

    // TODO: instanciar o modulo, aplicar estimulos e comparar com o esperado.
    // Ao achar erro: erros = erros + 1; $display("ERRO: ...");

    initial begin
        $dumpfile("tb_lcd_formatter.vcd");
        $dumpvars(0, tb_lcd_formatter);
        #1000;
        if (erros == 0) $display("tb_lcd_formatter: OK");
        else            $display("tb_lcd_formatter: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
`default_nettype wire
