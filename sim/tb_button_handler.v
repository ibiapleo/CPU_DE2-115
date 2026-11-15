`timescale 1ns/1ps
`default_nettype none
module tb_button_handler;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    integer erros = 0;

    localparam N = 10;   // DEBOUNCE_CYCLES do teste

    reg  rst = 1'b1;
    reg  btn_n = 1'b1;
    wire released;

    button_handler #(.DEBOUNCE_CYCLES(N)) dut (
        .clk(clk), .rst(rst), .btn_n(btn_n), .released(released)
    );

    // Monitor: conta os pulsos e confere que cada um tem 1 ciclo e sai so depois
    // de o botao ficar solto (btn_n = 1) por pelo menos N ciclos seguidos
    integer pulsos = 0;
    integer solto_ha = 0;
    reg     ant_released = 1'b0;
    always @(posedge clk) begin
        if (released) begin
            pulsos = pulsos + 1;
            if (rst) begin
                erros = erros + 1; $display("ERRO: pulso durante o reset (t=%0t)", $time);
            end
            if (ant_released) begin
                erros = erros + 1; $display("ERRO: pulso com mais de 1 ciclo (t=%0t)", $time);
            end
            if (solto_ha < N || solto_ha > N + 5) begin
                erros = erros + 1;
                $display("ERRO: pulso com o botao solto ha %0d ciclos, esperado entre %0d e %0d (t=%0t)",
                         solto_ha, N, N + 5, $time);
            end
        end
        ant_released <= released;
        solto_ha = btn_n ? solto_ha + 1 : 0;
    end

    task ciclos;
        input integer n;
        begin
            repeat (n) @(negedge clk);
        end
    endtask

    // Botao: btn_n muda sempre na borda de descida
    task segura;
        input integer n;
        begin
            btn_n = 1'b0;
            ciclos(n);
            btn_n = 1'b1;
        end
    endtask

    // Quica: alterna o botao com os tempos dados (em ciclos), comecando apertado
    task quica;
        input integer a, b, c, d;
        begin
            btn_n = 1'b0; ciclos(a);
            btn_n = 1'b1; ciclos(b);
            btn_n = 1'b0; ciclos(c);
            btn_n = 1'b1; ciclos(d);
        end
    endtask

    task checa;
        input integer esperado;
        input integer antes;
        input [8*40-1:0] nome;
        begin
            if (pulsos - antes !== esperado) begin
                erros = erros + 1;
                $display("ERRO: %0s: %0d pulso(s), esperado %0d", nome, pulsos - antes, esperado);
            end
            else
                $display("ok  %0s (%0d pulso(s))", nome, esperado);
        end
    endtask

    integer n0, k;
    initial begin
        $dumpfile("tb_button_handler.vcd");
        $dumpvars(0, tb_button_handler);

        // Reset com o botao solto
        ciclos(5);
        rst = 1'b0;
        ciclos(50);
        checa(0, 0, "reset sem pulso falso");

        // Aperto limpo
        n0 = pulsos;
        segura(30);
        if (pulsos !== n0) begin erros = erros + 1; $display("ERRO: pulso enquanto o botao estava apertado"); end
        ciclos(40);
        checa(1, n0, "aperto limpo");

        // Aperto com quique ao apertar e ao soltar
        n0 = pulsos;
        quica(1, 2, 1, 1);
        segura(30);
        quica(2, 1, 1, 2);
        ciclos(40);
        checa(1, n0, "aperto com quique");

        // Ruido mais curto que o debounce nao conta
        n0 = pulsos;
        segura(N / 2);
        ciclos(40);
        segura(2);
        ciclos(40);
        checa(0, n0, "ruido curto ignorado");

        // Soltura falsa no meio do aperto (menor que o debounce) nao gera pulso
        n0 = pulsos;
        segura(30);
        ciclos(N / 2);
        segura(30);
        ciclos(40);
        checa(1, n0, "soltura curta no meio do aperto");

        // Aperto longo gera um unico pulso
        n0 = pulsos;
        segura(2000);
        ciclos(40);
        checa(1, n0, "aperto longo");

        // Varios apertos seguidos
        n0 = pulsos;
        for (k = 0; k < 5; k = k + 1) begin
            segura(20 + k);
            ciclos(25);
        end
        ciclos(20);
        checa(5, n0, "5 apertos seguidos");

        // Reset no meio da soltura cancela o pulso
        n0 = pulsos;
        segura(30);
        ciclos(N / 2);
        rst = 1'b1;
        ciclos(3);
        rst = 1'b0;
        ciclos(40);
        checa(0, n0, "reset durante a soltura");

        if (erros == 0) $display("tb_button_handler: OK");
        else            $display("tb_button_handler: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
`default_nettype wire
