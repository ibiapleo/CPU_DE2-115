`timescale 1ns/1ps
`default_nettype none
module tb_bin2bcd;
    integer erros = 0;
    integer n;

    reg  [15:0] bin;
    wire [19:0] bcd;
    reg  [19:0] esperado;

    bin2bcd dut (.bin(bin), .bcd(bcd));

    // Testa todos os 65.536 valores possiveis
    initial begin
        for (n = 0; n < 65536; n = n + 1) begin
            bin = n;
            esperado = (n / 10000) << 16 | (n / 1000 % 10) << 12 | (n / 100 % 10) << 8 |
                       (n / 10 % 10) << 4 | (n % 10);
            #1;
            if (bcd !== esperado) begin
                erros = erros + 1;
                if (erros <= 10)
                    $display("ERRO: bin=%0d obtido=%h esperado=%h", n, bcd, esperado);
            end
        end

        if (erros == 0) $display("tb_bin2bcd: OK");
        else            $display("tb_bin2bcd: %0d ERRO(S)", erros);
        $finish;
    end
endmodule
`default_nettype wire
