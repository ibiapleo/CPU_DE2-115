// PARTE C - Banco de 16 registradores x 16 bits. MODULO OBRIGATORIO.
// Especificacao: docs/DIVISAO.md, Parte C
`default_nettype none
module memory (
    input  wire        clk,
    input  wire        rst,        // zera tudo
    input  wire        clear,      // pulso: zera tudo (prioridade sobre we)
    input  wire        we,
    input  wire [3:0]  wr_addr,
    input  wire [15:0] wr_data,
    input  wire [3:0]  rd_addr_a,
    input  wire [3:0]  rd_addr_b,
    output wire [15:0] rd_data_a,  // leitura combinacional
    output wire [15:0] rd_data_b   // leitura combinacional
);
    reg [15:0] regs [0:15];

    // TODO (Parte C): escrita sincrona, rst/clear zeram tudo
    assign rd_data_a = regs[rd_addr_a];
    assign rd_data_b = regs[rd_addr_b];
endmodule
`default_nettype wire
