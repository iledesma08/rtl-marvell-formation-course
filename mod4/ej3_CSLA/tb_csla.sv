// tb_csla.sv — Testbench self-checking para el CSLA de 16 bits (Ejercicio 3).
// Reutiliza el estilo de los testbenches de los ejercicios 1 y 2.
//
// Verifica:
//   1. rca4 exhaustivo: las 256 combinaciones de (a,b) x 2 de cin, contra
//      a + b + cin en 5 bits.
//   2. csla16 bordes:  0+0, max+max (carry-out=1), max+0 con cin=1, max+1.
//   3. csla16 random:  1000 vectores comparados contra a + b + cin en 17 bits,
//      con cross-check contra el RCA16 (ejercicio 1) y las DOS versiones del
//      CLA16 (ejercicio 2: v1 de un nivel y v2 de dos niveles) estimulados con
//      lo mismo: cuatro sumadores correctos deben coincidir.
//
// Ademas mide el delay del peor caso (carry de bit 0 hasta bit 15) para el
// CSLA16, el CLA16 v1, el CLA16 v2 y el RCA16 por separado y reporta la tabla
// comparativa que pide el enunciado. Todos comparten el mismo modelo de
// compuertas (xor=2ns, and/or/not=1ns), asi que la comparacion es justa.
// Reporta PASS/FAIL con $display.

