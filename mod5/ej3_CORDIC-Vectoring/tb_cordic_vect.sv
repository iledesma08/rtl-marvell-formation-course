// tb_cordic_vect.sv — Testbench self-checking para el CORDIC Vectoring
//
// Instancia DOS DUTs en paralelo con estimulacion compartida:
//   - cordic_vect: el CORDIC vectoring (entregable a)
//   - ref_direct : la referencia directa con mult + ROMs (entregable b)
//
// Verifica:
//   1. Protocolo: done pulso de 1 ciclo y latencia correcta (CORDIC = 16
//      ciclos, referencia = 3 ciclos).
//   2. Exactitud vs el valor "verdadero" en doble precision ($atan2/$sqrt),
//      medida en ULP para R y phi (entregables c y d).
//   3. Cross-check CORDIC vs referencia: ambos caminos deben coincidir dentro
//      de una tolerancia (redondean distinto).
//   4. Genera errores.csv con el error por vector y por cuadrante para que
//      analisis_error.py grafique el error vs cuadrante (entregable d).
//
// Reporta PASS/FAIL con $display.

`timescale 1ns/1ps

module tb_cordic_vect;
  localparam int MAXV   = 4096;
  localparam int N_ITER = 16;

  // Tolerancias en ULP (se ajustan segun lo que mide la simulacion):
  //   R  : 1 ULP = 2^-15 ;  phi: 1 ULP = pi * 2^-14 (unidades de pi)
  localparam int TOL_R_C = 4;     // R  CORDIC vs verdad (peor caso medido: 4)
  localparam int TOL_P_C = 5;     // phi CORDIC vs verdad
  localparam int TOL_R_R = 2;     // R  referencia vs verdad
  localparam int TOL_P_R = 2;     // phi referencia vs verdad
  localparam int TOL_R_X = 4;     // cross-check R  (CORDIC vs ref)
  localparam int TOL_P_X = 8;     // cross-check phi (CORDIC vs ref)

  // ---- Senales del estimulo y de los DUTs --------------------------------
  logic clk = 0;
  logic rst_n;
  logic start;
  logic signed [15:0] x, y;
  logic signed [15:0] Rc, phic, Rr, phir;
  logic dc, dr, bc, br;

  cordic_vect dut_c (.clk(clk), .rst_n(rst_n), .start(start),
                     .x(x), .y(y), .R(Rc), .phi(phic), .done(dc), .busy(bc));
  ref_direct  dut_r (.clk(clk), .rst_n(rst_n), .start(start),
                     .x(x), .y(y), .R(Rr), .phi(phir), .done(dr), .busy(br));

  always #5 clk = ~clk;

  // ---- Vectores de test (generados por gen_roms.py) ----------------------
  logic signed [15:0] xm [0:MAXV-1];
  logic signed [15:0] ym [0:MAXV-1];
  integer n_vec;

  // ---- Metricas ------------------------------------------------------------
  integer lat_c, lat_r;           // latencia medida
  integer errors;
  integer n_q     [1:4];
  integer maxRc_q [1:4], maxRr_q [1:4];
  integer maxPhic_q [1:4], maxPhir_q [1:4];
  integer sumRc_q [1:4], sumRr_q [1:4];
  integer sumPhic_q [1:4], sumPhir_q [1:4];
  real    meanRc_q [1:4], meanRr_q [1:4];
  real    meanPhic_q [1:4], meanPhir_q [1:4];
  integer fd;                     // errores.csv
  integer pad;                    // contador de guiones del separador

  // ---------------------------------------------------------------------
  // Funciones auxiliares.
  // ---------------------------------------------------------------------
  function automatic integer iabs(input integer v);
    iabs = (v < 0) ? -v : v; // absoluto
  endfunction

  // R "verdadero": R = sqrt(x^2+y^2) cuantizado a S(16,15) (redondeo nearest).
  function automatic integer true_R(input integer xq, input integer yq);
    true_R = $rtoi($sqrt(real'(xq) * xq + real'(yq) * yq) + 0.5);
  endfunction

  // phi "verdadero": atan2(y,x) en unidades de pi, cuantizado a S(16,14).
  function automatic integer true_phi(input integer xq, input integer yq);
    real r;
    r = $atan2(real'(yq), real'(xq)) / 3.141592653589793 * 16384.0;
    true_phi = (r >= 0) ? $rtoi(r + 0.5) : $rtoi(r - 0.5);
  endfunction

  function automatic integer quadrant(input integer xq, input integer yq);
    if (xq >= 0 && yq >= 0)      quadrant = 1;
    else if (xq < 0 && yq >= 0)  quadrant = 2;
    else if (xq < 0 && yq < 0)   quadrant = 3;
    else                         quadrant = 4;
  endfunction

  // ---------------------------------------------------------------------
  // Carga los vectores de test.
  // ---------------------------------------------------------------------
  task automatic load_vectors();
    integer f;
    begin
      n_vec = 0;
      f = $fopen("datos/vectors.hex", "r");
      while (!$feof(f) && n_vec < MAXV) begin
        if ($fscanf(f, "%h %h", xm[n_vec], ym[n_vec]) == 2)
          n_vec = n_vec + 1;
      end
      $fclose(f);
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector a ambos DUTs y verifica protocolo + exactitud.
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input integer vi);
    integer q, tR, tPhi, dRc, dRr, dPhic, dPhir;
    integer cycle;
    real ang_deg;
    begin
      // Esperamos a que ambos DUTs esten en IDLE.
      while (bc | br) @(posedge clk);

      // Aplicamos el estimulo a mitad de ciclo (setup garantizado).
      @(negedge clk);
      x = xm[vi];
      y = ym[vi];
      start = 1'b1;
      @(posedge clk);                   // flanco que muestrea start
      @(negedge clk);
      start = 1'b0;

      // ---- Latencia y protocolo (contador compartido desde start) ---------
      // Ambos DUTs arrancan con el mismo flanco; la referencia termina en 2
      // ciclos y el CORDIC en 16. Contamos los ciclos ABSOLUTOS desde start
      // para que la latencia de cada uno se mida contra el mismo origen.
      lat_r = -1;
      lat_c = -1;
      cycle = 0;
      while (lat_r < 0 || lat_c < 0) begin
        @(posedge clk);
        #1;                             // dejamos asentar el flanco (NBA)
        cycle = cycle + 1;
        // chequeo de pulso de 1 ciclo (el done del ciclo anterior debe ser 0)
        if (cycle == lat_r + 1 && dr) begin
          errors = errors + 1;
          $display("  ERROR [ref vec %0d]: done no es pulso de 1 ciclo", vi);
        end
        if (cycle == lat_c + 1 && dc) begin
          errors = errors + 1;
          $display("  ERROR [CORDIC vec %0d]: done no es pulso de 1 ciclo", vi);
        end
        if (lat_r < 0 && dr) lat_r = cycle;
        if (lat_c < 0 && dc) lat_c = cycle;
      end
      if (lat_r != 2) begin
        errors = errors + 1;
        $display("  ERROR [ref vec %0d]: latencia %0d ciclos (esperado 2)",
                 vi, lat_r);
      end
      if (lat_c != N_ITER) begin
        errors = errors + 1;
        $display("  ERROR [CORDIC vec %0d]: latencia %0d ciclos (esperado %0d)",
                 vi, lat_c, N_ITER);
      end

      // ---- Exactitud ----------------------------------------------------
      tR   = true_R(xm[vi], ym[vi]);
      tPhi = true_phi(xm[vi], ym[vi]);
      q    = quadrant(xm[vi], ym[vi]);

      dRc   = iabs($signed(Rc)   - tR);
      dRr   = iabs($signed(Rr)   - tR);
      dPhic = iabs($signed(phic) - tPhi);
      dPhir = iabs($signed(phir) - tPhi);

      // Cross-check CORDIC vs referencia (redondean distinto).
      if (iabs($signed(Rc) - $signed(Rr)) > TOL_R_X) begin
        errors = errors + 1;
        $display("  ERROR [cross R vec %0d]: CORDIC=%0d REF=%0d (x=%04x y=%04x)",
                 vi, Rc, Rr, xm[vi], ym[vi]);
      end
      if (iabs($signed(phic) - $signed(phir)) > TOL_P_X) begin
        errors = errors + 1;
        $display("  ERROR [cross phi vec %0d]: CORDIC=%0d REF=%0d (x=%04x y=%04x)",
                 vi, phic, phir, xm[vi], ym[vi]);
      end

      if (dRc > TOL_R_C) begin
        errors = errors + 1;
        $display("  ERROR [R CORDIC vec %0d]: err %0d ULP > %0d", vi, dRc, TOL_R_C);
      end
      if (dPhic > TOL_P_C) begin
        errors = errors + 1;
        $display("  ERROR [phi CORDIC vec %0d]: err %0d ULP > %0d", vi, dPhic, TOL_P_C);
      end
      if (dRr > TOL_R_R) begin
        errors = errors + 1;
        $display("  ERROR [R ref vec %0d]: err %0d ULP > %0d", vi, dRr, TOL_R_R);
      end
      if (dPhir > TOL_P_R) begin
        errors = errors + 1;
        $display("  ERROR [phi ref vec %0d]: err %0d ULP > %0d", vi, dPhir, TOL_P_R);
      end

      // ---- Acumulacion de estadisticas por cuadrante ---------------------
      n_q[q] = n_q[q] + 1;
      if (dRc > maxRc_q[q])   maxRc_q[q] = dRc;
      if (dRr > maxRr_q[q])   maxRr_q[q] = dRr;
      if (dPhic > maxPhic_q[q]) maxPhic_q[q] = dPhic;
      if (dPhir > maxPhir_q[q]) maxPhir_q[q] = dPhir;
      sumRc_q[q] = sumRc_q[q] + dRc;
      sumRr_q[q] = sumRr_q[q] + dRr;
      sumPhic_q[q] = sumPhic_q[q] + dPhic;
      sumPhir_q[q] = sumPhir_q[q] + dPhir;

      // ---- CSV para el analisis en Python -------------------------------
      ang_deg = $atan2(real'(ym[vi]), real'(xm[vi])) * 180.0 / 3.141592653589793;
      $fwrite(fd, "%0d,%.3f,%0d,%0d,%0d,%0d\n",
              q, ang_deg, dRc, dRr, dPhic, dPhir);
    end
  endtask

  // ---------------------------------------------------------------------
  // Verificacion principal.
  // ---------------------------------------------------------------------
  initial begin
    integer i;
    errors = 0;
    for (i = 1; i <= 4; i = i + 1) begin
      n_q[i] = 0;
      maxRc_q[i] = 0; maxRr_q[i] = 0;
      maxPhic_q[i] = 0; maxPhir_q[i] = 0;
      sumRc_q[i] = 0; sumRr_q[i] = 0;
      sumPhic_q[i] = 0; sumPhir_q[i] = 0;
    end

    // VCD selectivo: solo el CORDIC (principal) + senales del top. No
    // volcamos las ROMs de 64K de la referencia (harian el VCD enorme).
    $dumpfile("datos/tb_cordic_vect.vcd");
    $dumpvars(1, tb_cordic_vect);
    $dumpvars(0, dut_c);

    $display("");
    $display("==============================================================");
    $display("EJERCICIO 3 - CORDIC Vectoring: R y phi vs referencia directa");
    $display("==============================================================");

    rst_n = 1'b0;
    start = 1'b0;
    x = '0;
    y = '0;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    load_vectors();

    fd = $fopen("datos/errores.csv", "w");
    $fwrite(fd, "cuadrante,angulo_deg,errR_cordic_ulp,errR_ref_ulp,errPhi_cordic_ulp,errPhi_ref_ulp\n");

    $display("  Vectores cargados: %0d", n_vec);
    $display("");
    $display("  Verificando exactitud y protocolo...");
    for (i = 0; i < n_vec; i = i + 1)
      apply_and_check(i);

    $fclose(fd);

    // ---- Tabla error vs cuadrante (entregable d) -------------------------
    $display("");
    $display("==============================================================");
    $display("  Error vs cuadrante (R: 1 ULP = 2^-15, phi: 1 ULP = pi*2^-14)");
    $display("==============================================================");

    // Tabla alineada con anchos de columna FIJOS (deterministas), formateados
    // con $sformatf. No se usa .len() sobre arrays de string porque iverilog
    // reporta longitudes incorrectas; los anchos se fijan de antemano.

    // encabezado (anchos por columna: Q=2, n=5, R..=16, R ref..=14, phi..=11, phi re=9)
    $display("%2s | %5s | %-16s | %-14s | %-11s | %-9s",
             "Q", "n", "R CORDIC max/med", "R ref max/med", "phi CORDIC", "phi ref");

    // separador con los mismos anchos de columna que las filas:
    // Q=2, n=5, R CORDIC=16, R ref=14, phi CORDIC=11, phi ref=9.
    // Tramo de guiones por columna: ancho + un espacio a cada lado = +3.
    $write("---");                     // Q   (3)
    $write("+");                      // + separador
    for (pad = 0; pad < 6; pad = pad + 1) $write("-");     // n   (7)
    $write("-+");
    for (pad = 0; pad < 17; pad = pad + 1) $write("-");    // R   (18)
    $write("-+");
    for (pad = 0; pad < 15; pad = pad + 1) $write("-");    // Rref(16)
    $write("-+");
    for (pad = 0; pad < 12; pad = pad + 1) $write("-");    // phi (13)
    $write("-+");
    for (pad = 0; pad < 9; pad = pad + 1) $write("-");     // phiR (10)
    $write("-\n");

    // filas
    for (i = 1; i <= 4; i = i + 1) begin
      meanRc_q[i]   = real'(sumRc_q[i]) / n_q[i];
      meanRr_q[i]   = real'(sumRr_q[i]) / n_q[i];
      meanPhic_q[i] = real'(sumPhic_q[i]) / n_q[i];
      meanPhir_q[i] = real'(sumPhir_q[i]) / n_q[i];
      $display("%2s | %5s | %-16s | %-14s | %-11s | %-9s",
               $sformatf("%0d", i),
               $sformatf("%0d", n_q[i]),
               $sformatf("%0d/%0.2f", maxRc_q[i], meanRc_q[i]),
               $sformatf("%0d/%0.2f", maxRr_q[i], meanRr_q[i]),
               $sformatf("%0d/%0.2f", maxPhic_q[i], meanPhic_q[i]),
               $sformatf("%0d/%0.2f", maxPhir_q[i], meanPhir_q[i]));
    end

    // separador inferior con los mismos anchos
    $write("---");                     // Q   (3)
    $write("+");
    for (pad = 0; pad < 6; pad = pad + 1) $write("-");     // n   (7)
    $write("-+");
    for (pad = 0; pad < 17; pad = pad + 1) $write("-");    // R   (18)
    $write("-+");
    for (pad = 0; pad < 15; pad = pad + 1) $write("-");    // Rref(16)
    $write("-+");
    for (pad = 0; pad < 12; pad = pad + 1) $write("-");    // phi (13)
    $write("-+");
    for (pad = 0; pad < 9; pad = pad + 1) $write("-");     // phiR (10)
    $write("-\n");

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d vectores, CORDIC vs referencia vs verdad OK)", n_vec);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule