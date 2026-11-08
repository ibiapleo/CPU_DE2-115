// PARTE C - Binario (16 bits sem sinal) -> 5 digitos BCD (double dabble).
// Especificacao: docs/DIVISAO.md, Parte C
`default_nettype none
module bin2bcd (
    input  wire [15:0] bin,
    output wire [19:0] bcd   // [19:16] dezena de milhar ... [3:0] unidade
);
    // TODO (Parte C)
    assign bcd = 20'd0;
endmodule
`default_nettype wire