`timescale 1ns/1ps

module tb_csla;
  localparam int N16   = 16;    // ancho del CSLA
  localparam int NRAND = 1000;  // cantidad de casos random (igual que ej. 2)

  // Conteo estructural de compuertas (para la tabla).
  // En SystemVerilog puro no hay forma de "reflejar" la jerarquia y contar
  // instancias automaticamente (eso se haria con VPI en C segun investigue), 
  // asi que el total se deriva de los costos de las celdas y de las formulas 
  // estructurales de cada arquitectura, en vez de escribir numeros magicos.
  // El run.sh ademas lo VERIFICA con Yosys contra el netlist real.
  //
  // Costo de cada celula (documentado en su propio modulo):
  //   full_adder (ej1/full_adder.sv): 2 xor + 2 and + 1 or = 5 gates
  //   mux2  (en csla16.sv)           : not + 2 and + 1 or   = 4 gates
  //   cla4  (ej2/v1/cla4.sv)         : gp(8) + prefijos(3) + lookahead
  //                                    c1..c4 (2+4+6+8) + sum(4) = 35 gates
  //   cla4_v2 (ej2/v2/cla4.sv)       : cla4 + 1 or (G de bloque) = 36 gates
  // Formulas estructurales:
  //   rca4  = 4 x full_adder
  //   rca16 = 16 x full_adder
  //   cla16 (v1) = 4 x cla4
  //   cla16 (v2) = 4 x cla4_v2 + lookahead de bloque
  //                (3 prefijos + c1..c4 entre bloques 2+4+6+8 = 23 gates)
  //   csla16 = bloque0 (1 rca4) + 3 bloques x (2 rca4 + 4 sum_mux + 1 cout_mux)
  //
  // Nota: el lookahead de bloque del cla16_v2 se cuenta sin el or de su salida
  // G (no conectada): Yosys lo poda del netlist y en sintesis no existiria.
  localparam int GATES_FA      = 5;                                // full_adder.sv
  localparam int GATES_MUX2    = 4;                                // mux2 (csla16)
  localparam int GATES_CLA4    = 35;                               // v1/cla4.sv
  localparam int GATES_CLA4_V2 = GATES_CLA4 + 1;                   // v2/cla4.sv (36)
  localparam int GATES_LA2     = 23;                               // lookahead bloque cla16_v2
  localparam int GATES_RCA4    = 4 * GATES_FA;                                         // 20
  localparam int GATES_RCA     = 16 * GATES_FA;                                        // 80
  localparam int GATES_CLA     = 4 * GATES_CLA4;                                       // 140
  localparam int GATES_CLA_V2  = 4 * GATES_CLA4_V2 + GATES_LA2;                        // 167
  localparam int GATES_CSLA    = GATES_RCA4 + 3 * (2 * GATES_RCA4 + 5 * GATES_MUX2);   // 200

  // ---- Senales del DUT CSLA16 y de las referencias RCA16 / CLA16 ----------
  logic [15:0] a;
  logic [15:0] b;
  logic        cin;
  logic [15:0] sum_csla;
  logic        cout_csla;
  logic [15:0] sum_rca;
  logic        cout_rca;
  logic [15:0] sum_cla;
  logic        cout_cla;
  logic [15:0] sum_cla_v2;
  logic        cout_cla_v2;

  // ---- Senales para el rca4 (verificacion exhaustiva) ----------------------
  logic [3:0]  a4;
  logic [3:0]  b4;
  logic        cin4;
  logic [3:0]  sum4;
  logic        cout4;

  logic [16:0] expected;   // a + b + cin extendido a 17 bits
  logic [4:0]  expected4;  // a4 + b4 + cin4 extendido a 5 bits

  // ---- Medicion de delay ---------------------------------------------------
  time t0;
  time t_last_csla_cout;   // ultimo cambio del carry-out del CSLA16
  time t_last_csla_sum;    // ultimo cambio del bit sum[15] del CSLA16
  time t_last_cla_cout;    // ultimo cambio del carry-out del CLA16 v1
  time t_last_cla_sum;     // ultimo cambio del bit sum[15] del CLA16 v1
  time t_last_cla_v2_cout; // ultimo cambio del carry-out del CLA16 v2
  time t_last_cla_v2_sum;  // ultimo cambio del bit sum[15] del CLA16 v2
  time t_last_rca_cout;    // ultimo cambio del carry-out del RCA16
  time t_last_rca_sum;     // ultimo cambio del bit sum[15] del RCA16
  time d_csla_cout, d_csla_sum;
  time d_cla_cout,  d_cla_sum;
  time d_cla_v2_cout, d_cla_v2_sum;
  time d_rca_cout,  d_rca_sum;

  integer errors;
  integer i;
  integer seed = 2026;

  // ---------------------------------------------------------------------
  // DUTs: csla16 (bajo prueba), rca16 y cla16 (referencias para delay y
  // cross-check) y rca4 (para la verificacion exhaustiva del bloque).
  // ---------------------------------------------------------------------
  csla16 dut      (.a(a), .b(b), .cin(cin), .sum(sum_csla), .cout(cout_csla));
  rca    #(.N(16)) dut_rca (.a(a), .b(b), .cin(cin), .sum(sum_rca), .cout(cout_rca));
  cla16  dut_cla  (.a(a), .b(b), .cin(cin), .sum(sum_cla),  .cout(cout_cla));
  cla16_v2 dut_cla_v2 (.a(a), .b(b), .cin(cin), .sum(sum_cla_v2), .cout(cout_cla_v2));
  rca4   dut4     (.a(a4), .b(b4), .cin(cin4), .sum(sum4),  .cout(cout4));

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_csla.vcd");
    $dumpvars(0, tb_csla);
  end

  // Monitores POR SEPARADO del carry-out y del bit mas significativo de la
  // suma, de las tres arquitecturas. Son caminos distintos del path critico.
  always @(cout_csla)   t_last_csla_cout = $time;
  always @(sum_csla[15]) t_last_csla_sum = $time;
  always @(cout_cla)    t_last_cla_cout = $time;
  always @(sum_cla[15])  t_last_cla_sum = $time;
  always @(cout_cla_v2)    t_last_cla_v2_cout = $time;
  always @(sum_cla_v2[15])  t_last_cla_v2_sum = $time;
  always @(cout_rca)    t_last_rca_cout = $time;
  always @(sum_rca[15])  t_last_rca_sum = $time;

  // ---------------------------------------------------------------------
  // Aplica un vector al rca4 y lo chequea contra a4 + b4 + cin4 (5 bits).
  // ---------------------------------------------------------------------
  task automatic apply_rca4(input string tag, input logic [3:0] va,
                            input logic [3:0] vb, input logic vcin);
    begin
      a4 = va; b4 = vb; cin4 = vcin;
      #15;                              // rca4 estabiliza en ~10 ns
      expected4 = va + vb + vcin;
      if ((sum4 !== expected4[3:0]) || (cout4 !== expected4[4])) begin
        errors = errors + 1;
        $display("  ERROR [rca4 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum4, cout4, expected4[3:0], expected4[4]);
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Aplica un vector al csla16 y lo chequea contra a + b + cin (17 bits).
  // Ademas lo cross-checkea contra el RCA16 y los dos CLA16 (v1 y v2): con la
  // misma estimulacion, cuatro sumadores correctos tienen que dar lo mismo.
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input string tag, input logic [15:0] va,
                                 input logic [15:0] vb, input logic vcin);
    begin
      a = va; b = vb; cin = vcin;
      #(2 * N16 + 5);                    // esperamos a que estabilice lo mas lento
      expected = va + vb + vcin;
      if ((sum_csla !== expected[15:0]) || (cout_csla !== expected[16])) begin
        errors = errors + 1;
        $display("  ERROR [csla16 %s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum_csla, cout_csla, expected[15:0], expected[16]);
      end
      if ((sum_csla !== sum_rca) || (cout_csla !== cout_rca)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check RCA %s]: CSLA y RCA difieren (csla: sum=%0h cout=%b | rca: sum=%0h cout=%b)",
                 tag, sum_csla, cout_csla, sum_rca, cout_rca);
      end
      if ((sum_csla !== sum_cla) || (cout_csla !== cout_cla)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check CLA v1 %s]: CSLA y CLA v1 difieren (csla: sum=%0h cout=%b | cla v1: sum=%0h cout=%b)",
                 tag, sum_csla, cout_csla, sum_cla, cout_cla);
      end
      if ((sum_csla !== sum_cla_v2) || (cout_csla !== cout_cla_v2)) begin
        errors = errors + 1;
        $display("  ERROR [cross-check CLA v2 %s]: CSLA y CLA v2 difieren (csla: sum=%0h cout=%b | cla v2: sum=%0h cout=%b)",
                 tag, sum_csla, cout_csla, sum_cla_v2, cout_cla_v2);
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
    $display("EJERCICIO 3 - Carry Select Adder 16 bits en 4 bloques de 4");
    $display("==============================================================");

    // ---- 1. rca4 exhaustivo: todas las (a,b) x cin ---------------------
    $display("");
    $display("  [1/3] Verificando rca4 de forma exhaustiva (512 vectores)...");
    for (i = 0; i < 256; i = i + 1) begin
      apply_rca4("exhaustivo", i[3:0], i[7:4], 1'b0);
      apply_rca4("exhaustivo", i[3:0], i[7:4], 1'b1);
    end

    // ---- 2. csla16 bordes ------------------------------------------------
    $display("  [2/3] Verificando csla16 en los bordes...");
    apply_and_check("0+0",     '0, '0, 1'b0);
    apply_and_check("max+max", '1, '1, 1'b0);   // carry-out = 1
    apply_and_check("max+cin", '1, '0, 1'b1);   // carry-out = 1
    apply_and_check("max+1",   '1, 1, 1'b0);    // sum=0, cout=1

    // ---- 3. csla16 con 1000 vectores random -----------------------------
    $display("  [3/3] Verificando csla16 con %0d vectores random...", NRAND);
    for (i = 0; i < NRAND; i = i + 1)
      apply_and_check("random", $urandom(seed), $urandom(seed), $urandom(seed) & 1'b1);

    // ---- Medicion de delay (peor caso: carry de bit 0 hasta bit 15) -----
    // Partimos de (0,0,0) y aplicamos (max,1,0): el bit 0 genera carry y este
    // tiene que llegar hasta el final. Para el RCA son 16 saltos de ~2ns; para
    // el CLA v1, 4 saltos de bloque con lookahead interno; para el CLA v2, el
    // lookahead entre bloques en paralelo; para el CSLA, un RCA de 4 bits + 3
    // muxes de bloque. Medimos por separado cout y sum[15] en las cuatro
    // arquitecturas, con los monitores.
    a = '0; b = '0; cin = 1'b0;
    #(2 * N16 + 10);                     // dejamos estabilizar el estado previo
    t0 = $time;
    t_last_csla_cout = t0; t_last_csla_sum = t0;
    t_last_cla_cout  = t0; t_last_cla_sum  = t0;
    t_last_cla_v2_cout = t0; t_last_cla_v2_sum = t0;
    t_last_rca_cout  = t0; t_last_rca_sum  = t0;
    a = '1; b = 1; cin = 1'b0;           // aplicamos el estimulo del peor caso
    #(2 * N16 + 30);                     // tiempo suficiente para que estabilice
    d_csla_cout = t_last_csla_cout - t0;
    d_csla_sum  = t_last_csla_sum  - t0;
    d_cla_cout  = t_last_cla_cout  - t0;
    d_cla_sum   = t_last_cla_sum   - t0;
    d_cla_v2_cout = t_last_cla_v2_cout - t0;
    d_cla_v2_sum  = t_last_cla_v2_sum  - t0;
    d_rca_cout  = t_last_rca_cout  - t0;
    d_rca_sum   = t_last_rca_sum   - t0;

    $display("");
    $display("==============================================================");
    $display("  Tabla comparativa CSLA vs CLA (v1 y v2) vs RCA (N = 16)");
    $display("==============================================================");
    $display("  Arquitectura  | delay cout [ns]  | delay sum[15] [ns] | gates");
    $display("----------------+------------------+--------------------+------");
    $display("  CSLA16        |       %0d         |         %0d         |  %0d", d_csla_cout, d_csla_sum, GATES_CSLA);
    $display("  CLA16 v1 (1N) |       %0d         |         %0d         |  %0d", d_cla_cout,  d_cla_sum,  GATES_CLA);
    $display("  CLA16 v2 (2N) |       %0d         |         %0d         |  %0d", d_cla_v2_cout, d_cla_v2_sum, GATES_CLA_V2);
    $display("  RCA16         |       %0d         |         %0d         |  %0d", d_rca_cout,  d_rca_sum,  GATES_RCA);
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (rca4 exhaustivo, bordes, %0d random y delay OK)", NRAND);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule