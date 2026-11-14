`default_nettype none
`include "defines.vh"
module module_mini_cpu (
    input  wire        clk,
    input  wire        rst,
    input  wire        btn_ligar,
    input  wire        btn_enviar,
    input  wire [17:0] sw,
    output wire [3:0]  mem_rd_addr_a,
    output wire [3:0]  mem_rd_addr_b,
    input  wire [15:0] mem_rd_data_a,
    input  wire [15:0] mem_rd_data_b,
    output reg         mem_we,
    output wire [3:0]  mem_wr_addr,
    output wire [15:0] mem_wr_data,
    output reg         mem_clear,
    output wire [2:0]  alu_op,
    output wire [15:0] alu_a,
    output wire [15:0] alu_b,
    input  wire [15:0] alu_result,
    output reg  [1:0]  disp_kind,
    output reg  [2:0]  disp_opcode,
    output reg  [3:0]  disp_reg,
    output reg  [15:0] disp_value,
    output reg         lcd_refresh,
    output reg         lcd_off,
    input  wire        lcd_busy,
    input  wire        lcd_done,
    output reg         system_on,
    output wire [3:0]  dbg_state
);
    // Estados (o numero sai em dbg_state)
    parameter OFF = 4'd0, POWER_ON = 4'd1, SHOW = 4'd2, WAIT_LCD = 4'd3,
              READY = 4'd4, FETCH = 4'd5, DECODE = 4'd6, EXECUTE = 4'd7,
              WRITEBACK = 4'd8, POWER_OFF = 4'd9, SHOW_OFF = 4'd10, WAIT_OFF = 4'd11;

    reg [3:0]  estado_atual;
    reg [17:0] instr;          // capturada no FETCH
    reg [15:0] op_a, op_b;     // lidos no DECODE
    reg [15:0] resultado;      // guardado no EXECUTE
    reg        pending_off;    // Ligar apertado fora do READY, tratado no READY

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

    assign mem_rd_addr_a = dec_rs1;
    assign mem_rd_addr_b = dec_rs2;
    assign alu_op        = dec_opcode;
    assign alu_a         = op_a;
    assign alu_b         = op_b;
    assign mem_wr_addr   = dec_rd;
    assign mem_wr_data   = resultado;
    assign dbg_state     = estado_atual;

    always @(*) begin   // parte combinacional
        case (estado_atual)
            OFF: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b0;
            end
            POWER_ON: begin
                mem_we <= 1'b0; mem_clear <= 1'b1; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            SHOW: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= ~lcd_busy; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            WAIT_LCD: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            READY: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            FETCH: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            DECODE: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            EXECUTE: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            WRITEBACK: begin
                mem_we <= dec_reg_write; mem_clear <= dec_is_clear; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b1;
            end
            POWER_OFF: begin
                mem_we <= 1'b0; mem_clear <= 1'b1; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b0;
            end
            SHOW_OFF: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= ~lcd_busy;
                system_on <= 1'b0;
            end
            WAIT_OFF: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b0;
            end
            default: begin
                mem_we <= 1'b0; mem_clear <= 1'b0; lcd_refresh <= 1'b0; lcd_off <= 1'b0;
                system_on <= 1'b0;
            end
        endcase
    end

    always @(posedge clk) begin   // parte sequencial
        if (rst) begin
            estado_atual <= OFF;
            instr        <= 18'd0;
            op_a         <= 16'd0;
            op_b         <= 16'd0;
            resultado    <= 16'd0;
            pending_off  <= 1'b0;
            disp_kind    <= `DISP_INICIAL;
            disp_opcode  <= 3'd0;
            disp_reg     <= 4'd0;
            disp_value   <= 16'd0;
        end
        else
            case (estado_atual)
                OFF:
                    if (btn_ligar)
                        estado_atual <= POWER_ON;

                POWER_ON: begin
                    disp_kind    <= `DISP_INICIAL;
                    disp_opcode  <= 3'd0;
                    disp_reg     <= 4'd0;
                    disp_value   <= 16'd0;
                    pending_off  <= 1'b0;
                    estado_atual <= SHOW;
                end

                SHOW: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    if (lcd_busy == 0)
                        estado_atual <= WAIT_LCD;
                end

                WAIT_LCD: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    if (lcd_done)
                        estado_atual <= READY;
                end

                READY:
                    if (btn_ligar || pending_off)
                        estado_atual <= POWER_OFF;
                    else if (btn_enviar)
                        estado_atual <= FETCH;

                FETCH: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    instr        <= sw;
                    estado_atual <= DECODE;
                end

                DECODE: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    op_a         <= mem_rd_data_a;
                    op_b         <= dec_use_imm ? dec_imm : mem_rd_data_b;
                    estado_atual <= EXECUTE;
                end

                EXECUTE: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    resultado    <= alu_result;
                    estado_atual <= WRITEBACK;
                end

                WRITEBACK: begin
                    if (btn_ligar)
                        pending_off <= 1'b1;
                    disp_opcode <= dec_opcode;
                    if (dec_is_clear) begin
                        disp_kind  <= `DISP_SO_NOME;
                        disp_reg   <= 4'd0;
                        disp_value <= 16'd0;
                    end
                    else if (dec_is_display) begin
                        disp_kind  <= `DISP_RESULTADO;
                        disp_reg   <= dec_rs1;
                        disp_value <= op_a;   // R[rs1]: a ALU devolve 0 no DISPLAY
                    end
                    else begin
                        disp_kind  <= `DISP_RESULTADO;
                        disp_reg   <= dec_rd;
                        disp_value <= resultado;
                    end
                    estado_atual <= SHOW;
                end

                POWER_OFF: begin
                    pending_off  <= 1'b0;
                    estado_atual <= SHOW_OFF;
                end

                SHOW_OFF:
                    if (lcd_busy == 0)
                        estado_atual <= WAIT_OFF;

                WAIT_OFF:
                    if (lcd_done)
                        estado_atual <= OFF;

                default:
                    estado_atual <= OFF;
            endcase
    end
endmodule
`default_nettype wire
