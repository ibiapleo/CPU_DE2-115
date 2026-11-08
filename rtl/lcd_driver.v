// PARTE D - Driver do LCD 16x2 (HD44780) da DE2-115.
// Especificacao (portas, envio de byte, sequencias): docs/DIVISAO.md, Parte D
`default_nettype none
module lcd_driver #(
    parameter CLK_HZ = 50_000_000
) (
    input  wire         clk,
    input  wire         rst,
    input  wire         refresh,     // pulso: escreve a tela (inicializa antes se preciso)
    input  wire         power_off,   // pulso: limpa e apaga
    input  wire [255:0] screen,
    output wire         busy,
    output wire         done,        // pulso
    output wire [7:0]   lcd_data,
    output wire         lcd_rs,
    output wire         lcd_rw,
    output wire         lcd_en,
    output wire         lcd_on,
    output wire         lcd_blon
);
    // Ciclos uteis (calculados a partir de CLK_HZ)
    localparam CYC_1MS  = CLK_HZ / 1000;
    localparam CYC_20MS = CLK_HZ / 50;

    // TODO (Parte D): FSM de inicializacao / escrita / desligar
    assign busy     = 1'b0;
    assign done     = 1'b0;
    assign lcd_data = 8'd0;
    assign lcd_rs   = 1'b0;
    assign lcd_rw   = 1'b0;
    assign lcd_en   = 1'b0;
    assign lcd_on   = 1'b0;
    assign lcd_blon = 1'b0;
endmodule
`default_nettype wire
