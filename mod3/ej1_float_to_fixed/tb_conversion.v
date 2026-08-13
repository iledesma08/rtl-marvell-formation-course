//TESTBENCH PARA OBSERVAR QUE TAN ROBUSTO ES EL MODULO

`timescale 1ns/1ps

module tb_conversion;
    localparam int NMAX = 65536;   // tope de almacenamiento de los vectores
    logic [31:0] float_mem [0:NMAX-1];  // 
    logic [7:0] fixed_mem [0:NMAX-1];  // 
    reg   [31:0] n_buf[0:0];       // cantidad de vectores (nv.txt)


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

    task check(input [31:0] valor_float, input [7:0] valor_esperado, input integer i); //declaro una variable i para determinar qué vector es el que fallo
        begin
            numero_float = valor_float;
            esperado     = valor_esperado;
            #10;
            if (numero_fixed === esperado)
                pass_count = pass_count + 1;
            else
                fail_count = fail_count + 1;
        end
    endtask

    integer pass_count;
    integer fail_count;
    integer n_vectors;
    integer i;

    initial begin


        $readmemh("nv.txt", n_buf);
        n_vectors = n_buf[0];
        $readmemh("x.hex", float_mem, 0, n_vectors - 1); //almaceno en el array desde 0 hasta el total de vectores - 1
        $readmemh("expected.hex", fixed_mem, 0, n_vectors - 1);

        pass_count = 0;
        fail_count = 0;

        for (i =0 ;i<n_vectors ;i=i+1 ) begin
            

            check(float_mem[i], fixed_mem[i],i);

        end

        $display("PASS: %0d ", pass_count);
        $display("FAIL: %0d ", fail_count);
        $finish;
    end

endmodule