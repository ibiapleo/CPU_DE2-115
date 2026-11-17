// PARTE D - Driver do LCD 16x2 (HD44780) da DE2-115.
// Especificacao (portas, envio de byte, sequencias): docs/DIVISAO.md
// Estrutura:
//   BLOCO 1 - envia byte (RS/DATA, pulso de EN, espera de 1 ms ou 2 ms)
//   BLOCO 2 - sequenciador (maquina de estados que escolhe qual byte enviar)
// screen: o caractere i fica em screen[255-8*i -: 8]
//         i = 0..15 -> linha 1 | i = 16..31 -> linha 2
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
    localparam CICLOS_1US  = CLK_HZ / 1_000_000 + 1;   // ~1 us (nunca menos de 1 ciclo)
    localparam CICLOS_1MS  = CLK_HZ / 1000;
    localparam CICLOS_2MS  = CLK_HZ / 500;             // depois do comando 0x01 (limpar)
    localparam CICLOS_20MS = CLK_HZ / 50;              // espera inicial

    // Saidas internas (registradores) ligadas as portas
    reg       ocupado_reg;
    reg       concluido_reg;
    reg [7:0] dados_reg;
    reg       rs_reg;
    reg       en_reg;

    assign busy     = ocupado_reg;
    assign done     = concluido_reg;
    assign lcd_data = dados_reg;
    assign lcd_rs   = rs_reg;
    assign lcd_en   = en_reg;
    // Fixos: so escrevemos no LCD (RW=0), LCD ligado, backlight ligado
    assign lcd_rw   = 1'b0;
    assign lcd_on   = 1'b1;
    assign lcd_blon = 1'b1;

    // -------------------------------------------------------------------------
    // BLOCO 1 - Enviador de byte
    // Recebe : inicia_byte (pulso), byte_rs, byte_dado, byte_lento
    // Devolve: byte_pronto (pulso de 1 ciclo quando o byte acabou, ja com a espera)
    // Passos : coloca RS/DATA -> espera ~1us -> EN=1 -> ~1us -> EN=0 (o LCD
    //          captura o byte) -> espera 1 ms (ou 2 ms se byte_lento)
    // -------------------------------------------------------------------------
    localparam [1:0] B_OCIOSO = 2'd0, B_PREPARA = 2'd1, B_EN_ALTO = 2'd2, B_ESPERA = 2'd3;

    reg [1:0]  est_byte;
    reg [20:0] cont_byte;
    reg        inicia_byte;   // pedido vindo do sequenciador
    reg        byte_rs;
    reg [7:0]  byte_dado;
    reg        byte_lento;
    reg        byte_pronto;

    always @(posedge clk) begin
        byte_pronto <= 1'b0;
        if (rst) begin
            est_byte    <= B_OCIOSO;
            cont_byte    <= 21'd0;
            en_reg   <= 1'b0;
            rs_reg   <= 1'b0;
            dados_reg <= 8'h00;
        end else begin
            case (est_byte)
                B_OCIOSO: begin
                    if (inicia_byte) begin
                        rs_reg   <= byte_rs;       // RS e DATA primeiro...
                        dados_reg <= byte_dado;
                        cont_byte    <= 21'd0;
                        est_byte    <= B_PREPARA;
                    end
                end
                B_PREPARA: begin
                    if (cont_byte == CICLOS_1US) begin
                        en_reg <= 1'b1;            // ...EN sobe depois (tempo de setup)
                        cont_byte  <= 21'd0;
                        est_byte  <= B_EN_ALTO;
                    end else cont_byte <= cont_byte + 21'd1;
                end
                B_EN_ALTO: begin
                    if (cont_byte == CICLOS_1US) begin
                        en_reg <= 1'b0;            // descida de EN: o LCD captura o byte
                        cont_byte  <= 21'd0;
                        est_byte  <= B_ESPERA;
                    end else cont_byte <= cont_byte + 21'd1;
                end
                B_ESPERA: begin
                    if (cont_byte == (byte_lento ? CICLOS_2MS : CICLOS_1MS)) begin
                        byte_pronto <= 1'b1;
                        est_byte       <= B_OCIOSO;
                    end else cont_byte <= cont_byte + 21'd1;
                end
                default: est_byte <= B_OCIOSO;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // BLOCO 2 - Sequenciador (maquina de estados)
    // -------------------------------------------------------------------------
    localparam [2:0] E_ESPERA_RESET = 3'd0,
                     E_INICIALIZA   = 3'd1,
                     E_OCIOSO       = 3'd2,
                     E_ATUALIZA     = 3'd3,
                     E_DESLIGA      = 3'd4,
                     E_FIM          = 3'd5;

    reg [2:0]   estado;
    reg [5:0]   indice;          // qual byte da sequencia esta sendo enviado
    reg         aguarda_byte;    // 1 = ja pedi o byte, esperando byte_pronto
    reg [255:0] tela_reg;        // copia de screen tirada no instante do refresh
    reg         display_ligado;  // 1 = display ja ligado (0x0C ja foi enviado)
    reg [20:0]  cont_espera;     // contador da espera de 20 ms

    // Pega o caractere n (0..31) da copia da tela
    function [7:0] caractere_em(input [5:0] n);
        caractere_em = tela_reg[255 - 8*n -: 8];
    endfunction

    always @(posedge clk) begin
        inicia_byte <= 1'b0;      // por padrao: nenhum pedido de byte
        concluido_reg     <= 1'b0;      // por padrao: sem pulso de done

        if (rst) begin
            estado     <= E_ESPERA_RESET;
            ocupado_reg    <= 1'b1;   // ocupado durante toda a inicializacao
            indice       <= 6'd0;
            aguarda_byte <= 1'b0;
            cont_espera   <= 21'd0;
            display_ligado   <= 1'b0;
            tela_reg  <= 256'd0;
            byte_rs   <= 1'b0;
            byte_dado <= 8'h00;
            byte_lento <= 1'b0;
        end else begin
            case (estado)

                // Espera 20 ms para o LCD estabilizar
                E_ESPERA_RESET: begin
                    ocupado_reg <= 1'b1;
                    if (cont_espera == CICLOS_20MS) begin
                        cont_espera   <= 21'd0;
                        indice       <= 6'd0;
                        aguarda_byte <= 1'b0;
                        estado     <= E_INICIALIZA;
                    end else cont_espera <= cont_espera + 21'd1;
                end

                // Inicializacao: 0x38, 0x08, 0x01 (lento), 0x06 -> tela apagada
                E_INICIALIZA: begin
                    if (!aguarda_byte) begin
                        byte_rs   <= 1'b0;
                        byte_lento <= (indice == 6'd2);
                        case (indice)
                            6'd0:    byte_dado <= 8'h38;   // 8 bits, 2 linhas, 5x8
                            6'd1:    byte_dado <= 8'h08;   // display desligado
                            6'd2:    byte_dado <= 8'h01;   // limpar display
                            default: byte_dado <= 8'h06;   // cursor anda p/ direita
                        endcase
                        inicia_byte <= 1'b1;
                        aguarda_byte  <= 1'b1;
                    end else if (byte_pronto) begin
                        aguarda_byte <= 1'b0;
                        if (indice == 6'd3) begin
                            indice    <= 6'd0;
                            ocupado_reg <= 1'b0;
                            estado  <= E_OCIOSO;
                        end else indice <= indice + 6'd1;
                    end
                end

                // Espera um pedido da CPU
                E_OCIOSO: begin
                    ocupado_reg <= 1'b0;
                    if (refresh) begin
                        tela_reg  <= screen;                 // copia a tela
                        indice       <= display_ligado ? 6'd1 : 6'd0;  // pula o 0x0C se ja ligado
                        aguarda_byte <= 1'b0;
                        ocupado_reg    <= 1'b1;
                        estado     <= E_ATUALIZA;
                    end else if (power_off) begin
                        indice       <= 6'd0;
                        aguarda_byte <= 1'b0;
                        ocupado_reg    <= 1'b1;
                        estado     <= E_DESLIGA;
                    end
                end

                // Escreve a tela. Sequencia (indice):
                //   0      : 0x0C   (display ligado)   [so se estava apagado]
                //   1      : 0x80   (linha 1, coluna 0)
                //   2..17  : caracteres 0..15
                //   18     : 0xC0   (linha 2, coluna 0)
                //   19..34 : caracteres 16..31
                E_ATUALIZA: begin
                    if (!aguarda_byte) begin
                        byte_lento <= 1'b0;
                        if (indice == 6'd0) begin
                            byte_rs <= 1'b0; byte_dado <= 8'h0C;
                        end else if (indice == 6'd1) begin
                            byte_rs <= 1'b0; byte_dado <= 8'h80;
                        end else if (indice <= 6'd17) begin
                            byte_rs <= 1'b1; byte_dado <= caractere_em(indice - 6'd2);
                        end else if (indice == 6'd18) begin
                            byte_rs <= 1'b0; byte_dado <= 8'hC0;
                        end else begin
                            byte_rs <= 1'b1; byte_dado <= caractere_em(indice - 6'd3);
                        end
                        inicia_byte <= 1'b1;
                        aguarda_byte  <= 1'b1;
                    end else if (byte_pronto) begin
                        aguarda_byte <= 1'b0;
                        if (indice == 6'd34) begin
                            display_ligado <= 1'b1;
                            estado   <= E_FIM;
                        end else indice <= indice + 6'd1;
                    end
                end

                // Apaga a tela: 0x01 (lento) e 0x08
                E_DESLIGA: begin
                    if (!aguarda_byte) begin
                        byte_rs    <= 1'b0;
                        byte_dado  <= (indice == 6'd0) ? 8'h01 : 8'h08;
                        byte_lento  <= (indice == 6'd0);
                        inicia_byte <= 1'b1;
                        aguarda_byte  <= 1'b1;
                    end else if (byte_pronto) begin
                        aguarda_byte <= 1'b0;
                        if (indice == 6'd1) begin
                            display_ligado <= 1'b0;
                            estado   <= E_FIM;
                        end else indice <= indice + 6'd1;
                    end
                end

                // Avisa a CPU: done (1 ciclo) e busy volta a 0
                E_FIM: begin
                    concluido_reg <= 1'b1;
                    ocupado_reg <= 1'b0;
                    estado  <= E_OCIOSO;
                end

                default: estado <= E_OCIOSO;
            endcase
        end
    end

endmodule
`default_nettype wire