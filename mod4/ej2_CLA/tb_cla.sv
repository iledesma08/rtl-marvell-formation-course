// tb_cla.sv — Testbench self-checking que testea y COMPARA las dos versiones
// del CLA jerarquico de 16 bits (v1: un nivel de lookahead; v2: dos niveles)
// junto con el RCA16 de referencia del ejercicio 1, como pide el enunciado.
//
// Combina el testbench de v1 (que a su vez sigue el estilo del ejercicio 1)
// con la version de dos niveles: los tres sumadores se estimulan juntos.
//
// Verifica:
//   1. cla4 v1 exhaustivo: las 256 combinaciones de (a,b) x 2 de cin, contra
//      a + b + cin en 5 bits.
//   2. cla4 v2 exhaustivo (igual que v1) y ademas valida sus senales de bloque
//      G y P:  cout(cin=0) == G  y  cout(cin=1) == G | P.
//   3. cla16 v1 y v2 en bordes y con 1000 vectores random, comparados contra
//      a + b + cin en 17 bits.
//   4. Cross-check entre CLA16 v1, CLA16 v2 y RCA16: tres implementaciones
//      correctas de la misma operacion deben coincidir siempre.
//
// Ademas mide el delay del peor caso (carry de bit 0 hasta bit 15) para CLA16
// v1, CLA16 v2 y RCA16 por separado y reporta la tabla delay que pide el
// enunciado. Como todos comparten el mismo modelo de compuertas
// (xor=2ns, and/or=1ns), la comparacion es justa. Reporta PASS/FAIL con
// $display.

