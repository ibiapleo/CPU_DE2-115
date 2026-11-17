`default_nettype none
module button_handler #(
    parameter DEBOUNCE_CYCLES = 1_000_000   // 20 ms a 50 MHz
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_n,      // 0 = apertado
    output reg  released
);
    localparam SOLTO = 3'd0, FILTRA_APERTO = 3'd1, APERTADO = 3'd2,
               FILTRA_SOLTURA = 3'd3, SOLTOU = 3'd4;

    reg [2:0]  estado_atual;
    reg [1:0]  sync;     // sincronizador de 2 flip-flops; sync[1] e o botao ja sincronizado
    reg [19:0] tempo;    // 20 bits contam ate 1.048.575, o bastante para 1.000.000

    wire btn = sync[1];

    always @(*) begin   // parte combinacional
        case (estado_atual)
            SOLTO:          released <= 1'b0;
            FILTRA_APERTO:  released <= 1'b0;
            APERTADO:       released <= 1'b0;
            FILTRA_SOLTURA: released <= 1'b0;
            SOLTOU:         released <= 1'b1;
            default:        released <= 1'b0;
        endcase
    end

    always @(posedge clk) begin   // parte sequencial
        if (rst) begin
            sync         <= 2'b11;   // comeca solto: nao gera pulso falso
            estado_atual <= SOLTO;
            tempo        <= 0;
        end
        else begin
            sync <= {sync[0], btn_n};

            case (estado_atual)
                SOLTO: begin
                    tempo <= 0;
                    if (btn == 0)
                        estado_atual <= FILTRA_APERTO;
                end

                // so aceita o aperto se o botao ficar em 0 por DEBOUNCE_CYCLES ciclos seguidos
                FILTRA_APERTO:
                    if (btn == 1)
                        estado_atual <= SOLTO;
                    else if (tempo == DEBOUNCE_CYCLES - 1)
                        estado_atual <= APERTADO;
                    else
                        tempo <= tempo + 1'b1;

                APERTADO: begin
                    tempo <= 0;
                    if (btn == 1)
                        estado_atual <= FILTRA_SOLTURA;
                end

                FILTRA_SOLTURA:
                    if (btn == 0)
                        estado_atual <= APERTADO;
                    else if (tempo == DEBOUNCE_CYCLES - 1)
                        estado_atual <= SOLTOU;
                    else
                        tempo <= tempo + 1'b1;

                SOLTOU:
                    estado_atual <= SOLTO;

                default:
                    estado_atual <= SOLTO;
            endcase
        end
    end
endmodule
`default_nettype wire
