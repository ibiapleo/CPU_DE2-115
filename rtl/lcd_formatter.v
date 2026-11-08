// PARTE C - Monta os 32 caracteres ASCII da tela (combinacional).
// Especificacao: docs/DIVISAO.md, Parte C
// Layout: caractere i (0..31) em screen[255-8*i -: 8]; 0..15 = linha 1, 16..31 = linha 2.
`default_nettype none
`include "defines.vh"
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

    // TODO (Parte C): montar as telas. Stub: tela inicial fixa.
    assign screen = "------    [----]          +00000";
endmodule
`default_nettype wire
