// PARTE B - Unidade de controle (FSM principal). MODULO OBRIGATORIO.
// Especificacao (portas, estados, writeback): docs/DIVISAO.md, Parte B
`default_nettype none
`include "defines.vh"
module module_mini_cpu (
    input  wire        clk,
    input  wire        rst,
    // entradas da placa (ja tratadas)
    input  wire        btn_ligar,      // pulso
    input  wire        btn_enviar,     // pulso
    input  wire [17:0] sw,
    // memoria
    output wire [3:0]  mem_rd_addr_a,
    output wire [3:0]  mem_rd_addr_b,
    input  wire [15:0] mem_rd_data_a,
    input  wire [15:0] mem_rd_data_b,
    output wire        mem_we,         // pulso
    output wire [3:0]  mem_wr_addr,
    output wire [15:0] mem_wr_data,
    output wire        mem_clear,      // pulso
    // ALU
    output wire [2:0]  alu_op,
    output wire [15:0] alu_a,
    output wire [15:0] alu_b,
    input  wire [15:0] alu_result,
    // LCD (disp_* registrados e estaveis enquanto lcd_busy = 1)
    output wire [1:0]  disp_kind,
    output wire [2:0]  disp_opcode,
    output wire [3:0]  disp_reg,
    output wire [15:0] disp_value,
    output wire        lcd_refresh,    // pulso, so com lcd_busy = 0
    output wire        lcd_off,        // pulso, so com lcd_busy = 0
    input  wire        lcd_busy,
    input  wire        lcd_done,       // pulso
    // status / debug
    output wire        system_on,
    output wire [3:0]  dbg_state
);
    // Registrador da instrucao capturada no FETCH
    reg [17:0] instr;

    wire [2:0]  dec_opcode;
    wire [3:0]  dec_rd, dec_rs1, dec_rs2;
    wire [15:0] dec_imm;
    wire        dec_use_imm, dec_reg_write, dec_is_clear, dec_is_display;

    decoder u_decoder (
        .instr      (instr),
        .opcode     (dec_opcode),
        .rd         (dec_rd),
        .rs1        (dec_rs1),
        .rs2        (dec_rs2),
        .imm        (dec_imm),
        .use_imm    (dec_use_imm),
        .reg_write  (dec_reg_write),
        .is_clear   (dec_is_clear),
        .is_display (dec_is_display)
    );

    // TODO (Parte B): FSM. Stub: tudo parado.
    always @(posedge clk) begin
        if (rst) instr <= 18'd0;
    end

    assign mem_rd_addr_a = 4'd0;
    assign mem_rd_addr_b = 4'd0;
    assign mem_we        = 1'b0;
    assign mem_wr_addr   = 4'd0;
    assign mem_wr_data   = 16'd0;
    assign mem_clear     = 1'b0;
    assign alu_op        = 3'd0;
    assign alu_a         = 16'd0;
    assign alu_b         = 16'd0;
    assign disp_kind     = `DISP_INICIAL;
    assign disp_opcode   = 3'd0;
    assign disp_reg      = 4'd0;
    assign disp_value    = 16'd0;
    assign lcd_refresh   = 1'b0;
    assign lcd_off       = 1'b0;
    assign system_on     = 1'b0;
    assign dbg_state     = 4'd0;
endmodule
`default_nettype wire
