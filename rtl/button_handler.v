// PARTE A - Sincroniza, faz debounce e gera 1 pulso quando o botao e SOLTO.
// Especificacao: docs/DIVISAO.md, Parte A
`default_nettype none
module button_handler #(
    parameter DEBOUNCE_CYCLES = 1_000_000   // 20 ms a 50 MHz
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_n,      // KEY[i] cru: 0 = apertado
    output wire released    // pulso de 1 ciclo ao soltar
);
    // TODO (Parte A): sincronizador 2 FF + debounce + detector de soltura
    assign released = 1'b0;
endmodule
`default_nettype wire
