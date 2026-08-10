// tb_sum_ptofijo.sv — Testbench self-checking para sum_ptofijo (Ejercicio 2).
//
// Carga los vectores generados por gen_vectors.py (a.hex, b.hex, expected.hex,
// nv.txt), aplica cada par A/B al DUT y compara la suma observada contra el
// valor esperado calculado por el modelo golden (fxpmath). Reporta PASS/FAIL.

`timescale 1ns/1ps

module tb_sum_ptofijo;
  localparam int NMAX = 65536;   // tope de almacenamiento de los vectores

  logic [5:0] a_mem [0:NMAX-1];  // A : S(6,4)
  logic [7:0] b_mem [0:NMAX-1];  // B : S(8,5)
  logic [8:0] s_mem [0:NMAX-1];  // esperado : S(9,5)
  reg   [31:0] n_buf[0:0];       // cantidad de vectores (nv.txt)

  logic [5:0] a;
  logic [7:0] b;
  logic [8:0] sum;
  logic [8:0] sum_exp;

  integer n_vectors;
  integer errors;
  integer i;

  // ---------------------------------------------------------------------
  // DUT: instancia el sumador con los formatos del enunciado
  // ---------------------------------------------------------------------
  sum_ptofijo #(.W_A(6), .NBFA(4), .W_B(8), .NBFB(5)) dut (
    .a   (a  ),
    .b   (b  ),
    .sum (sum)
  );

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_sum_ptofijo.vcd");
    $dumpvars(0, tb_sum_ptofijo);
  end

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    $readmemh("nv.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("a.hex", a_mem, 0, n_vectors - 1);
    $readmemh("b.hex", b_mem, 0, n_vectors - 1);
    $readmemh("expected.hex", s_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      a = a_mem[i];
      b = b_mem[i];
      sum_exp = s_mem[i];
      #1;
      if (sum !== sum_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: a=%06b  b=%08b  ->  sum=%09b  esperado=%09b",
                   i, a, b, sum, sum_exp);
      end
      #1;
    end

    // Caso particular del enunciado (vector 0)
    a = 6'b110010;
    b = 8'b00011110;
    #1;
    $display("");
    $display("  Caso del enunciado: 110010 + 00011110 = %09b (S(9,5))", sum);
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO: FAIL  (%0d errores sobre %0d)", errors, n_vectors);
    $display("");
    $finish;
  end

endmodule