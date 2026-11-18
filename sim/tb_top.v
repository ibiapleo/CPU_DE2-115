`timescale 1ns/1ps
`default_nettype none
module tb_top;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    integer erros = 0;

    localparam DB      = 10;        // debounce do teste
    localparam LCD_HZ  = 50_000;    // driver mais rapido: 1 ms = 50 ciclos
    localparam TIMEOUT = 100_000;

    localparam S_OFF = 4'd0, S_READY = 4'd4;

    reg  [3:0]  key = 4'b1111;      // KEY[1] = Ligar, KEY[0] = Enviar (0 = apertado)
    reg  [17:0] sw  = 18'd0;
    wire [7:0]  lcd_data;
    wire        lcd_rs, lcd_rw, lcd_en, lcd_on, lcd_blon;
    wire [8:0]  ledg;
    wire [17:0] ledr;

    top_de2_115 #(.DEBOUNCE_CYCLES(DB), .LCD_CLK_HZ(LCD_HZ)) dut (
        .CLOCK_50(clk), .KEY(key), .SW(sw),
        .LCD_DATA(lcd_data), .LCD_RS(lcd_rs), .LCD_RW(lcd_rw), .LCD_EN(lcd_en),
        .LCD_ON(lcd_on), .LCD_BLON(lcd_blon),
        .LEDG(ledg), .LEDR(ledr)
    );

    wire [3:0] estado = ledg[3:0];

    // LCD falso: na descida de EN guarda o byte, como o HD44780
    reg [7:0] ddram [0:31];
    reg [4:0] cursor = 5'd0;
    reg       display_on = 1'b0;
    integer   i;
    initial for (i = 0; i < 32; i = i + 1) ddram[i] = " ";

    always @(negedge lcd_en) begin
        if (lcd_rs) begin
            ddram[cursor] = lcd_data;
            cursor = cursor + 5'd1;
        end else case (lcd_data)
            8'h01: begin for (i = 0; i < 32; i = i + 1) ddram[i] = " "; cursor = 5'd0; end
            8'h08: display_on = 1'b0;
            8'h0C: display_on = 1'b1;
            8'h80: cursor = 5'd0;
            8'hC0: cursor = 5'd16;
            default: ;
        endcase
    end

    function [127:0] linha(input integer l);
        integer k;
        begin
            for (k = 0; k < 16; k = k + 1) linha[127 - 8*k -: 8] = ddram[16*l + k];
        end
    endfunction

    integer n_done = 0;
    always @(posedge clk) if (dut.lcd_done) n_done = n_done + 1;

    task ciclos(input integer n);
        begin
            repeat (n) @(negedge clk);
        end
    endtask

    task espera_tela(input [3:0] estado_final);
        integer k, d0;
        begin
            d0 = n_done;
            k = 0;
            while ((n_done == d0 || estado !== estado_final) && k < TIMEOUT) begin
                @(posedge clk); #1;
                k = k + 1;
            end
            if (k >= TIMEOUT) begin
                erros = erros + 1;
                $display("ERRO: timeout esperando a tela (estado %0d, t=%0t)", estado, $time);
            end
        end
    endtask

    // Aperta e solta com quique nas duas pontas
    task aperta(input integer qual);
        begin
            @(negedge clk);
            key[qual] = 1'b0; ciclos(2);
            key[qual] = 1'b1; ciclos(1);
            key[qual] = 1'b0; ciclos(30);
            key[qual] = 1'b1; ciclos(1);
            key[qual] = 1'b0; ciclos(2);
            key[qual] = 1'b1;
        end
    endtask

    task checa(input [8*24-1:0] nome, input [127:0] l1, input [127:0] l2);
        begin
            if (!display_on || linha(0) !== l1 || linha(1) !== l2) begin
                erros = erros + 1;
                $display("ERRO  %0s", nome);
                $display("      obtido   |%s|%s|%s", linha(0), linha(1), display_on ? "" : " (display apagado)");
                $display("      esperado |%s|%s|", l1, l2);
            end else
                $display("ok    %0s |%s|%s|", nome, linha(0), linha(1));
        end
    endtask

    task enviar(input [17:0] instrucao, input [8*24-1:0] nome, input [127:0] l1, input [127:0] l2);
        begin
            @(negedge clk) sw = instrucao;
            aperta(0);
            espera_tela(S_READY);
            checa(nome, l1, l2);
        end
    endtask

    task ligar;
        begin
            aperta(1);
            espera_tela(S_READY);
        end
    endtask

    initial begin
        // Espera o reset e a inicializacao do LCD
        ciclos(5000);
        if (display_on) begin
            erros = erros + 1;
            $display("ERRO: display aceso antes de ligar");
        end

        ligar;
        checa("0  ligar", "------    [----]", "          +00000");

        enviar(18'b000_0010_0000_0_001100, "1  LOAD R2, 12",       "LOAD      [0010]", "          +00012");
        enviar(18'b001_0001_0000_0010_000, "2  ADD R1, R0, R2",    "ADD       [0001]", "          +00012");
        enviar(18'b100_0011_0001_0_010100, "3  SUBI R3, R1, 20",   "SUBI      [0011]", "          -00008");
        enviar(18'b101_0100_0011_1_000101, "4  MUL R4, R3, -5",    "MUL       [0100]", "          +00040");
        enviar(18'b011_0101_0100_0001_000, "5  SUB R5, R4, R1",    "SUB       [0101]", "          +00028");
        enviar(18'b010_0110_0101_1_111111, "6  ADDI R6, R5, -63",  "ADDI      [0110]", "          -00035");
        enviar(18'b111_0000_0010_0_000000, "7  DISPLAY R2",        "DPL       [0010]", "          +00012");
        enviar(18'b000_0111_0000_0_111111, "8  LOAD R7, 63",       "LOAD      [0111]", "          +00063");
        enviar(18'b101_0111_0111_0_111111, "9  MUL R7, R7, 63",    "MUL       [0111]", "          +03969");
        enviar(18'b101_0111_0111_0_111111, "10 MUL R7, R7, 63",    "MUL       [0111]", "          -12097");
        if (ledg[6] !== 1'b1) begin
            erros = erros + 1;
            $display("ERRO  10 LEDG[6] (overflow) apagado");
        end
        enviar(18'b110_0000_0000_0_000000, "11 CLEAR",             "CLEAR           ", "                ");
        enviar(18'b111_0000_0111_0_000000, "12 DISPLAY R7",        "DPL       [0111]", "          +00000");

        aperta(1);
        espera_tela(S_OFF);
        if (display_on || linha(0) !== "                " || linha(1) !== "                " || ledg[8] !== 1'b0) begin
            erros = erros + 1;
            $display("ERRO  13 desligar: display_on=%b system_on=%b |%s|%s|", display_on, ledg[8], linha(0), linha(1));
        end else
            $display("ok    13 desligar (display apagado)");

        ligar;
        checa("14 ligar de novo", "------    [----]", "          +00000");
        enviar(18'b111_0000_0010_0_000000, "14 DISPLAY R2",        "DPL       [0010]", "          +00000");

        if (erros == 0) $display("tb_top: OK");
        else            $display("tb_top: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
`default_nettype wire