`timescale 1ns/1ps

module tb_cla;
  localparam int N16  = 16;     // ancho del CLA jerarquico
  localparam int NRAND = 1000;  // cantidad de casos random (pide el enunciado)

  // ---- Senales del DUT CLA16 v1, CLA16 v2 y RCA16 de referencia -----------
  logic [15:0] a;
  logic [15:0] b;
  logic        cin;
  logic [15:0] sum_cla_v1;
  logic        cout_cla_v1;
  logic [15:0] sum_cla_v2;
  logic        cout_cla_v2;
  logic [15:0] sum_rca;
  logic        cout_rca;

  // ---- Senales para el cla4 v1 --------------------------------------------
  logic [3:0]  a4;
  logic [3:0]  b4;
  logic        cin4;
  logic [3:0]  sum4;
  logic        cout4;

  // ---- Senales para el cla4 v2 (con G y P de bloque) ----------------------
  logic [3:0]  a4b;
  logic [3:0]  b4b;
  logic        cin4b;
  logic [3:0]  sum4b;
  logic        cout4b;
  logic        G4b;
  logic        P4b;

  logic [16:0] expected;   // a + b + cin extendido a 17 bits
  logic [4:0]  expected4;  // a4 + b4 + cin4 extendido a 5 bits

  // ---- Medicion de delay ---------------------------------------------------
  time t0;
  time t_last_cla1_cout;   // ultimo cambio del carry-out del CLA16 v1
  time t_last_cla1_sum;    // ultimo cambio del bit sum[15] del CLA16 v1
  time t_last_cla2_cout;   // ultimo cambio del carry-out del CLA16 v2
  time t_last_cla2_sum;    // ultimo cambio del bit sum[15] del CLA16 v2
  time t_last_rca_cout;    // ultimo cambio del carry-out del RCA16
  time t_last_rca_sum;     // ultimo cambio del bit sum[15] del RCA16
  time d_cla1_cout, d_cla1_sum;
  time d_cla2_cout, d_cla2_sum;
  time d_rca_cout, d_rca_sum;

  integer errors;
  integer i;
  integer match_count;   // vectores donde CLA16 v1 y v2 coinciden
  integer seed = 2026;

  // ---------------------------------------------------------------------
  // DUTs: cla16 v1 y v2 (bajo prueba), rca16 (referencia para delay y
  // cross-check) y los cla4 de 4 bits (para la verificacion exhaustiva).
  // ---------------------------------------------------------------------
  cla16   dut_v1 (.a(a), .b(b), .cin(cin), .sum(sum_cla_v1), .cout(cout_cla_v1));
  cla16_v2 dut_v2 (.a(a), .b(b), .cin(cin), .sum(sum_cla_v2), .cout(cout_cla_v2));
  rca     #(.N(16)) dut_rca (.a(a), .b(b), .cin(cin), .sum(sum_rca), .cout(cout_rca));
  cla4    dut4 (.a(a4), .b(b4), .cin(cin4), .sum(sum4), .cout(cout4));
  cla4_v2 dut4b (.a(a4b), .b(b4b), .cin(cin4b), .sum(sum4b), .cout(cout4b),
                 .G(G4b), .P(P4b));

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_cla.vcd");
    $dumpvars(0, tb_cla);
  end

  // Monitores POR SEPARADO del carry-out y del bit mas significativo de la
  // suma, del CLA v1, del CLA v2 y del RCA.
  always @(cout_cla_v1)  t_last_cla1_cout = $time;
  always @(sum_cla_v1[15]) t_last_cla1_sum = $time;
  always @(cout_cla_v2)  t_last_cla2_cout = $time;
  always @(sum_cla_v2[15]) t_last_cla2_sum = $time;
  always @(cout_rca)  t_last_rca_cout = $time;
  always @(sum_rca[15]) t_last_rca_sum = $time;

  // ---------------------------------------------------------------------
  // Aplica un vector al cla4 v1 y lo chequea contra a4 + b4 + cin4 (5 bits).
  // ---------------------------------------------------------------------
  task automatic apply_cla4_v1(input string tag, input logic [3:0] va,
                               input logic [3:0] vb, input logic vcin);
    begin
      a4 = va; b4 = vb; cin4 = vcin;
      #15;                              // cla4 estabiliza en ~10 ns
      expected4 = va + vb + vcin;
      if ((sum4 !== expected4[3:0]) || (cout4 !== expected4[4])) begin
        errors = errors + 1;
        $display("  ERROR [cla4 v1 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum4, cout4, expected4[3:0], expected4[4]);
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector al cla4 v2, chequea sum/cout y valida G/P de bloque:
  //   cout(cin=0) == G   y   cout(cin=1) == G | P.
  // ---------------------------------------------------------------------
  task automatic apply_cla4_v2(input string tag, input logic [3:0] va,
                               input logic [3:0] vb, input logic vcin);
    begin
      a4b = va; b4b = vb; cin4b = vcin;
      #15;                              // cla4 estabiliza en ~10 ns
      expected4 = va + vb + vcin;
      if ((sum4b !== expected4[3:0]) || (cout4b !== expected4[4])) begin
        errors = errors + 1;
        $display("  ERROR [cla4 v2 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum4b, cout4b, expected4[3:0], expected4[4]);
      end
      if (vcin == 1'b0) begin
        if (G4b !== cout4b) begin
          errors = errors + 1;
          $display("  ERROR [cla4 v2 G %s]: a=%0h b=%0h -> G=%b != cout(cin=0)=%b",
                   tag, va, vb, G4b, cout4b);
        end
      end else begin
        if ((G4b | P4b) !== cout4b) begin
          errors = errors + 1;
          $display("  ERROR [cla4 v2 G|P %s]: a=%0h b=%0h -> G=%b P=%b, G|P=%b != cout(cin=1)=%b",
                   tag, va, vb, G4b, P4b, (G4b | P4b), cout4b);
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector a los dos cla16 y al RCA16. Chequea cada CLA contra
  // a + b + cin (17 bits) y cross-checkea las tres implementaciones: con la
  // misma estimulacion, tres sumadores correctos tienen que coincidir.
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input string tag, input logic [15:0] va,
                                 input logic [15:0] vb, input logic vcin);
    begin
      a = va; b = vb; cin = vcin;
      #(2 * N16 + 5);                    // esperamos a que estabilice lo mas lento
      expected = va + vb + vcin;
      if ((sum_cla_v1 !== expected[15:0]) || (cout_cla_v1 !== expected[16])) begin
        errors = errors + 1;
        $display("  ERROR [cla16 v1 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum_cla_v1, cout_cla_v1, expected[15:0], expected[16]);
      end
      if ((sum_cla_v2 !== expected[15:0]) || (cout_cla_v2 !== expected[16])) begin
        errors = errors + 1;
        $display("  ERROR [cla16 v2 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum_cla_v2, cout_cla_v2, expected[15:0], expected[16]);
      end
      if ((sum_cla_v1 !== sum_cla_v2) || (cout_cla_v1 !== cout_cla_v2)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check v1-v2 %s]: CLA v1 y v2 difieren (v1: sum=%0h cout=%b | v2: sum=%0h cout=%b)",
                 tag, sum_cla_v1, cout_cla_v1, sum_cla_v2, cout_cla_v2);
      end
      if ((sum_cla_v2 !== sum_rca) || (cout_cla_v2 !== cout_rca)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check v2-RCA %s]: CLA v2 y RCA difieren (v2: sum=%0h cout=%b | rca: sum=%0h cout=%b)",
                 tag, sum_cla_v2, cout_cla_v2, sum_rca, cout_rca);
      end
      if ((sum_cla_v1 === sum_cla_v2) && (cout_cla_v1 === cout_cla_v2))
        match_count = match_count + 1;
    end
  endtask

  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    errors = 0;
    match_count = 0;

    $display("");
    $display("==============================================================");
    $display("EJERCICIO 2 - CLA jerarquico 4-bit -> 16-bit");
    $display("  v1: un nivel de lookahead (cla4 + cla16)");
    $display("  v2: dos niveles, con G/P de bloque (cla4_v2 + cla16_v2)");
    $display("  referencias: RCA16 (ejercicio 1)");
    $display("==============================================================");

    // ---- 1. cla4 v1 exhaustivo: todas las (a,b) x cin ------------------
    $display("");
    $display("  [1/4] Verificando cla4 v1 de forma exhaustiva...");
    for (i = 0; i < 256; i = i + 1) begin
      apply_cla4_v1("exhaustivo", i[3:0], (i[7:4]), 1'b0);
      apply_cla4_v1("exhaustivo", i[3:0], (i[7:4]), 1'b1);
    end

    // ---- 2. cla4 v2 exhaustivo + validacion de G/P ---------------------
    $display("  [2/4] Verificando cla4 v2 de forma exhaustiva (con G/P de bloque)...");
    for (i = 0; i < 256; i = i + 1) begin
      apply_cla4_v2("exhaustivo", i[3:0], (i[7:4]), 1'b0);
      apply_cla4_v2("exhaustivo", i[3:0], (i[7:4]), 1'b1);
    end

    // ---- 3. cla16 v1 y v2 en los bordes ---------------------------------
    $display("  [3/4] Verificando cla16 v1 y v2 en los bordes...");
    apply_and_check("0+0",       '0, '0, 1'b0);
    apply_and_check("max+max",   '1, '1, 1'b0);   // carry-out = 1
    apply_and_check("max+cin",   '1, '0, 1'b1);   // carry-out = 1
    apply_and_check("max+1",     '1, 1, 1'b0);    // sum=0, cout=1

    // ---- 4. cla16 v1 y v2 con 1000 vectores random ---------------------
    $display("  [4/4] Verificando cla16 v1 y v2 con %0d vectores random...", NRAND);
    for (i = 0; i < NRAND; i = i + 1)
      apply_and_check("random", $urandom(seed), $urandom(seed), $urandom(seed) & 1'b1);

    // ---- Medicion de delay (peor caso: carry de bit 0 hasta bit 15) -----
    // Partimos de (0,0,0) y aplicamos (max,1,0): el bit 0 genera carry y este
    // tiene que llegar hasta el final. Medimos por separado cout y sum[15]
    // del CLA v1, del CLA v2 y del RCA, con los monitores.
    a = '0; b = '0; cin = 1'b0;
    #(2 * N16 + 10);                     // dejamos estabilizar el estado previo
    t0 = $time;
    t_last_cla1_cout = t0; t_last_cla1_sum = t0;
    t_last_cla2_cout = t0; t_last_cla2_sum = t0;
    t_last_rca_cout = t0; t_last_rca_sum = t0;
    a = '1; b = 1; cin = 1'b0;           // aplicamos el estimulo del peor caso
    #(2 * N16 + 30);                     // tiempo suficiente para que estabilice
    d_cla1_cout = t_last_cla1_cout - t0;
    d_cla1_sum  = t_last_cla1_sum  - t0;
    d_cla2_cout = t_last_cla2_cout - t0;
    d_cla2_sum  = t_last_cla2_sum  - t0;
    d_rca_cout = t_last_rca_cout - t0;
    d_rca_sum  = t_last_rca_sum  - t0;

    $display("");
    $display("==============================================================");
    $display("  Tabla delay vs RCA (misma N = 16, mismo modelo de compuertas)");
    $display("==============================================================");
    $display("  Arquitectura  | delay cout  [ns] | delay sum[15] [ns]");
    $display("---------------+-------------------+-------------------");
    $display("  CLA16 v1 (1N) |       %0d         |       %0d", d_cla1_cout, d_cla1_sum);
    $display("  CLA16 v2 (2N) |       %0d         |       %0d", d_cla2_cout, d_cla2_sum);
    $display("  RCA16         |       %0d         |       %0d", d_rca_cout, d_rca_sum);
    $display("");
    $display("  (peor caso: a = 2^16 - 1, b = 1, cin = 0; xor=2ns, and/or=1ns)");
    $display("");

    if (match_count != (4 + NRAND))
      $display("  ATENCION: CLA16 v1 y v2 solo coincidieron en %0d de %0d vectores", match_count, 4 + NRAND);
    else
      $display("  CLA16 v1 y v2 coincidieron en los %0d vectores (bordes + random)", match_count);

    if (errors == 0)
      $display("RESULTADO: PASS  (cla4 v1+v2 exhaustivo, bordes, %0d random, cross-check y delay OK)", NRAND);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule