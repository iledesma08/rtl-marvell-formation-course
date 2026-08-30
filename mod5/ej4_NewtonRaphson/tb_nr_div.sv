// tb_nr_div.sv — Testbench self-checking para el divisor por Newton-Raphson
//
// Instancia CUATRO DUTs de nr_div en paralelo (N_ITER = 1..4) con estimulacion
// compartida y verifica:
//   1. Exactitud bit a bit contra los vectores dorados de gen_vectors.py
//      (a.hex + y_exp_1..4.hex), generados con el golden model de punto fijo
//      (gen_lut.nr_iterate), que replica EXACTAMENTE la aritmetica del RTL.
//   2. Error real vs 1/a "verdadero" en doble precision: max error en ULP y
//      relativo por cantidad de iteraciones (entregable d), como tabla.
//
// Reporta PASS/FAIL con $display.

`timescale 1ns/1ps

module tb_nr_div;
  localparam int N_MAX = 4;                     // probamos N_ITER = 1..4
  localparam int MAXV  = 1 << 16;               // tope de vectores

  // ---- Senales compartidas del estimulo ---------------------------------
  logic        clk = 0;
  logic        rst_n;
  logic        start;
  logic [15:0] a;

  // ---- Salidas de los 4 DUTs ---------------------------------------------
  logic [15:0] y   [N_MAX];
  logic        done[N_MAX];
  logic        busy[N_MAX];

  // ---- Vectores de prueba (leidos de los .hex de gen_vectors.py) ---------
  logic [15:0] mem_a  [0:MAXV-1];
  logic [15:0] mem_y1 [0:MAXV-1];   // esperados tras 1 iteracion NR
  logic [15:0] mem_y2 [0:MAXV-1];   // tras 2
  logic [15:0] mem_y3 [0:MAXV-1];   // tras 3
  logic [15:0] mem_y4 [0:MAXV-1];   // tras 4
  integer      n_vec;

  // ---- Metricas -----------------------------------------------------------
  integer lat    [N_MAX];      // latencia medida (ciclos)
  integer maxulp [N_MAX];      // max error absoluto (ULP) vs 1/a real
  real    maxrel [N_MAX];      // max error relativo vs 1/a real
  integer errors;
  integer seed = 2026;

  // Clk de 100 MHz.
  always #5 clk = ~clk;

  // ---- DUTs: N_ITER = 1..4, misma estimulacion ---------------------------
  for (genvar g = 0; g < N_MAX; g++) begin : gen_dut
    nr_div #(.N_ITER(g + 1)) dut (
      .clk  (clk),
      .rst_n(rst_n),
      .start(start),
      .a    (a),
      .y    (y[g]),
      .done (done[g]),
      .busy (busy[g])
    );
  end

  // Forma de onda para GTKWave.
  initial begin
    $dumpfile("tb_nr_div.vcd");
    $dumpvars(0, tb_nr_div);
  end

  // ---------------------------------------------------------------------
  // 1/a "verdadero" redondeado a U(16,15), calculado en doble precision.
  // ---------------------------------------------------------------------
  function automatic integer y_true(input integer a_q);
    real r;
    r = 2147483648.0 / a_q;               // 2^31 / a
    return (r + 0.5 >= 65536.0) ? 65535 : $rtoi(r + 0.5); // redondeo a nearest, saturando a 0xFFFF
  endfunction

  // Esperado del golden de Python para un N_ITER y un vector dados.
  function automatic logic [15:0] exp_y(input integer n, input integer i);
    case (n)
      1: exp_y = mem_y1[i];
      2: exp_y = mem_y2[i];
      3: exp_y = mem_y3[i];
      4: exp_y = mem_y4[i];
      default: exp_y = '0;
    endcase
  endfunction

  // ---------------------------------------------------------------------
  // Carga los vectores generados por gen_vectors.py.
  // ---------------------------------------------------------------------
  task automatic load_vectors();
    integer fd, i;
    begin
      fd = $fopen("nvec.txt", "r");
      void'($fscanf(fd, "%d", n_vec));
      $fclose(fd);

      fd = $fopen("a.hex", "r");
      for (i = 0; i < n_vec; i = i + 1) void'($fscanf(fd, "%h", mem_a[i]));
      $fclose(fd);

      fd = $fopen("y_exp_1.hex", "r");
      for (i = 0; i < n_vec; i = i + 1) void'($fscanf(fd, "%h", mem_y1[i]));
      $fclose(fd);

      fd = $fopen("y_exp_2.hex", "r");
      for (i = 0; i < n_vec; i = i + 1) void'($fscanf(fd, "%h", mem_y2[i]));
      $fclose(fd);

      fd = $fopen("y_exp_3.hex", "r");
      for (i = 0; i < n_vec; i = i + 1) void'($fscanf(fd, "%h", mem_y3[i]));
      $fclose(fd);

      fd = $fopen("y_exp_4.hex", "r");
      for (i = 0; i < n_vec; i = i + 1) void'($fscanf(fd, "%h", mem_y4[i]));
      $fclose(fd);
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector a los 4 DUTs y verifica cada uno al ritmo de su `done`.
  //
  // La estimulacion se aplica a mitad de ciclo (negedge) para que `a` y
  // `start` esten estables al menos medio periodo antes del flanco de
  // captura
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input integer vi);
    integer c;        // ciclos transcurridos desde que se muestreo `start`
    integer t;        // valor "verdadero" 1/a
    integer d;        // |y - y_true| en ULP
    real    rel;
    begin
      // Esperamos a que todos los DUTs esten en IDLE.
      while (busy[0] | busy[1] | busy[2] | busy[3]) @(posedge clk);

      // Aplicamos el estimulo a mitad de ciclo (setup garantizado).
      @(negedge clk);
      a = mem_a[vi];
      start = 1;
      @(posedge clk);                  // flanco de captura
      @(negedge clk);                  // salimos del flanco antes de quitar start
      start = 0;
      c = 0;

      for (int n = 1; n <= N_MAX; n = n + 1) begin
        // Esperamos el pulso de `done` de este DUT.
        while (!done[n - 1]) begin
          @(posedge clk);
          c = c + 1;
        end

        // Latencia esperada: 2*N_ITER + 1 ciclos desde `start` (el resultado
        // `y` queda valido en 2*N_ITER ciclos y `done` se observa un ciclo
        // despues, junto con `y` listo).
        lat[n - 1] = c;
        if (c != 2 * n + 1) begin
          errors = errors + 1;
          $display("  ERROR [latencia N=%0d, vec %0d]: %0d ciclos (esperado %0d)",
                   n, vi, c, 2 * n + 1);
        end

        // Comparacion bit a bit contra el golden de Python.
        if (y[n - 1] !== exp_y(n, vi)) begin
          errors = errors + 1;
          $display("  ERROR [N=%0d, vec %0d]: a=%04x -> y=%04x (dorado %04x)",
                   n, vi, mem_a[vi], y[n - 1], exp_y(n, vi));
        end else begin
          t   = y_true(mem_a[vi]);
          d   = (y[n - 1] > t) ? y[n - 1] - t : t - y[n - 1];
          rel = real'(d) / t;      // division real, no entera
          if (d > maxulp[n - 1]) maxulp[n - 1] = d;
          if (rel > maxrel[n - 1]) maxrel[n - 1] = rel;
        end

        // `done` debe ser pulso de un solo ciclo.
        @(posedge clk);
        c = c + 1;
        if (done[n - 1]) begin
          errors = errors + 1;
          $display("  ERROR [done N=%0d, vec %0d]: no es pulso de un ciclo", n, vi);
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    errors = 0;
    for (int n = 1; n <= N_MAX; n = n + 1) begin
      maxulp[n - 1] = 0;
      maxrel[n - 1] = 0.0;
    end

    $display("");
    $display("==============================================================");
    $display("EJERCICIO 4 - Divisor por Newton-Raphson  (y = 1/a)");
    $display("==============================================================");

    rst_n = 0;
    start = 0;
    a     = '0;
    repeat (4) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    load_vectors();
    $display("  Vectores cargados: %0d (x4 DUTs, N_ITER = 1..4)", n_vec);

    $display("");
    $display("  [1/2] Verificando exactitud bit a bit contra golden (Python)...");
    for (int i = 0; i < n_vec; i = i + 1)
      apply_and_check(i);

    $display("  [2/2] Tabla error vs N iteraciones (vs 1/a en doble precision)...");
    $display("");
    $display("==============================================================");
    $display("  N_ITER | latencia [ciclos] | max err [ULP] | max err rel");
    $display("---------+-------------------+---------------+----------------");
    for (int n = 1; n <= N_MAX; n = n + 1)
      $display("    %0d    |         %0d         |      %0d        |   %.3e",
               n, lat[n - 1], maxulp[n - 1], maxrel[n - 1]);

    $display("--------------------------------------------------------------");
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d vectores bit-exactos en N_ITER=1..4, latencia y protocolo OK)", n_vec);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule