`timescale 1ns/1ps

// tb_pipeline.sv — Testbench SystemVerilog para pipeline_3stage.
//
// Verifica tres cosas:
//   1. Funcional: golden model en software (y = ((x + 5) * 3) >>> 4) y
//      comprobación de la latencia de 3 ciclos.
//   2. Stall: ready_in alternando 1/0. Comprueba que con stall + valid_in = 1
//      el pipeline NO acepta (ready_out = 0) y que no se pierden muestras.
//   3. Throughput observado vs. teórico en ambas fases (sin y con stalls).
//
// Convención de timing: los estímulos se presentan en negedge y la salida 
// se muestrea justo después del posedge, tal como
// en los testbenches de los ejercicios anteriores.
module tb_pipeline;

  localparam int XW     = 8;
  localparam int YW     = 16;
  localparam int S2W    = XW + 1 + XW;   // ancho interno del producto (17 bits)
  localparam int QDEPTH = 4;             // profundidad del FIFO del golden model (>= 3)

  logic clk, rst_n;
  logic signed [XW-1:0] x_in;
  logic valid_in;
  logic ready_out;
  logic signed [YW-1:0] y_out;
  logic valid_out;
  logic ready_in;

  // Golden model: un FIFO con las muestras aceptadas (en orden de llegada) y
  // una función aritmética pura. Así el modelado es independiente del RTL.
  logic signed [XW-1:0] fifo [0:QDEPTH-1];
  integer fifo_head = 0;
  integer fifo_tail = 0;

  integer cycle       = 0;   // contador de ciclos (se incrementa por posedge)
  integer accepted    = 0;   // muestras aceptadas por el pipeline
  integer produced    = 0;   // muestras producidas en la salida
  integer errors      = 0;   // errores funcionales (golden model)
  integer stall_viol  = 0;   // violaciones de handshake durante stall
  integer first_accept = -1; // ciclo del primer "valid_in && ready_out"
  integer first_out    = -1; // ciclo del primer valid_out

  // Clock 100 MHz (período 10 ns, 50% duty).
  always #5 clk = ~clk;
  initial clk = 0;

  pipeline_3stage #(.XW(XW), .YW(YW)) dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .x_in      (x_in),
    .valid_in  (valid_in),
    .ready_out (ready_out),
    .y_out     (y_out),
    .valid_out (valid_out),
    .ready_in  (ready_in)
  );

  // Graba señales para GTKWave.
  initial begin
    $dumpfile("tb_pipeline.vcd");
    $dumpvars(0, tb_pipeline);
  end

  // --- Utilidades del golden model (FIFO) ---
  task automatic fifo_push(input logic signed [XW-1:0] v);
    fifo[fifo_tail] = v;
    fifo_tail = (fifo_tail + 1) % QDEPTH;
  endtask

  task automatic fifo_pop(output logic signed [XW-1:0] v);
    v = fifo[fifo_head];
    fifo_head = (fifo_head + 1) % QDEPTH;
  endtask

  // Golden model en software: y = ((x + A) * B) >>> 4, con A = 5 y B = 3.
  function automatic logic signed [YW-1:0] golden_y(input logic signed [XW-1:0] x);
    logic signed [S2W-1:0] tmp;
    tmp = (($signed(x) + 8'sd5) * 8'sd3) >>> 4;
    return tmp[YW-1:0];
  endfunction

  task automatic cycle_step(input logic v, input logic signed [XW-1:0] xv,
                            input logic rd);
    logic signed [XW-1:0] popped;
    logic signed [YW-1:0] exp;
    begin
      @(negedge clk);
      valid_in = v;
      x_in     = xv;
      ready_in = rd;

      @(posedge clk);
      #1;
      cycle = cycle + 1;

      // Requisito del enunciado: con stall (ready_in = 0) y valid_in = 1,
      // ready_out debe ser 0 (el pipeline no puede aceptar).
      if (!rd && v && ready_out) begin
        stall_viol = stall_viol + 1;
        $display("  VIOLACION DE STALL en ciclo %0d: ready_in=0, valid_in=1, ready_out=1", cycle);
      end

      // ¿Acepta la muestra? (handshake del lado slave)
      if (v && ready_out) begin
        fifo_push(x_in);
        accepted = accepted + 1;
        if (first_accept < 0) first_accept = cycle;
      end

      // ¿Produce un resultado? Solo cuenta si el consumidor está listo
      // (handshake del lado master: valid_out && ready_in). Si ready_in = 0,
      // valid_out queda congelado en 1 pero NO hay transferencia.
      if (valid_out && rd) begin
        fifo_pop(popped);
        produced = produced + 1;
        if (first_out < 0) first_out = cycle;
        exp = golden_y(popped);
        if (y_out !== exp) begin
          errors = errors + 1;
          $display("  ERROR en ciclo %0d: y_out=%0d, esperado=%0d (x=%0d)",
                   cycle, y_out, exp, popped);
        end
      end
    end
  endtask

  // Reinicia el DUT y limpia los contadores entre fases.
  task automatic reset_and_clear();
    begin
      rst_n    = 0;
      valid_in = 0;
      ready_in = 1;
      x_in     = '0;
      repeat(3) @(negedge clk);
      rst_n = 1;

      cycle       = 0;
      accepted    = 0;
      produced    = 0;
      errors      = 0;
      stall_viol  = 0;
      first_accept = -1;
      first_out    = -1;
      fifo_head    = 0;
      fifo_tail    = 0;
    end
  endtask

  initial begin
    integer i;
    integer P1_CYCLES;      // fase 1: ventana sin stalls
    integer P2_CYCLES;      // fase 2: ventana con stalls
    integer ready1;         // ciclos con ready_in = 1 en la fase 2
    integer p1_accept, p1_prod, p2_accept, p2_prod, lat;
    real    tp_obs1, tp_theo1, tp_obs2, tp_theo2;
    logic signed [XW-1:0] xv;

    P1_CYCLES = 40;
    P2_CYCLES = 200;
    ready1    = 0;
    xv        = 8'sd0;

    reset_and_clear();

    // ================= FASE 1: sin stalls (ready_in = 1) =================
    $display("");
    $display("=== FASE 1: sin stalls (ready_in = 1 todo el tiempo) ===");

    // Alimentación continua con una secuencia de 8 bits signed.
    xv = 8'sd0;
    for (i = 0; i < P1_CYCLES; i = i + 1) begin
      xv = (xv * 8'sd13) + 8'sd7;
      cycle_step(1'b1, xv, 1'b1);
    end
    // Drenar el pipeline (valid_in = 0) para sacar las últimas 3 muestras.
    for (i = 0; i < 4; i = i + 1)
      cycle_step(1'b0, '0, 1'b1);

    p1_accept = accepted;
    p1_prod   = produced;
    lat       = first_out - first_accept + 1;   // 3 ciclos esperados
    tp_obs1   = accepted / (P1_CYCLES * 1.0);
    tp_theo1  = 1.0;

    $display("  ciclos de ventana      : %0d", P1_CYCLES);
    $display("  aceptadas / producidas : %0d / %0d", p1_accept, p1_prod);
    $display("  latencia observada     : %0d ciclos (esperado 3)", lat);
    $display("  throughput observado   : %0.3f muestras/ciclo", tp_obs1);
    $display("  throughput teorico     : %0.3f muestras/ciclo", tp_theo1);
    $display("  errores funcionales    : %0d", errors);

    if (p1_accept != P1_CYCLES || p1_prod != p1_accept || lat != 3 || errors != 0)
      $display("  >> FASE 1: FAIL");
    else
      $display("  >> FASE 1: PASS");

    // ================= FASE 2: con stalls (ready_in 1/0) =================
    reset_and_clear();

    $display("");
    $display("=== FASE 2: con stalls (ready_in alternando 1/0) ===");

    xv = 8'sd0;
    for (i = 0; i < P2_CYCLES; i = i + 1) begin
      xv = (xv * 8'sd13) + 8'sd7;
      // Alternancia que empieza en 1: en la mitad de los ciclos hay stall.
      cycle_step(1'b1, xv, (i % 2 == 0) ? 1'b1 : 1'b0);
      if (i % 2 == 0) ready1 = ready1 + 1;
    end
    // Drenar con ready_in = 1 y valid_in = 0 hasta vaciar la salida.
    for (i = 0; i < 6; i = i + 1)
      cycle_step(1'b0, '0, 1'b1);

    p2_accept = accepted;
    p2_prod   = produced;
    tp_theo2  = ready1 / (P2_CYCLES * 1.0);   // fracción de ciclos con ready
    tp_obs2   = accepted / (P2_CYCLES * 1.0); // muestras aceptadas por ciclo

    $display("  ciclos de ventana      : %0d", P2_CYCLES);
    $display("  ciclos con ready_in=1  : %0d", ready1);
    $display("  ciclos con stall       : %0d", P2_CYCLES - ready1);
    $display("  aceptadas / producidas : %0d / %0d", p2_accept, p2_prod);
    $display("  violaciones handshake  : %0d", stall_viol);
    $display("  throughput observado   : %0.3f muestras/ciclo", tp_obs2);
    $display("  throughput teorico     : %0.3f muestras/ciclo", tp_theo2);
    $display("  errores funcionales    : %0d", errors);

    if (p2_accept != ready1 || p2_prod != p2_accept || errors != 0 || stall_viol != 0)
      $display("  >> FASE 2: FAIL");
    else
      $display("  >> FASE 2: PASS");

    // ============================ RESUMEN ============================
    $display("");
    if (errors == 0 && stall_viol == 0 &&
        p1_accept == P1_CYCLES && p1_prod == p1_accept && lat == 3 &&
        p2_accept == ready1 && p2_prod == p2_accept)
      $display("RESULTADO GENERAL: PASS  (funcional OK, latencia 3, stalls OK, throughput OK)");
    else
      $display("RESULTADO GENERAL: FAIL");
    $display("");
    $finish;
  end

endmodule
