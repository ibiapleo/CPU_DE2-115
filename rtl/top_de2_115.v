// PARTE A - Topo: liga os pinos da DE2-115 aos modulos. Sem logica de CPU aqui.
// Especificacao: docs/DIVISAO.md, Parte A
`default_nettype none
`include "defines.vh"
module top_de2_115 #(
    parameter DEBOUNCE_CYCLES = 1_000_000,    // 20 ms (no tb_top use 10)
    parameter LCD_CLK_HZ      = 50_000_000    // no tb_top use 50_000
) (
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,        // ativos em 0
    input  wire [17:0] SW,
    output wire [7:0]  LCD_DATA,
    output wire        LCD_RS,
    output wire        LCD_RW,
    output wire        LCD_EN,
    output wire        LCD_ON,
    output wire        LCD_BLON,
    output wire [8:0]  LEDG,
    output wire [17:0] LEDR
);
    wire clk = CLOCK_50;

    // ---------------- Reset de power-on (16 ciclos apos programar a FPGA) ----
    reg [3:0] por_cnt = 4'd0;
    wire rst = ~&por_cnt;
    always @(posedge clk) if (rst) por_cnt <= por_cnt + 4'd1;

    // ---------------- Botoes ------------------------------------------------
    wire btn_ligar, btn_enviar;
    button_handler #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btn_ligar  (.clk(clk), .rst(rst), .btn_n(KEY[1]), .released(btn_ligar));
    button_handler #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) u_btn_enviar (.clk(clk), .rst(rst), .btn_n(KEY[0]), .released(btn_enviar));

    // ---------------- Fios entre modulos -------------------------------------
    wire [3:0]  mem_rd_addr_a, mem_rd_addr_b, mem_wr_addr;
    wire [15:0] mem_rd_data_a, mem_rd_data_b, mem_wr_data;
    wire        mem_we, mem_clear;
    wire [2:0]  alu_op;
    wire [15:0] alu_a, alu_b, alu_result;
    wire        alu_overflow;
    wire [1:0]  disp_kind;
    wire [2:0]  disp_opcode;
    wire [3:0]  disp_reg;
    wire [15:0] disp_value;
    wire [255:0] screen;
    wire        lcd_refresh, lcd_off, lcd_busy, lcd_done;
    wire        system_on;
    wire [3:0]  dbg_state;

    // ---------------- Modulos -------------------------------------------------
    module_mini_cpu u_cpu (
        .clk(clk), .rst(rst),
        .btn_ligar(btn_ligar), .btn_enviar(btn_enviar), .sw(SW),
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

    memory u_mem (
        .clk(clk), .rst(rst), .clear(mem_clear),
        .we(mem_we), .wr_addr(mem_wr_addr), .wr_data(mem_wr_data),
        .rd_addr_a(mem_rd_addr_a), .rd_addr_b(mem_rd_addr_b),
        .rd_data_a(mem_rd_data_a), .rd_data_b(mem_rd_data_b)
    );

    module_alu u_alu (
        .op(alu_op), .a(alu_a), .b(alu_b),
        .result(alu_result), .overflow(alu_overflow)
    );

    lcd_formatter u_fmt (
        .kind(disp_kind), .opcode(disp_opcode), .reg_num(disp_reg),
        .value(disp_value), .screen(screen)
    );

    lcd_driver #(.CLK_HZ(LCD_CLK_HZ)) u_lcd (
        .clk(clk), .rst(rst),
        .refresh(lcd_refresh), .power_off(lcd_off), .screen(screen),
        .busy(lcd_busy), .done(lcd_done),
        .lcd_data(LCD_DATA), .lcd_rs(LCD_RS), .lcd_rw(LCD_RW), .lcd_en(LCD_EN),
        .lcd_on(LCD_ON), .lcd_blon(LCD_BLON)
    );

    // ---------------- LEDs de debug -------------------------------------------
    assign LEDR      = SW;
    assign LEDG[8]   = system_on;
    assign LEDG[7]   = lcd_busy;
    assign LEDG[6]   = alu_overflow;
    assign LEDG[5:4] = 2'b00;
    assign LEDG[3:0] = dbg_state;
endmodule
`default_nettype wire
