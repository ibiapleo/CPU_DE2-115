`default_nettype none
module bin2bcd (
    input  wire [15:0] bin,
    output wire [19:0] bcd   // [19:16] dezena de milhar ... [3:0] unidade
);
    assign bcd[19:16] = bin / 10000;
    assign bcd[15:12] = bin / 1000 % 10;
    assign bcd[11:8]  = bin / 100 % 10;
    assign bcd[7:4]   = bin / 10 % 10;
    assign bcd[3:0]   = bin % 10;
endmodule
`default_nettype wire
