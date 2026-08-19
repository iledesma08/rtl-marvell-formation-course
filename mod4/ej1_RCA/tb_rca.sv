// tb_rca.sv — Testbench self-checking para el Ripple Carry Adder (Ejercicio 1).
//
// Cubre los casos que pide el enunciado:
//   1. Borde inferior:     0 + 0
//   2. Borde superior:     max + max
//   3. Caso con carry-out: max + 1  (el carry riplea por toda la cadena)
//   4. 500 casos random    (comparados contra a + b + cin en N+1 bits)
//
// Como el DUT es estructural con gate delays (xor=2ns, and/or=1ns), cada
// estímulo se aplica y se espera a que las salidas se estabilicen antes de
// chequear. Ademas mide el delay del peor caso (ripple de carry) y reporta la
// cantidad de full adders usados. Reporta PASS/FAIL con $display.
`timescale 1ns/1ps

module tb_rca;
  localparam int N = 8;               // ancho del DUT (default del enunciado)
  localparam int NRAND = 500;         // cantidad de casos random

  logic [N-1:0] a;
  logic [N-1:0] b;
  logic         cin;
  logic [N-1:0] sum;
  logic         cout;
  logic [N:0]   expected;             // a + b + cin extendido a N+1 bits

  time          t_last_cout;            // ultimo cambio del carry-out
  time          t_last_sum_msb;         // ultimo cambio del bit mas significativo de la suma
  time          t0;
  time          delay_carry;
  time          delay_sum;

  integer       errors;
  integer       i;
  integer       seed = 2026;

  // ---------------------------------------------------------------------
  // DUT: RCA de N bits parametrizable
  // ---------------------------------------------------------------------
  rca #(.N(N)) dut (
    .a   (a  ),
    .b   (b  ),
    .cin (cin),
    .sum (sum),
    .cout(cout)
  );

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_rca.vcd");
    $dumpvars(0, tb_rca);
  end

  // Registran POR SEPARADO la ultima transicion del carry-out y del bit mas
  // significativo de la suma. Son dos caminos distintos del path critico y por
  // eso necesitan monitores independientes (un solo `always @(sum or cout)`
  // mediria lo mismo dos veces).
  always @(cout)     t_last_cout   = $time;
  always @(sum[N-1]) t_last_sum_msb = $time;

  // ---------------------------------------------------------------------
  // Aplica un vector y lo chequea contra el valor esperado (a + b + cin)
  // ---------------------------------------------------------------------
  task automatic apply_and_check(input string tag, input logic [N-1:0] va,
                                 input logic [N-1:0] vb, input logic vcin);
    begin
      a = va; b = vb; cin = vcin;
      #(2 * N + 5);                     // esperamos a que estabilicen las salidas
      expected = va + vb + vcin;
      if ((sum !== expected[N-1:0]) || (cout !== expected[N])) begin
        errors = errors + 1;
        $display("  ERROR [%s]: a=%0h b=%0h cin=%b -> sum=%0h cout=%b  (esperado sum=%0h cout=%b)",
                 tag, va, vb, vcin, sum, cout, expected[N-1:0], expected[N]);
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
    $display("EJERCICIO 1 - Ripple Carry Adder de %0d bits parametrizable", N);
    $display("==============================================================");

    // ---- 1. Borde inferior: 0 + 0 -------------------------------------
    apply_and_check("0+0", '0, '0, 1'b0);

    // ---- 2. Borde superior: max + max ---------------------------------
    apply_and_check("max+max", '1, '1, 1'b0);

    // ---- 3. Casos con carry-out = 1 -----------------------------------
    apply_and_check("carry-out (max+max)", '1, '1, 1'b0);
    apply_and_check("carry-out (max+cin)", '1, '0, 1'b1);
    apply_and_check("carry-out (max+1)",   '1, 1, 1'b0);  // max+1 -> sum=0, cout=1

    // ---- 4. 500 casos random ------------------------------------------
    for (i = 0; i < NRAND; i = i + 1)
      apply_and_check("random", $urandom(seed), $urandom(seed), $urandom(seed) & 1'b1);

    // ---- Medicion de delay (peor caso: ripple de carry) ----------------
    // Partimos de (0,0,0) y cambiamos a (max, 1, 0): el bit 0 genera carry y
    // este tiene que atravesar los N full adders (el clasico peor caso).
    // Aplicamos UN solo estimulo y leemos los dos monitores por separado:
    // cada uno registro la ultima transicion de su propio camino.
    a = '0; b = '0; cin = 1'b0;
    #(2 * N + 10);                       // dejamos estabilizar el estado previo
    t0 = $time;
    t_last_cout = t0; t_last_sum_msb = t0;
    a = '1; b = 1; cin = 1'b0;        // aplicamos el estimulo del peor caso
    #(2 * N + 20);                       // tiempo suficiente para que estabilice
    delay_carry = t_last_cout - t0;
    delay_sum   = t_last_sum_msb - t0;

    $display("");
    $display("  Cantidad de full adders : %0d", N);
    $display("  Delay peor caso (carry-out)  : %0d ns  (path cin -> cout)", delay_carry);
    $display("  Delay peor caso (bit sum MSB): %0d ns  (path cin -> sum[N-1])", delay_sum);
    $display("  (xor=2ns, and/or=1ns; el carry riplea por las %0d etapas)", N);
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (borde inferior, borde superior, carry-out y %0d random OK)", NRAND);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule