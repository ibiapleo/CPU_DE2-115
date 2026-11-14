`timescale 1ns/1ps
`default_nettype none
`include "defines.vh"
module tb_module_mini_cpu;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    integer erros = 0;

    localparam LCD_CICLOS  = 12;   // ciclos ocupado por pedido
    localparam LCD_INICIAL = 40;   // ciclos ocupado apos o reset
    localparam TIMEOUT     = 5000;

    localparam S_OFF = 4'd0, S_POWER_ON = 4'd1, S_SHOW = 4'd2, S_WAIT_LCD = 4'd3,
               S_READY = 4'd4, S_FETCH = 4'd5, S_DECODE = 4'd6, S_EXECUTE = 4'd7,
               S_WRITEBACK = 4'd8, S_POWER_OFF = 4'd9, S_SHOW_OFF = 4'd10, S_WAIT_OFF = 4'd11;

    reg         rst = 1'b1;
    reg         btn_ligar = 1'b0, btn_enviar = 1'b0;
    reg  [17:0] sw = 18'd0;

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

    module_mini_cpu dut (
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

    tb_mem_model u_mem (
        .clk(clk), .rst(rst), .clear(mem_clear),
        .we(mem_we), .wr_addr(mem_wr_addr), .wr_data(mem_wr_data),
        .rd_addr_a(mem_rd_addr_a), .rd_addr_b(mem_rd_addr_b),
        .rd_data_a(mem_rd_data_a), .rd_data_b(mem_rd_data_b)
    );

    tb_alu_model u_alu (.op(alu_op), .a(alu_a), .b(alu_b), .result(alu_result));

    // LCD falso: ao receber refresh/off fica ocupado LCD_CICLOS ciclos e depois pulsa done
    integer lcd_cnt = 0;
    integer n_refresh = 0, n_off = 0;
    reg [1:0]  snap_kind;
    reg [2:0]  snap_opcode;
    reg [3:0]  snap_reg;
    reg [15:0] snap_value;

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
    end

    // Monitores que rodam a simulacao inteira
    reg        ant_we = 0, ant_clear = 0, ant_refresh = 0, ant_off = 0;
    reg [24:0] ant_disp = 0;
    reg        ant_busy = 0;
    always @(posedge clk) begin
        if (!rst) begin
            if (mem_we && ant_we)           begin erros = erros + 1; $display("ERRO: mem_we ficou em 1 por mais de 1 ciclo (t=%0t)", $time); end
            if (mem_clear && ant_clear)     begin erros = erros + 1; $display("ERRO: mem_clear ficou em 1 por mais de 1 ciclo (t=%0t)", $time); end
            if (lcd_refresh && ant_refresh) begin erros = erros + 1; $display("ERRO: lcd_refresh ficou em 1 por mais de 1 ciclo (t=%0t)", $time); end
            if (lcd_off && ant_off)         begin erros = erros + 1; $display("ERRO: lcd_off ficou em 1 por mais de 1 ciclo (t=%0t)", $time); end
            if ((lcd_refresh || lcd_off) && lcd_busy) begin
                erros = erros + 1; $display("ERRO: pedido ao LCD com lcd_busy = 1 (t=%0t)", $time);
            end
            if (ant_busy && lcd_busy && {disp_kind, disp_opcode, disp_reg, disp_value} !== ant_disp) begin
                erros = erros + 1; $display("ERRO: disp_* mudou com o LCD ocupado (t=%0t)", $time);
            end
            if (system_on !== (dbg_state >= S_POWER_ON && dbg_state <= S_WRITEBACK)) begin
                erros = erros + 1; $display("ERRO: system_on=%b no estado %0d (t=%0t)", system_on, dbg_state, $time);
            end
        end
        ant_we      <= mem_we;
        ant_clear   <= mem_clear;
        ant_refresh <= lcd_refresh;
        ant_off     <= lcd_off;
        ant_busy    <= lcd_busy;
        ant_disp    <= {disp_kind, disp_opcode, disp_reg, disp_value};
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
            repeat (n) @(posedge clk);
            #1;
        end
    endtask

    // Botoes: pulso de 1 ciclo, mudado na borda de descida
    task solta_ligar;
        begin
            @(negedge clk) btn_ligar = 1'b1;
            @(negedge clk) btn_ligar = 1'b0;
        end
    endtask

    task solta_enviar;
        begin
            @(negedge clk) btn_enviar = 1'b1;
            @(negedge clk) btn_enviar = 1'b0;
        end
    endtask

    // Envia uma instrucao a partir do READY e espera a tela nova terminar
    task enviar;
        input [17:0] instrucao;
        integer n0;
        begin
            espera_estado(S_READY);
            n0 = n_refresh;
            @(negedge clk) sw = instrucao;
            solta_enviar;
            espera_estado(S_FETCH);
            espera_estado(S_READY);
            if (n_refresh !== n0 + 1) begin
                erros = erros + 1;
                $display("ERRO: esperava 1 lcd_refresh, vieram %0d", n_refresh - n0);
            end
        end
    endtask

    task ligar;
        integer n0;
        begin
            n0 = n_refresh;
            solta_ligar;
            espera_estado(S_READY);
            if (n_refresh !== n0 + 1) begin
                erros = erros + 1;
                $display("ERRO: ligar deveria gerar 1 lcd_refresh, vieram %0d", n_refresh - n0);
            end
        end
    endtask

    task desligar;
        integer n0;
        begin
            espera_estado(S_READY);
            n0 = n_off;
            solta_ligar;
            espera_estado(S_OFF);
            if (n_off !== n0 + 1) begin
                erros = erros + 1;
                $display("ERRO: desligar deveria gerar 1 lcd_off, vieram %0d", n_off - n0);
            end
        end
    endtask

    // Compara o que foi mandado ao LCD no ultimo refresh
    task checa_tela;
        input [1:0]         e_kind;
        input [2:0]         e_opcode;
        input [3:0]         e_reg;
        input signed [15:0] e_value;
        input [8*24-1:0]    nome;
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

    task checa_reg;
        input [3:0]         r;
        input signed [15:0] e_value;
        begin
            if (u_mem.regs[r] !== e_value) begin
                erros = erros + 1;
                $display("ERRO: R%0d = %0d, esperado %0d", r, $signed(u_mem.regs[r]), e_value);
            end
        end
    endtask

    task checa_tudo_zero;
        input [8*24-1:0] nome;
        integer r;
        begin
            for (r = 0; r < 16; r = r + 1)
                if (u_mem.regs[r] !== 16'd0) begin
                    erros = erros + 1;
                    $display("ERRO: %0s: R%0d = %0d, esperado 0", nome, r, $signed(u_mem.regs[r]));
                end
        end
    endtask

    integer n0;
    initial begin
        $dumpfile("tb_module_mini_cpu.vcd");
        $dumpvars(0, tb_module_mini_cpu);

        ciclos(5);
        @(negedge clk) rst = 1'b0;

        // Enviar com o sistema desligado e ignorado
        ciclos(3);
        n0 = n_refresh;
        @(negedge clk) sw = 18'b000_0001_0000_0_000001;
        solta_enviar;
        ciclos(30);
        if (dbg_state !== S_OFF || n_refresh !== n0) begin
            erros = erros + 1; $display("ERRO: Enviar com o sistema desligado mudou algo");
        end
        else $display("ok  Enviar ignorado com o sistema desligado");

        // Sequencia de testes esperados
        ligar;
        checa_tela(`DISP_INICIAL, 3'b000, 0, 0, "0  ligar (tela inicial)");
        checa_tudo_zero("0  ligar");

        enviar(18'b000_0010_0000_0_001100); checa_tela(`DISP_RESULTADO, `OP_LOAD,    2,      12, "1  LOAD R2, 12");
        enviar(18'b001_0001_0000_0010_000); checa_tela(`DISP_RESULTADO, `OP_ADD,     1,      12, "2  ADD R1, R0, R2");
        enviar(18'b100_0011_0001_0_010100); checa_tela(`DISP_RESULTADO, `OP_SUBI,    3,      -8, "3  SUBI R3, R1, 20");
        enviar(18'b101_0100_0011_1_000101); checa_tela(`DISP_RESULTADO, `OP_MUL,     4,      40, "4  MUL R4, R3, -5");
        enviar(18'b011_0101_0100_0001_000); checa_tela(`DISP_RESULTADO, `OP_SUB,     5,      28, "5  SUB R5, R4, R1");
        enviar(18'b010_0110_0101_1_111111); checa_tela(`DISP_RESULTADO, `OP_ADDI,    6,     -35, "6  ADDI R6, R5, -63");
        checa_reg(0, 0); checa_reg(1, 12); checa_reg(2, 12); checa_reg(3, -8);
        checa_reg(4, 40); checa_reg(5, 28); checa_reg(6, -35);
        enviar(18'b111_0000_0010_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 2,      12, "7  DISPLAY R2");
        checa_reg(2, 12);
        enviar(18'b000_0111_0000_0_111111); checa_tela(`DISP_RESULTADO, `OP_LOAD,    7,      63, "8  LOAD R7, 63");
        enviar(18'b101_0111_0111_0_111111); checa_tela(`DISP_RESULTADO, `OP_MUL,     7,    3969, "9  MUL R7, R7, 63");
        enviar(18'b101_0111_0111_0_111111); checa_tela(`DISP_RESULTADO, `OP_MUL,     7,  -12097, "10 MUL R7 (overflow)");
        enviar(18'b110_0000_0000_0_000000); checa_tela(`DISP_SO_NOME,   `OP_CLEAR,   0,       0, "11 CLEAR");
        checa_tudo_zero("11 CLEAR");
        enviar(18'b111_0000_0111_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 7,       0, "12 DISPLAY R7");

        enviar(18'b000_0011_0000_0_000111);   // deixa R3 = 7 para ver o desligar zerar
        desligar;
        checa_tudo_zero("13 desligar");
        if (system_on !== 1'b0) begin erros = erros + 1; $display("ERRO: system_on deveria ser 0 desligado"); end
        else $display("ok  13 desligar");

        ligar;
        enviar(18'b111_0000_0010_0_000000); checa_tela(`DISP_RESULTADO, `OP_DISPLAY, 2,       0, "14 ligar + DISPLAY R2");

        // trocar os switches depois do FETCH nao muda nada
        espera_estado(S_READY);
        @(negedge clk) sw = 18'b010_1000_0000_0_001010;   // ADDI R8, R0, 10
        solta_enviar;
        espera_estado(S_DECODE);
        @(negedge clk) sw = 18'b000_1111_0000_1_111111;   // lixo
        espera_estado(S_READY);
        checa_tela(`DISP_RESULTADO, `OP_ADDI, 8, 10, "sw muda depois do FETCH");

        // Enviar com o LCD ocupado e ignorado
        n0 = n_refresh;
        @(negedge clk) sw = 18'b000_1001_0000_0_000101;   // LOAD R9, 5
        solta_enviar;
        espera_estado(S_WAIT_LCD);
        @(negedge clk) sw = 18'b000_1001_0000_0_000110;   // LOAD R9, 6 (nao pode entrar)
        solta_enviar;
        espera_estado(S_READY);
        ciclos(30);
        if (n_refresh !== n0 + 1 || dbg_state !== S_READY || u_mem.regs[9] !== 16'd5) begin
            erros = erros + 1; $display("ERRO: Enviar com o LCD ocupado foi aceito");
        end
        else $display("ok  Enviar ignorado com o LCD ocupado");

        // Ligar no meio da instrucao: termina, mostra e so depois desliga
        n0 = n_off;
        @(negedge clk) sw = 18'b000_1010_0000_0_010101;   // LOAD R10, 21
        solta_enviar;
        espera_estado(S_DECODE);
        solta_ligar;
        espera_estado(S_WAIT_LCD);
        checa_tela(`DISP_RESULTADO, `OP_LOAD, 10, 21, "Ligar no meio: termina");
        espera_estado(S_OFF);
        if (n_off !== n0 + 1) begin erros = erros + 1; $display("ERRO: Ligar no meio da instrucao nao desligou"); end
        else $display("ok  Ligar no meio: desliga depois de mostrar");
        checa_tudo_zero("Ligar no meio");

        // Ligar durante o desligamento e ignorado
        ligar;
        n0 = n_off;
        solta_ligar;                 // pede para desligar
        espera_estado(S_WAIT_OFF);
        solta_ligar;                 // deve ser ignorado
        espera_estado(S_OFF);
        ciclos(50);
        if (dbg_state !== S_OFF || n_off !== n0 + 1) begin
            erros = erros + 1; $display("ERRO: Ligar durante o desligamento nao foi ignorado");
        end
        else $display("ok  Ligar ignorado durante o desligamento");

        // reset no meio leva para OFF
        ligar;
        @(negedge clk) rst = 1'b1;
        ciclos(2);
        @(negedge clk) rst = 1'b0;
        #1;
        if (dbg_state !== S_OFF) begin erros = erros + 1; $display("ERRO: rst nao levou para OFF"); end
        else $display("ok  rst leva para OFF");

        if (erros == 0) $display("tb_module_mini_cpu: OK");
        else            $display("tb_module_mini_cpu: %0d ERRO(S)", erros);
        $finish;
    end

    // Timeout global
    initial begin
        #5_000_000;
        $display("ERRO: simulacao travou (timeout global)");
        $display("tb_module_mini_cpu: FALHOU");
        $finish;
    end
endmodule

module tb_mem_model (
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

module tb_alu_model (
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
