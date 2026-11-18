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

    reg [15:0] ram [15:0];
    integer i;

    task limpar_ram;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                ram[i] = 0;
            end
        end
    endtask

    always @(posedge clk or posedge clear or posedge rst) begin
        if (rst || clear) begin
            limpar_ram();
        end
        else begin
            if (we) begin
                ram[wr_addr] <= wr_data;
            end
        end
    end
	 
	 assign rd_data_a = ram[rd_addr_a];
    assign rd_data_b = ram[rd_addr_b];
	 
endmodule