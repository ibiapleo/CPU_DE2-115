`timescale 1ns/1ps
`default_nettype none
`include "defines.vh"
module tb_integracao_ab;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    integer erros = 0;

    localparam DB          = 10;    // DEBOUNCE_CYCLES do teste
    localparam LCD_CICLOS  = 200;
    localparam LCD_INICIAL = 100;
    localparam TIMEOUT     = 5000;

    localparam S_OFF = 4'd0, S_SHOW = 4'd2, S_WAIT_LCD = 4'd3, S_READY = 4'd4,
               S_FETCH = 4'd5, S_DECODE = 4'd6, S_WAIT_OFF = 4'd11;

    reg         rst = 1'b1;
    reg  [1:0]  key = 2'b11;   // key[1] = Ligar, key[0] = Enviar (0 = apertado)
    reg  [17:0] sw = 18'd0;

    wire        btn_ligar, btn_enviar;
    wire [3:0]  mem_rd_addr_a, mem_rd_addr_b, mem_wr_addr;
    wire [15:0] mem_rd_data_a, mem_rd_data_b, mem_wr_data;
    wire        mem_we, mem_clear;
    wire [2:0]  alu_op;
    wire [15:0] alu_a, alu_b, alu_result;
    wire [1:0]  disp_kind;
    wire [2:0]  disp_opcode;
    wire [3:0]  disp_reg;
    wire [15:0] disp_value;
    wire        lcd_refresh, lcd_off, system_on;
    wire [3:0]  dbg_state;
    reg         lcd_busy = 1'b0, lcd_done = 1'b0;

    button_handler #(.DEBOUNCE_CYCLES(DB)) u_btn_ligar  (.clk(clk), .rst(rst), .btn_n(key[1]), .released(btn_ligar));
    button_handler #(.DEBOUNCE_CYCLES(DB)) u_btn_enviar (.clk(clk), .rst(rst), .btn_n(key[0]), .released(btn_enviar));

    module_mini_cpu u_cpu (
        .clk(clk), .rst(rst),
        .btn_ligar(btn_ligar), .btn_enviar(btn_enviar), .sw(sw),
        .mem_rd_addr_a(mem_rd_addr_a), .mem_rd_addr_b(mem_rd_addr_b),
        .mem_rd_data_a(mem_rd_data_a), .mem_rd_data_b(mem_rd_data_b),
        .mem_we(mem_we), .mem_wr_addr(mem_wr_addr), .mem_wr_data(mem_wr_data),
        .mem_clear(mem_clear),
        .alu_op(alu_op), .alu_a(alu_a), .alu_b(alu_b), .alu_result(alu_result),
        .disp_kind(disp_kind), .disp_opcode(disp_opcode), .disp_reg(disp_reg),
        .disp_value(disp_value),
        .lcd_refresh(lcd_refresh), .lcd_off(lcd_off),
        .lcd_busy(lcd_busy), .lcd_done(lcd_done),
        .system_on(system_on), .dbg_state(dbg_state)
    );

    tb_ab_mem u_mem (
        .clk(clk), .rst(rst), .clear(mem_clear),
        .we(mem_we), .wr_addr(mem_wr_addr), .wr_data(mem_wr_data),
        .rd_addr_a(mem_rd_addr_a), .rd_addr_b(mem_rd_addr_b),
        .rd_data_a(mem_rd_data_a), .rd_data_b(mem_rd_data_b)
    );

    tb_ab_alu u_alu (.op(alu_op), .a(alu_a), .b(alu_b), .result(alu_result));

    // LCD falso: fica ocupado LCD_CICLOS ciclos a cada pedido e depois pulsa done
    integer lcd_cnt = 0;
    integer n_refresh = 0, n_off = 0, n_fetch = 0;
    reg [1:0]  snap_kind;
    reg [2:0]  snap_opcode;
    reg [3:0]  snap_reg;
    reg [15:0] snap_value;
    reg [3:0]  ant_state = 4'd0;

    always @(posedge clk) begin
        lcd_done <= 1'b0;
        if (rst) begin
            lcd_busy <= 1'b1;
            lcd_cnt  <= LCD_INICIAL;
        end
        else if (lcd_busy) begin
            if (lcd_cnt == 0) begin
                lcd_busy <= 1'b0;
                lcd_done <= 1'b1;
            end
            else
                lcd_cnt <= lcd_cnt - 1;
        end
        else if (lcd_refresh || lcd_off) begin
            lcd_busy <= 1'b1;
            lcd_cnt  <= LCD_CICLOS;
        end

        if (!rst && lcd_refresh) begin
            n_refresh   <= n_refresh + 1;
            snap_kind   <= disp_kind;
            snap_opcode <= disp_opcode;
            snap_reg    <= disp_reg;
            snap_value  <= disp_value;
        end
        if (!rst && lcd_off)
            n_off <= n_off + 1;
        if (!rst && dbg_state == S_FETCH && ant_state != S_FETCH)
            n_fetch <= n_fetch + 1;
        ant_state <= dbg_state;
    end

    task espera_estado;
        input [3:0] estado;
        integer k;
        begin
            k = 0;
            while (dbg_state !== estado && k < TIMEOUT) begin
                @(posedge clk); #1;
                k = k + 1;
            end
            if (k >= TIMEOUT) begin
                erros = erros + 1;
                $display("ERRO: timeout esperando o estado %0d (parado no %0d, t=%0t)", estado, dbg_state, $time);
            end
        end
    endtask

    task ciclos;
        input integer n;
        begin
            repeat (n) @(negedge clk);
        end
    endtask

    // Aperta e solta com quique nas duas pontas
    task aperta;
        input integer qual;   // 1 = Ligar, 0 = Enviar
        input integer n;
        begin
            @(negedge clk);
            key[qual] = 1'b0; ciclos(2);
            key[qual] = 1'b1; ciclos(1);
            key[qual] = 1'b0; ciclos(1);
            key[qual] = 1'b1; ciclos(2);
            key[qual] = 1'b0; ciclos(n);
            key[qual] = 1'b1; ciclos(1);
            key[qual] = 1'b0; ciclos(2);
            key[qual] = 1'b1; ciclos(1);
            key[qual] = 1'b0; ciclos(1);
            key[qual] = 1'b1;
        end
    endtask

    task enviar;
        input [17:0] instrucao;
        integer f0, r0;
        begin
            espera_estado(S_READY);
            f0 = n_fetch;
            r0 = n_refresh;
            @(negedge clk) sw = instrucao;
            aperta(0, 30);
            espera_estado(S_FETCH);
            espera_estado(S_READY);
            if (n_fetch !== f0 + 1 || n_refresh !== r0 + 1) begin
                erros = erros + 1;
                $display("ERRO: um aperto de Enviar gerou %0d instrucao(oes) e %0d tela(s)", n_fetch - f0, n_refresh - r0);
            end
        end
    endtask

    task ligar;
        integer r0;
        begin
            espera_estado(S_OFF);
            r0 = n_refresh;
            aperta(1, 30);
            espera_estado(S_READY);
            if (n_refresh !== r0 + 1) begin
                erros = erros + 1;
                $display("ERRO: ligar gerou %0d tela(s)", n_refresh - r0);
            end
        end
    endtask

    task desligar;
        integer o0;
        begin
            espera_estado(S_READY);
            o0 = n_off;
            aperta(1, 30);
            espera_estado(S_OFF);
            if (n_off !== o0 + 1) begin
                erros = erros + 1;
                $display("ERRO: desligar gerou %0d lcd_off", n_off - o0);
            end
        end
    endtask

    task checa_tela;
        input [1:0]         e_kind;
        input [2:0]         e_opcode;
        input [3:0]         e_reg;
        input signed [15:0] e_value;
        input [8*32-1:0]    nome;
        begin
            if (snap_kind !== e_kind || snap_opcode !== e_opcode ||
                snap_reg !== e_reg || snap_value !== e_value) begin
                erros = erros + 1;
                $display("ERRO: %0s", nome);
                $display("      obtido   kind=%0d op=%b reg=%0d valor=%0d", snap_kind, snap_opcode, snap_reg, $signed(snap_value));
                $display("      esperado kind=%0d op=%b reg=%0d valor=%0d", e_kind, e_opcode, e_reg, e_value);
            end
            else
                $display("ok  %0s", nome);
        end
    endtask

    task checa_tudo_zero;
        input [8*32-1:0] nome;
        integer r;
        begin
            for (r = 0; r < 16; r = r + 1)
                if (u_mem.regs[r] !== 16'd0) begin
                    erros = erros + 1;
                    $display("ERRO: %0s: R%0d = %0d, esperado 0", nome, r, $signed(u_mem.regs[r]));
                end
        end
    endtask

    integer f0, o0;
    initial begin
        $dumpfile("tb_integracao_ab.vcd");
        $dumpvars(0, tb_integracao_ab);

        ciclos(5);
        rst = 1'b0;

        @(negedge clk) sw = 18'b000_0001_0000_0_000001;
        aperta(0, 30);
        ciclos(60);
        if (dbg_state !== S_OFF || n_fetch !== 0) begin
            erros = erros + 1; $display("ERRO: Enviar com o sistema desligado mudou algo");
        end
        else $display("ok  Enviar ignorado com o sistema desligado");

        ligar;
        checa_tela(`DISP_INICIAL, 3'b000, 0, 0, "0  ligar (tela inicial)");
        enviar(18'b000_0010_0000_0_001100); checa_tela(`DISP_RESULTADO, `OP_LOAD,    2,      12, "1  LOAD R2, 12");
        enviar(18'b001_0001_0000_0010_000); checa_tela(`DISP_RESULTADO, `OP_ADD,     1,      12, "2  ADD R1, R0, R2");
        enviar(18'b100_0011_0001_0_010100); checa_tela(`DISP_RESULTADO, `OP_SUBI,    3,      -8, "3  SUBI R3, R1, 20");
        enviar(18'b101_0100_0011_1_000101); checa_tela(`DISP_RESULTADO, `OP_MUL,     4,      40, "4  MUL R4, R3, -5");
        enviar(18'b011_0101_0100_0001_000); checa_tela(`DISP_RESULTADO, `OP_SUB,     5,      28, "5  SUB R5, R4, R1");
        enviar(18'b010_0110_0101_1_111111); checa_tela(`DISP_RESULTADO, `OP_ADDI,    6,     -35, "6  ADDI R6, R5, -63");
        enviar(18'b111_0000_0010_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 2,      12, "7  DISPLAY R2");
        enviar(18'b000_0111_0000_0_111111); checa_tela(`DISP_RESULTADO, `OP_LOAD,    7,      63, "8  LOAD R7, 63");
        enviar(18'b101_0111_0111_0_111111); checa_tela(`DISP_RESULTADO, `OP_MUL,     7,    3969, "9  MUL R7, R7, 63");
        enviar(18'b101_0111_0111_0_111111); checa_tela(`DISP_RESULTADO, `OP_MUL,     7,  -12097, "10 MUL R7 (overflow)");
        enviar(18'b110_0000_0000_0_000000); checa_tela(`DISP_SO_NOME,   `OP_CLEAR,   0,       0, "11 CLEAR");
        enviar(18'b111_0000_0111_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 7,       0, "12 DISPLAY R7");
        enviar(18'b000_0011_0000_0_000111);   // deixa R3 = 7 para ver o desligar zerar
        desligar;
        checa_tudo_zero("13 desligar");
        $display("ok  13 desligar");
        ligar;
        enviar(18'b111_0000_0010_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 2,       0, "14 ligar + DISPLAY R2");

        espera_estado(S_READY);
        f0 = n_fetch;
        @(negedge clk) sw = 18'b000_1000_0000_0_000011;   // LOAD R8, 3
        aperta(0, 2000);
        espera_estado(S_FETCH);
        espera_estado(S_READY);
        ciclos(300);
        if (n_fetch !== f0 + 1) begin erros = erros + 1; $display("ERRO: Enviar seguro executou %0d vezes", n_fetch - f0); end
        else $display("ok  Enviar seguro executa uma vez so");

        f0 = n_fetch;
        @(negedge clk) sw = 18'b000_1001_0000_0_000101;   // LOAD R9, 5
        aperta(0, 30);
        espera_estado(S_WAIT_LCD);
        @(negedge clk) sw = 18'b000_1001_0000_0_000110;   // LOAD R9, 6 (nao pode entrar)
        aperta(0, 30);
        espera_estado(S_READY);
        ciclos(100);
        if (n_fetch !== f0 + 1 || u_mem.regs[9] !== 16'd5) begin
            erros = erros + 1; $display("ERRO: Enviar com o LCD ocupado foi aceito (instrucoes=%0d, R9=%0d)", n_fetch - f0, u_mem.regs[9]);
        end
        else $display("ok  Enviar ignorado com o LCD ocupado");

        o0 = n_off;
        @(negedge clk) sw = 18'b000_1010_0000_0_010101;   // LOAD R10, 21
        aperta(0, 30);
        espera_estado(S_WAIT_LCD);
        aperta(1, 30);
        espera_estado(S_OFF);
        if (n_off !== o0 + 1 || snap_reg !== 4'd10 || snap_value !== 16'd21) begin
            erros = erros + 1; $display("ERRO: Ligar no meio da escrita do LCD");
        end
        else $display("ok  Ligar no meio da escrita: mostra e depois desliga");
        checa_tudo_zero("Ligar no meio");

        ligar;
        o0 = n_off;
        aperta(1, 30);
        espera_estado(S_WAIT_OFF);
        aperta(1, 30);
        espera_estado(S_OFF);
        ciclos(300);
        if (dbg_state !== S_OFF || n_off !== o0 + 1) begin
            erros = erros + 1; $display("ERRO: Ligar durante o desligamento nao foi ignorado");
        end
        else $display("ok  Ligar ignorado durante o desligamento");

        if (erros == 0) $display("tb_integracao_ab: OK");
        else            $display("tb_integracao_ab: %0d ERRO(S)", erros);
        $finish;
    end

    initial begin
        #20_000_000;
        $display("ERRO: simulacao travou (timeout global)");
        $display("tb_integracao_ab: FALHOU");
        $finish;
    end
endmodule

module tb_ab_mem (
    input  wire        clk,
    input  wire        rst,
    input  wire        clear,
    input  wire        we,
    input  wire [3:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [3:0]  rd_addr_a,
    input  wire [3:0]  rd_addr_b,
    output wire [15:0] rd_data_a,
    output wire [15:0] rd_data_b
);
    reg [15:0] regs [0:15];
    integer i;
    always @(posedge clk) begin
        if (rst || clear)
            for (i = 0; i < 16; i = i + 1) regs[i] <= 16'd0;
        else if (we)
            regs[wr_addr] <= wr_data;
    end
    assign rd_data_a = regs[rd_addr_a];
    assign rd_data_b = regs[rd_addr_b];
endmodule

module tb_ab_alu (
    input  wire [2:0]  op,
    input  wire [15:0] a,
    input  wire [15:0] b,
    output reg  [15:0] result
);
    always @(*) begin
        case (op)
            `OP_LOAD:             result = b;
            `OP_ADD,  `OP_ADDI:   result = a + b;
            `OP_SUB,  `OP_SUBI:   result = a - b;
            `OP_MUL:              result = a * b;   // 16 bits de baixo
            default:              result = 16'd0;
        endcase
    end
endmodule
`default_nettype wire
