// tb_rns_mul.sv — Testbench self-checking para rns_mul (Ejercicio 6 - RNS).
//
// Carga los vectores generados por gen_vectors.py (x.hex, y.hex, c3.hex,
// c5.hex, c7.hex, z.hex, nv.txt), aplica cada par X/Y al DUT y compara los
// tres residuos de canal (c3, c5, c7) y la recomposicion (z) contra el
// modelo golden (fxpmath). Reporta PASS/FAIL.
`timescale 1ns/1ps

module tb_rns_mul;
  localparam int W    = 7;        // valores [0, M-1] = [0, 104]
  localparam int NMAX = 65536;    // tope de almacenamiento de los vectores

  logic [W-1:0] x_mem [0:NMAX-1];
  logic [W-1:0] y_mem [0:NMAX-1];
  logic [1:0]  c3_mem [0:NMAX-1];
  logic [2:0]  c5_mem [0:NMAX-1];
  logic [2:0]  c7_mem [0:NMAX-1];
  logic [W-1:0] z_mem [0:NMAX-1];
  reg  [31:0]  n_buf[0:0];        // cantidad de vectores (nv.txt)

  logic [W-1:0] x;
  logic [W-1:0] y;
  logic [1:0]  c3;
  logic [2:0]  c5;
  logic [2:0]  c7;
  logic [W-1:0] z;
  logic [1:0]  c3_exp;
  logic [2:0]  c5_exp;
  logic [2:0]  c7_exp;
  logic [W-1:0] z_exp;

  integer n_vectors;
  integer errors;
  integer i;

  // ---------------------------------------------------------------------
  // DUT: instancia el multiplicador RNS con los modulos {3, 5, 7}
  // ---------------------------------------------------------------------
  rns_mul #(.W(W)) dut (
    .x (x ),
    .y (y ),
    .c3(c3),
    .c5(c5),
    .c7(c7),
    .z (z )
  );

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_rns_mul.vcd");
    $dumpvars(0, tb_rns_mul);
  end

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    $readmemh("nv.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("x.hex",  x_mem, 0, n_vectors - 1);
    $readmemh("y.hex",  y_mem, 0, n_vectors - 1);
    $readmemh("c3.hex", c3_mem, 0, n_vectors - 1);
    $readmemh("c5.hex", c5_mem, 0, n_vectors - 1);
    $readmemh("c7.hex", c7_mem, 0, n_vectors - 1);
    $readmemh("z.hex",  z_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      x     = x_mem[i];
      y     = y_mem[i];
      c3_exp = c3_mem[i];
      c5_exp = c5_mem[i];
      c7_exp = c7_mem[i];
      z_exp  = z_mem[i];
      #1;
      if ((c3 !== c3_exp) || (c5 !== c5_exp) || (c7 !== c7_exp)) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: x=%0d y=%0d -> residuos (%0d,%0d,%0d) esperado (%0d,%0d,%0d)",
                   i, x, y, c3, c5, c7, c3_exp, c5_exp, c7_exp);
      end
      if (z !== z_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: x=%03d y=%03d -> z=%03d esperado=%03d",
                   i, x, y, z, z_exp);
      end
      #1;
    end

    // Caso particular del enunciado (X=14, Y=6)
    x = 7'd14;
    y = 7'd6;
    #1;
    $display("");
    $display("  Caso del enunciado: X=14, Y=6 -> residuos (%0d, %0d, %0d) y z = %0d",
             c3, c5, c7, z);
    $display("  (z debe ser 14*6 = 84)");
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO: FAIL  (%0d errores sobre %0d)", errors, n_vectors);
    $display("");
    $finish;
  end

endmodule