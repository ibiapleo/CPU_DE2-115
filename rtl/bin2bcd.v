`default_nettype none
module bin2bcd (
    input  wire [15:0] bin,
    output wire [19:0] bcd   // [19:16] dezena de milhar ... [3:0] unidade
);
    // Divisao por constante feita como multiplicacao: bin / 10 = (bin * 52429) >> 19
    wire [32:0] p10    = bin * 17'd52429;
    wire [32:0] p100   = bin * 17'd83887;
    wire [32:0] p1000  = bin * 17'd67109;
    wire [32:0] p10000 = bin * 17'd107375;

    wire [15:0] q10    = p10    >> 19;   // bin / 10
    wire [15:0] q100   = p100   >> 23;   // bin / 100
    wire [15:0] q1000  = p1000  >> 26;   // bin / 1000
    wire [15:0] q10000 = p10000 >> 30;   // bin / 10000

    assign bcd[3:0]   = bin    - 10 * q10;
    assign bcd[7:4]   = q10    - 10 * q100;
    assign bcd[11:8]  = q100   - 10 * q1000;
    assign bcd[15:12] = q1000  - 10 * q10000;
    assign bcd[19:16] = q10000;
endmodule
`default_nettype wire
