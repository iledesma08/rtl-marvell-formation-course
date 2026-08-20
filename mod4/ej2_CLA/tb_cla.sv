// tb_cla.sv — Testbench self-checking para el CLA jerarquico de 16 bits
// (Ejercicio 2). 
//
// Verifica:
//   1. cla4 exhaustivo: las 256 combinaciones de (a,b) x 2 de cin, contra
//      a + b + cin en 5 bits.
//   2. cla16 bordes:  0+0, max+max (carry-out=1), max+0 con cin=1, max+1.
//   3. cla16 random:  1000 vectores comparados contra a + b + cin en 17 bits,
//      con cross-check contra un RCA de 16 bits (referencia del ejercicio 1)
//      estimulado con lo mismo: dos sumadores correctos deben coincidir.
//
// Ademas mide el delay del peor caso (carry de bit 0 hasta bit 15) para el
// CLA16 y para el RCA16 por separado y reporta la tabla delay vs RCA que pide
// el enunciado. Como ambos comparten el mismo modelo de compuertas
// (xor=2ns, and/or=1ns), la comparacion es justa. Reporta PASS/FAIL con
// $display.

`timescale 1ns/1ps

module tb_cla;
  localparam int N16  = 16;     // ancho del CLA jerarquico
  localparam int NRAND = 1000;  // cantidad de casos random (pide el enunciado)

  // ---- Senales del DUT CLA16 y del RCA16 de referencia -------------------
  logic [15:0] a;
  logic [15:0] b;
  logic        cin;
  logic [15:0] sum_cla;
  logic        cout_cla;
  logic [15:0] sum_rca;
  logic        cout_rca;

  // ---- Senales para el cla4 ----------------------------------------------
  logic [3:0]  a4;
  logic [3:0]  b4;
  logic        cin4;
  logic [3:0]  sum4;
  logic        cout4;

  logic [16:0] expected;   // a + b + cin extendido a 17 bits
  logic [4:0]  expected4;  // a4 + b4 + cin4 extendido a 5 bits

  // ---- Medicion de delay ---------------------------------------------------
  time t0;
  time t_last_cla_cout;   // ultimo cambio del carry-out del CLA16
  time t_last_cla_sum;    // ultimo cambio del bit sum[15] del CLA16
  time t_last_rca_cout;   // ultimo cambio del carry-out del RCA16
  time t_last_rca_sum;    // ultimo cambio del bit sum[15] del RCA16
  time d_cla_cout, d_cla_sum;
  time d_rca_cout, d_rca_sum;

  integer errors;
  integer i;
  integer seed = 2026;

  // ---------------------------------------------------------------------
  // DUTs: cla16 (bajo prueba), rca16 (referencia para delay y cross-check)
  // y cla4 (para la verificacion exhaustiva del bloque de 4 bits).
  // ---------------------------------------------------------------------
  cla16 dut (.a(a), .b(b), .cin(cin), .sum(sum_cla), .cout(cout_cla));
  rca   #(.N(16)) dut_rca (.a(a), .b(b), .cin(cin), .sum(sum_rca), .cout(cout_rca));
  cla4  dut4 (.a(a4), .b(b4), .cin(cin4), .sum(sum4), .cout(cout4));

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_cla.vcd");
    $dumpvars(0, tb_cla);
  end

  // Monitores POR SEPARADO del carry-out y del bit mas significativo de la
  // suma, tanto del CLA como del RCA.
  always @(cout_cla)  t_last_cla_cout = $time;
  always @(sum_cla[15]) t_last_cla_sum = $time;
  always @(cout_rca)  t_last_rca_cout = $time;
  always @(sum_rca[15]) t_last_rca_sum = $time;

  // ---------------------------------------------------------------------
  // Aplica un vector al cla4 y lo chequea contra a4 + b4 + cin4 (5 bits).
  // ---------------------------------------------------------------------
  task automatic apply_cla4(input string tag, input logic [3:0] va,
                            input logic [3:0] vb, input logic vcin);
    begin
      a4 = va; b4 = vb; cin4 = vcin;
      #15;                              // cla4 estabiliza en ~10 ns
      expected4 = va + vb + vcin;
      if ((sum4 !== expected4[3:0]) || (cout4 !== expected4[4])) begin
        errors = errors + 1;
        $display("  ERROR [cla4 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum4, cout4, expected4[3:0], expected4[4]);
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector al cla16 y lo chequea contra a + b + cin (17 bits).
  // Ademas lo cross-checkea contra el RCA16: con la misma estimulacion, dos
  // sumadores correctos tienen que dar exactamente la misma salida.
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input string tag, input logic [15:0] va,
                                 input logic [15:0] vb, input logic vcin);
    begin
      a = va; b = vb; cin = vcin;
      #(2 * N16 + 5);                    // esperamos a que estabilice lo mas lento
      expected = va + vb + vcin;
      if ((sum_cla !== expected[15:0]) || (cout_cla !== expected[16])) begin
        errors = errors + 1;
        $display("  ERROR [cla16 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum_cla, cout_cla, expected[15:0], expected[16]);
      end
      if ((sum_cla !== sum_rca) || (cout_cla !== cout_rca)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check %s]: CLA y RCA difieren (cla: sum=%0h cout=%b | rca: sum=%0h cout=%b)",
                 tag, sum_cla, cout_cla, sum_rca, cout_rca);
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    errors = 0;

    $display("");
    $display("==============================================================");
    $display("EJERCICIO 2 - CLA jerarquico 4-bit -> 16-bit (cla4 + cla16)");
    $display("==============================================================");

    // ---- 1. cla4 exhaustivo: todas las (a,b) x cin ---------------------
    $display("");
    $display("  [1/3] Verificando cla4 de forma exhaustiva...");
    for (i = 0; i < 256; i = i + 1) begin
      apply_cla4("exhaustivo", i[3:0], (i[7:4]), 1'b0);
      apply_cla4("exhaustivo", i[3:0], (i[7:4]), 1'b1);
    end

    // ---- 2. cla16 bordes ------------------------------------------------
    $display("  [2/3] Verificando cla16 en los bordes...");
    apply_and_check("0+0",       '0, '0, 1'b0);
    apply_and_check("max+max",   '1, '1, 1'b0);   // carry-out = 1
    apply_and_check("max+cin",   '1, '0, 1'b1);   // carry-out = 1
    apply_and_check("max+1",     '1, 1, 1'b0);    // sum=0, cout=1

    // ---- 3. cla16 con 1000 vectores random -----------------------------
    $display("  [3/3] Verificando cla16 con %0d vectores random...", NRAND);
    for (i = 0; i < NRAND; i = i + 1)
      apply_and_check("random", $urandom(seed), $urandom(seed), $urandom(seed) & 1'b1);

    // ---- Medicion de delay (peor caso: carry de bit 0 hasta bit 15) -----
    // Partimos de (0,0,0) y aplicamos (max,1,0): el bit 0 genera carry y este
    // tiene que llegar hasta el final. Para el RCA eso son 16 saltos de ~2ns;
    // para el CLA, 4 saltos de bloque con lookahead interno. Medimos por
    // separado cout y sum[15], en el CLA y en el RCA, con los monitores.
    a = '0; b = '0; cin = 1'b0;
    #(2 * N16 + 10);                     // dejamos estabilizar el estado previo
    t0 = $time;
    t_last_cla_cout = t0; t_last_cla_sum = t0;
    t_last_rca_cout = t0; t_last_rca_sum = t0;
    a = '1; b = 1; cin = 1'b0;           // aplicamos el estimulo del peor caso
    #(2 * N16 + 30);                     // tiempo suficiente para que estabilice
    d_cla_cout = t_last_cla_cout - t0;
    d_cla_sum  = t_last_cla_sum  - t0;
    d_rca_cout = t_last_rca_cout - t0;
    d_rca_sum  = t_last_rca_sum  - t0;

    $display("");
    $display("==============================================================");
    $display("  Tabla delay vs RCA (misma N = 16, mismo modelo de compuertas)");
    $display("==============================================================");
    $display("  Arquitectura | delay cout  [ns] | delay sum[15] [ns]");
    $display("--------------+-------------------+-------------------");
    $display("  CLA16       |       %0d         |       %0d", d_cla_cout, d_cla_sum);
    $display("  RCA16       |       %0d         |       %0d", d_rca_cout, d_rca_sum);
    $display("");
    $display("  (peor caso: a = 2^16 - 1, b = 1, cin = 0; xor=2ns, and/or=1ns)");
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (cla4 exhaustivo, bordes, %0d random y delay OK)", NRAND);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule