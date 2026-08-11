//TESTBENCH PARA OBSERVAR QUE TAN ROBUSTO ES EL MODULO

`timescale 1ns/1ps

module tb_conversion;

    logic [31:0] numero_float;
    logic [7:0]  numero_fixed;
    logic [7:0]  esperado;

    Conversor_float_to_fixed #(
        .Width_NB(8),
        .Width_NF(3),
        .Width_float(32)
    ) dut (
        .numero_float(numero_float),
        .numero_fixed(numero_fixed)
    );

    task check(input [31:0] valor_float, input [7:0] valor_esperado, input string nombre);
        begin
            numero_float = valor_float;
            esperado     = valor_esperado;
            #10;
            if (numero_fixed === esperado)
                $display("PASS: %s -> numero_fixed = %b (esperado %b)", nombre, numero_fixed, esperado);
            else
                $display("FAIL: %s -> numero_fixed = %b (esperado %b)", nombre, numero_fixed, esperado);
        end
    endtask

    initial begin
        // Caso 1: x = 9.625 (positivo, sin overflow, exponente positivo)
        check(32'b01000001000110100000000000000000, 8'b01001101, "x=9.625");

        // Caso 2: x = -9.625 (negativo, prueba el bit de signo)
        check(32'b11000001000110100000000000000000, 8'b11001101, "x=-9.625");

        // Caso 3: x = 20.5 (overflow, debe saturar)
        check(32'b01000001101001000000000000000000, 8'b01111111, "x=20.5 (overflow)");

        // Caso 4: x = 0.625 (exponente negativo, numero menor a 1)
        check(32'b00111111001000000000000000000000, 8'b00000101, "x=0.625 (exp negativo)");

        // Caso 5: x = 15.875 (limite maximo representable en S(8,3), sin overflow)
        check(32'b01000001011111100000000000000000, 8'b01111111, "x=15.875 (limite maximo)");

        $finish;
    end

endmodule