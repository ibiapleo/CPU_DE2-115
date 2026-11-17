// =============================================================================
// tb_lcd_driver.v  -  testbench ampliado da Parte D (lcd_driver)
//
// "LCD falso": a cada DESCIDA de lcd_en anota {RS, DATA} e o ciclo em que
// aconteceu, como o LCD real faria. Depois compara com o esperado.
//
// O que e conferido:
//   - sequencia de bytes (inicializacao, refresh com e sem 0x0C, power_off)
//   - TEXTOS DIFERENTES em cada refresh (a tela tem que atualizar de verdade)
//   - TEMPO: espera de ~1 ms depois de cada byte (2 ms depois do 0x01) e
//     espera inicial de 20 ms depois do reset
//   - EN com largura minima de ~1 us e RS/DATA estaveis antes e durante EN
//   - busy sobe logo apos o pedido; done dura 1 ciclo; done nunca com busy=1
//   - constantes: lcd_rw=0, lcd_on=1, lcd_blon=1; lcd_en=0 com o driver livre
//   - casos raros: screen mudando durante o busy, pedidos com busy=1 (ignorados),
//     refresh+power_off no mesmo ciclo (refresh tem prioridade), pedido no
//     primeiro ciclo livre, dois power_off seguidos, power_off logo apos o reset,
//     reset no meio de uma escrita, pedido durante a inicializacao
//
// Para testar com o clock real da placa, troque CLK_HZ_TB por 50_000_000
// (a simulacao fica MUITO mais lenta).
// =============================================================================
`timescale 1ns/1ps
module tb_lcd_driver;

    localparam CLK_HZ_TB   = 100_000;      // clock "lento": 1 ms = 100 ciclos
    localparam MIN_1US     = (CLK_HZ_TB / 1_000_000 < 1) ? 1 : (CLK_HZ_TB / 1_000_000);
    localparam CICLOS_1MS  = CLK_HZ_TB / 1000;
    localparam CICLOS_2MS  = CLK_HZ_TB / 500;
    localparam CICLOS_20MS = CLK_HZ_TB / 50;
    localparam FOLGA       = 2 * (CLK_HZ_TB / 1_000_000 + 1) + 16;   // tolerancia no tempo

    reg         clk       = 1'b0;
    reg         rst       = 1'b1;
    reg         refresh   = 1'b0;
    reg         power_off = 1'b0;
    reg [255:0] screen;

    wire        busy, done;
    wire        lcd_rs, lcd_rw, lcd_en, lcd_on, lcd_blon;
    wire [7:0]  lcd_data;

    lcd_driver #(.CLK_HZ(CLK_HZ_TB)) dut (
        .clk(clk), .rst(rst),
        .refresh(refresh), .power_off(power_off), .screen(screen),
        .busy(busy), .done(done),
        .lcd_data(lcd_data), .lcd_rs(lcd_rs), .lcd_rw(lcd_rw),
        .lcd_en(lcd_en), .lcd_on(lcd_on), .lcd_blon(lcd_blon)
    );

    always #10 clk = ~clk;                       // 50 MHz (so a escala de tempo)

    // ---------------- contadores e memoria do LCD falso ----------------
    integer     ciclo       = 0;                 // numero do ciclo de clock
    integer     errors      = 0;
    integer     ncap        = 0;                 // bytes anotados
    integer     ndone       = 0;                 // pulsos de done vistos
    integer     t_subida    = 0;                 // ciclo da ultima subida de EN
    integer     ult_mud     = 0;                 // ciclo da ultima mudanca de RS/DATA
    integer     t_rst_solto = 0;                 // ciclo em que o reset foi solto
    reg [8:0]   snap;                            // {RS, DATA} na subida de EN
    reg [8:0]   cap   [0:511];                   // {RS, DATA} de cada byte
    integer     t_cap [0:511];                   // ciclo de cada byte

    always @(posedge clk) ciclo = ciclo + 1;

    // quando RS/DATA mudam
    always @(lcd_data or lcd_rs) ult_mud = ciclo;

    // subida de EN: RS/DATA ja devem estar estaveis ha ~1 us
    always @(posedge lcd_en) begin
        if (rst === 1'b0) begin
            t_subida = ciclo;
            snap     = {lcd_rs, lcd_data};
            if (ciclo - ult_mud < MIN_1US) begin
                $display("ERRO: RS/DATA mudaram menos de %0d ciclo(s) antes de EN subir", MIN_1US);
                errors = errors + 1;
            end
        end
    end

    // descida de EN: e aqui que o LCD captura o byte
    always @(negedge lcd_en) begin
        if (rst === 1'b0) begin
            cap[ncap]   = {lcd_rs, lcd_data};
            t_cap[ncap] = ciclo;
            if ({lcd_rs, lcd_data} !== snap) begin
                $display("ERRO: RS/DATA mudaram enquanto EN estava alto (byte %0d)", ncap);
                errors = errors + 1;
            end
            if (ciclo - t_subida < MIN_1US) begin
                $display("ERRO: EN ficou alto por menos de %0d ciclo(s) (byte %0d)", MIN_1US, ncap);
                errors = errors + 1;
            end
            $display("ciclo %0d  byte #%0d  RS=%b  DATA=%h", ciclo, ncap, lcd_rs, lcd_data);
            ncap = ncap + 1;
        end
    end

    // ---------------- monitores de regras gerais ----------------
    reg const_err = 1'b0;
    reg done_d    = 1'b0;

    always @(posedge clk) begin
        done_d <= done;
        if (!const_err && (lcd_rw !== 1'b0 || lcd_on !== 1'b1 || lcd_blon !== 1'b1)) begin
            const_err = 1'b1;
            $display("ERRO: lcd_rw/lcd_on/lcd_blon deveriam ser 0/1/1");
            errors = errors + 1;
        end
        if (busy === 1'b0 && lcd_en !== 1'b0) begin
            $display("ERRO: lcd_en ativo com o driver livre (busy=0)");
            errors = errors + 1;
        end
        if (done === 1'b1 && busy !== 1'b0) begin
            $display("ERRO: done com busy=1");
            errors = errors + 1;
        end
        if (done === 1'b1 && done_d === 1'b1) begin
            $display("ERRO: done durou mais de 1 ciclo");
            errors = errors + 1;
        end
    end

    always @(posedge done) ndone = ndone + 1;

    // ---------------- tarefas de conferencia ----------------
    task check_byte(input integer pos, input rs, input [7:0] d);
        begin
            if (cap[pos] !== {rs, d}) begin
                $display("ERRO byte #%0d: obtido RS=%b DATA=%h | esperado RS=%b DATA=%h",
                         pos, cap[pos][8], cap[pos][7:0], rs, d);
                errors = errors + 1;
            end
        end
    endtask

    // 0x80 + 16 caracteres + 0xC0 + 16 caracteres (34 bytes) a partir de "inicio"
    task check_tela(input integer inicio, input [255:0] tela);
        integer i;
        begin
            check_byte(inicio, 1'b0, 8'h80);
            for (i = 0; i < 16; i = i + 1)
                check_byte(inicio + 1 + i, 1'b1, tela[255 - 8*i -: 8]);
            check_byte(inicio + 17, 1'b0, 8'hC0);
            for (i = 0; i < 16; i = i + 1)
                check_byte(inicio + 18 + i, 1'b1, tela[255 - 8*(i+16) -: 8]);
        end
    endtask

    // espera entre bytes consecutivos: >= 1 ms (>= 2 ms depois do 0x01)
    task check_tempos(input integer ini, input integer fim);
        integer i, gap, minimo;
        begin
            for (i = ini + 1; i <= fim; i = i + 1) begin
                gap    = t_cap[i] - t_cap[i-1];
                minimo = (cap[i-1] === 9'b0_0000_0001) ? CICLOS_2MS : CICLOS_1MS;
                if (gap < minimo || gap > minimo + FOLGA) begin
                    $display("ERRO tempo: entre os bytes #%0d e #%0d passaram %0d ciclos (esperado de %0d a %0d)",
                             i-1, i, gap, minimo, minimo + FOLGA);
                    errors = errors + 1;
                end
            end
        end
    endtask

    // inicializacao: 0x38, 0x08, 0x01, 0x06, com espera inicial de 20 ms
    task confere_init(input integer pos);
        begin
            check_byte(pos,     1'b0, 8'h38);
            check_byte(pos + 1, 1'b0, 8'h08);
            check_byte(pos + 2, 1'b0, 8'h01);
            check_byte(pos + 3, 1'b0, 8'h06);
            check_tempos(pos, pos + 3);
            if (t_cap[pos] - t_rst_solto < CICLOS_20MS) begin
                $display("ERRO: primeiro byte saiu %0d ciclos depois do reset (minimo %0d)",
                         t_cap[pos] - t_rst_solto, CICLOS_20MS);
                errors = errors + 1;
            end
        end
    endtask

    // ---------------- tarefas de estimulo ----------------
    // pulso de 1 ciclo em refresh e/ou power_off
    task pulso(input r, input p);
        begin
            @(posedge clk); refresh <= r;     power_off <= p;
            @(posedge clk); refresh <= 1'b0;  power_off <= 1'b0;
        end
    endtask

    task confere_busy_subiu;
        begin
            #1;
            if (busy !== 1'b1) begin
                $display("ERRO: busy nao subiu logo apos o pedido");
                errors = errors + 1;
            end
        end
    endtask

    task wait_done;
        begin
            @(posedge done);
            #1;
            if (busy !== 1'b0) begin
                $display("ERRO: busy deveria ser 0 quando done pulsa");
                errors = errors + 1;
            end
        end
    endtask

    task aplica_reset(input integer n);
        begin
            @(posedge clk); rst <= 1'b1;
            repeat (n) @(posedge clk);
            t_rst_solto = ciclo;
            rst <= 1'b0;
        end
    endtask

    // ---------------- roteiro ----------------
    reg [255:0] tela_a, tela_b, tela_c, tela_e;

    initial begin
        $dumpfile("lcd.vcd");
        $dumpvars(0, tb_lcd_driver);

        tela_a = {"ADD       [0001]", "          +00012"};
        tela_b = {"SUB       [0110]", "          -00345"};
        tela_c = {"CLEAR           ", "                "};
        tela_e = {16{8'h00, 8'hFF}};               // bytes extremos: 00 e FF
        screen = tela_a;

        // ---- 1) reset e inicializacao (bytes #0 a #3) ----
        repeat (5) @(posedge clk);
        t_rst_solto = ciclo;
        rst <= 1'b0;
        wait (busy === 1'b0);
        confere_init(0);

        // ---- 2) primeiro refresh: display apagado -> 0x0C antes da tela (#4 a #38) ----
        screen = tela_a;
        pulso(1'b1, 1'b0);  confere_busy_subiu;  wait_done;
        check_byte(4, 1'b0, 8'h0C);
        check_tela(5, tela_a);
        check_tempos(4, 38);

        // ---- 3) segundo refresh com OUTRO texto: sem 0x0C (#39 a #72) ----
        screen = tela_b;
        pulso(1'b1, 1'b0);  confere_busy_subiu;  wait_done;
        check_tela(39, tela_b);
        check_tempos(39, 72);

        // ---- 4) screen muda durante o busy: vale a copia do refresh (#73 a #106) ----
        screen = tela_c;
        pulso(1'b1, 1'b0);  confere_busy_subiu;
        screen = tela_e;                           // muda a entrada com o driver ocupado
        wait_done;
        check_tela(73, tela_c);
        check_tempos(73, 106);

        // ---- 5) pedidos com busy=1 sao ignorados (#107 a #140) ----
        screen = tela_a;
        pulso(1'b1, 1'b0);  confere_busy_subiu;
        repeat (5) @(posedge clk);
        pulso(1'b1, 1'b0);                         // refresh com busy=1
        repeat (5) @(posedge clk);
        pulso(1'b0, 1'b1);                         // power_off com busy=1
        wait_done;
        check_tela(107, tela_a);
        check_tempos(107, 140);
        repeat (3 * CICLOS_1MS) @(posedge clk);
        if (ncap !== 141) begin
            $display("ERRO: pedidos com busy=1 geraram bytes extras (total %0d, esperado 141)", ncap);
            errors = errors + 1;
        end

        // ---- 6) refresh e power_off no mesmo ciclo: refresh tem prioridade (#141 a #174) ----
        screen = tela_b;
        pulso(1'b1, 1'b1);  confere_busy_subiu;  wait_done;
        check_tela(141, tela_b);
        check_tempos(141, 174);

        // ---- 7) pedido no primeiro ciclo livre, logo apos o done (#175 a #208) ----
        screen = tela_c;
        pulso(1'b1, 1'b0);  confere_busy_subiu;  wait_done;
        check_tela(175, tela_c);
        check_tempos(175, 208);

        // ---- 8) power_off e outro power_off logo em seguida (#209 a #212) ----
        pulso(1'b0, 1'b1);  confere_busy_subiu;  wait_done;
        check_byte(209, 1'b0, 8'h01);
        check_byte(210, 1'b0, 8'h08);
        check_tempos(209, 210);
        pulso(1'b0, 1'b1);  confere_busy_subiu;  wait_done;
        check_byte(211, 1'b0, 8'h01);
        check_byte(212, 1'b0, 8'h08);
        check_tempos(211, 212);

        // ---- 9) refresh depois de apagar: volta o 0x0C; bytes extremos (#213 a #247) ----
        screen = tela_e;
        pulso(1'b1, 1'b0);  confere_busy_subiu;  wait_done;
        check_byte(213, 1'b0, 8'h0C);
        check_tela(214, tela_e);
        check_tempos(213, 247);

        // ---- 10) reset no meio de uma escrita (#248 a #257 saem, depois reinicializa) ----
        screen = tela_a;
        pulso(1'b1, 1'b0);  confere_busy_subiu;
        wait (ncap == 258);                        // 10 bytes ja enviados
        aplica_reset(3);
        wait (busy === 1'b0);
        confere_init(258);                         // #258 a #261
        // depois do reset o display esta apagado: o proximo refresh manda 0x0C (#262 a #296)
        screen = tela_a;
        pulso(1'b1, 1'b0);  confere_busy_subiu;  wait_done;
        check_byte(262, 1'b0, 8'h0C);
        check_tela(263, tela_a);
        check_tempos(262, 296);

        // ---- 11) power_off logo apos o reset, sem refresh antes (#297 a #302) ----
        aplica_reset(3);
        wait (busy === 1'b0);
        confere_init(297);                         // #297 a #300
        pulso(1'b0, 1'b1);  confere_busy_subiu;  wait_done;
        check_byte(301, 1'b0, 8'h01);
        check_byte(302, 1'b0, 8'h08);
        check_tempos(301, 302);

        // ---- 12) pedido durante a inicializacao (busy=1): ignorado (#303 a #306) ----
        aplica_reset(3);
        repeat (5) @(posedge clk);
        pulso(1'b1, 1'b0);
        wait (busy === 1'b0);
        confere_init(303);
        repeat (3 * CICLOS_1MS) @(posedge clk);

        // ---- totais ----
        if (ncap !== 307) begin
            $display("ERRO: total de bytes = %0d (esperado 307)", ncap);
            errors = errors + 1;
        end
        if (ndone !== 11) begin
            $display("ERRO: total de pulsos de done = %0d (esperado 11)", ndone);
            errors = errors + 1;
        end

        if (errors == 0) $display("=== TESTE OK: todos os bytes, tempos e regras batem ===");
        else             $display("=== %0d ERRO(S) ===", errors);
        $finish;
    end

    // trava de seguranca (caso algo fique esperando para sempre)
    initial begin
        #(1500 * CICLOS_1MS * 20);
        $display("TIMEOUT: a simulacao travou esperando algum evento");
        $finish;
    end

endmodule
