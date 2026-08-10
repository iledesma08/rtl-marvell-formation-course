// tb_mul23.sv — Testbench self-checking para mul23 (Ejercicio 4 - CSD).
//
// Carga los vectores generados por gen_vectors.py (x.hex, expected.hex,
// nv.txt), aplica cada X al DUT y compara ambas salidas (forma binaria y
// forma CSD) contra el valor esperado calculado por el modelo golden
// (fxpmath). Ademas verifica que ambas formas coinciden entre si. PASS/FAIL.

`timescale 1ns/1ps

module tb_mul23;
  localparam int W_X  = 8;
  localparam int W_Y  = W_X + 5;      // S(13,0)
  localparam int NMAX = 65536;

  logic [W_X-1:0] x_mem [0:NMAX-1];
  logic [W_Y-1:0] y_mem [0:NMAX-1];
  reg   [31:0]    n_buf[0:0];

  logic [W_X-1:0] x;
  logic [W_Y-1:0] y_std;
  logic [W_Y-1:0] y_csd;
  logic [W_Y-1:0] y_exp;

  integer n_vectors;
  integer errors;
  integer i;
  logic signed [W_Y-1:0] y_disp;

  // ---------------------------------------------------------------------
  // DUT: instancia el multiplicador con W_X = 8 (X en S(8,0))
  // ---------------------------------------------------------------------
  mul23 #(.W_X(W_X)) dut (
    .x    (x    ),
    .y_std(y_std),
    .y_csd(y_csd)
  );

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_mul23.vcd");
    $dumpvars(0, tb_mul23);
  end

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    $readmemh("nv.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("x.hex", x_mem, 0, n_vectors - 1);
    $readmemh("expected.hex", y_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      x = x_mem[i];
      y_exp = y_mem[i];
      #1;
      if (y_std !== y_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: x=%08b -> y_std=%013b esperado=%013b",
                   i, x, y_std, y_exp);
      end
      if (y_csd !== y_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: x=%08b -> y_csd=%013b esperado=%013b",
                   i, x, y_csd, y_exp);
      end
      if (y_std !== y_csd) begin
        errors = errors + 1;
        $display("  ERROR vec %4d: forma binaria != forma CSD", i);
      end
      #1;
    end

    // Un par de casos ilustrativos (X positivo y X negativo)
    x = 8'sd11;  #1;   y_disp = y_std;
    $display("  X=+11 -> y = 11*23 = %0d  (bin:%013b csd:%013b)",
             y_disp, y_std, y_csd);
    x = -8'sd15; #1;   y_disp = y_std;
    $display("  X=-15 -> y = -15*23 = %0d  (bin:%013b csd:%013b)",
             y_disp, y_std, y_csd);

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO: FAIL  (%0d errores sobre %0d)", errors, n_vectors);
    $display("");
    $finish;
  end

endmodule