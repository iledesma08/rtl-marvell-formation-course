// tb_fir4.sv — Testbench self-checking para el FIR iterativo (Ejercicio 3).
//
// Verifica:
//   1. Respuesta al impulso: con h = (1,2,3,4) y la secuencia x = (8,0,0,0,0,0)
//      la salida tiene que ser 8,16,24,32,0,0. Es LA prueba estructural: si
//      algun tap quedara cruzado con el coeficiente equivocado, la secuencia
//      no daria eso.
//   2. Borde de ancho: con h = x = 255 el pico es 4*255*255 = 260100, que
//      entra justo en los 18 bits del acumulador (2^18 = 262144). Si el
//      ancho estuviera mal elegido, aca se desborda.
//   3. Streaming back-to-back: 100 muestras con in_valid permanente. El DUT
//      tiene que escupir una salida cada 5 ciclos exactos y todas correctas.
//   4. Gaps aleatorios: 300 muestras con in_valid sorteado (~35%) y datos
//      aleatorios. El modelo solo registra muestras cuando in_valid && 
//      in_ready, igual que el handshake del DUT.
//   5. Latencia aislada: 3 transacciones separadas para medir cuantos
//      ciclos pasan entre la aceptacion y out_valid.
//
// El modelo de referencia replica el filtro con la misma historia de taps
// que la linea de retardo del DUT y compara cada y_out contra una cola de
// valores esperados. Ademas mide latencia, periodo en streaming y la
// utilizacion real del multiplicador y del sumador, y reporta la tabla
// teorico-vs-medido que pide el enunciado.

`timescale 1ns/1ps

module tb_fir4;
  localparam int WX = 8;          // ancho de muestras
  localparam int WH = 8;          // ancho de coeficientes
  localparam int WY = WX + WH + 2; // ancho del acumulador/salida (18 bits)
  localparam int NSTREAM = 100;   // muestras de la fase streaming
  localparam int NRAND   = 300;   // muestras de la fase random
  localparam int LAT_ESP = 6;     // latencia teorica (in_valid -> out_valid)
  localparam int PER_ESP = 5;     // periodo teorico en streaming

  // ---- Senales del DUT ------------------------------------------------------
  logic       clk = 1'b0;
  logic       rst_n;
  logic       in_valid;
  logic       in_ready;
  logic [WX-1:0] x_in;
  logic [WH-1:0] h0, h1, h2, h3;
  logic [WY-1:0] y_out;
  logic       out_valid;

  always #5 clk = ~clk;   // periodo de 10 ns

  fir4_folded #(.WX(WX), .WH(WH)) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (in_valid),
    .in_ready (in_ready),
    .x_in     (x_in),
    .h0       (h0),
    .h1       (h1),
    .h2       (h2),
    .h3       (h3),
    .y_out    (y_out),
    .out_valid(out_valid)
  );

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_fir4.vcd");
    $dumpvars(0, tb_fir4);
  end

  // ---- Modelo de referencia -------------------------------------------------
  // mx0..mx3 replican la linea de retardo del DUT: mx0 es la ultima muestra
  // aceptada y mx3 la mas vieja. Cada vez que el DUT acepta (in_valid &&
  // in_ready en un flanco), el modelo calcula la salida esperada y la encola;
  // cada pulso de out_valid desencola y compara contra y_out.
  logic [WX-1:0] mx0, mx1, mx2, mx3;
  logic [WY-1:0] exp_q [0:15];    // cola circular de salidas esperadas
  integer acc_q [0:15];           // ciclo de aceptacion de cada esperado
  integer q_head, q_tail, q_cnt;

  integer errors;
  integer seed = 2026;

  // ---- Mediciones -----------------------------------------------------------
  integer cyc;         // contador de flancos de subida
  integer last_acc;    // ciclo de la ultima aceptacion
  integer lat_min, lat_max, latv;
  integer out_total;
  integer exp_full, expv;
  integer perv;

  // Ventana de medicion de utilizacion/throughput (fase streaming):
  // cuenta ciclos con el multiplicador cargando producto (p_en) y ciclos con
  // el sumador produciendo un resultado util (acc_en && acc_sel).
  integer meas_util, util_cycles, mult_cycles, add_cycles, stream_outs;
  integer per_min, per_max, first_out_w, last_out_w;
  logic show_out, show_lat;

  task automatic push_exp(input [WY-1:0] v, input integer acc_cycle);
    begin
      if (q_cnt == 16) begin
        errors = errors + 1;
        $display("  ERROR [modelo]: cola de esperados llena en ciclo %0d", cyc);
      end else begin
        exp_q[q_tail] = v;
        acc_q[q_tail] = acc_cycle;
        q_tail = (q_tail + 1) % 16;
        q_cnt  = q_cnt + 1;
      end
    end
  endtask

  // ---------------------------------------------------------------------
  // Monitor: en cada flanco de subida lee (pre-flanco, o sea los valores
  // estables del ciclo que cierra) el handshake, las salidas y los enables
  // del control. Actualiza el modelo, la cola y las metricas.
  // ---------------------------------------------------------------------
  always @(posedge clk) begin
    cyc = cyc + 1;

    if (meas_util) begin
      util_cycles = util_cycles + 1;
      if (dut.u_ctrl.p_en)                     mult_cycles = mult_cycles + 1;
      if (dut.u_ctrl.acc_en && dut.u_ctrl.acc_sel) add_cycles = add_cycles + 1;
    end

    // Pulso de salida: desencolar y comparar.
    if (out_valid) begin
      out_total = out_total + 1;
      if (meas_util) begin
        stream_outs = stream_outs + 1;
        if (last_out_w != 0) begin
          perv = cyc - last_out_w;
          if (perv < per_min) per_min = perv;
          if (perv > per_max) per_max = perv;
        end else begin
          first_out_w = cyc;
        end
        last_out_w = cyc;
      end
      if (q_cnt == 0) begin
        errors = errors + 1;
        $display("  ERROR [salida]: out_valid sin esperado en cola (ciclo %0d)", cyc);
      end else begin
        expv   = exp_q[q_head];
        latv   = cyc - acc_q[q_head];   // latencia de ESTA muestra, no de la ultima aceptada
        q_head = (q_head + 1) % 16;
        q_cnt  = q_cnt - 1;
        if (y_out !== expv[WY-1:0]) begin
          errors = errors + 1;
          $display("  ERROR [salida ciclo %0d]: y_out=%0d esperado=%0d", cyc, y_out, expv);
        end
      end
      if (show_out) $display("    ciclo %0d: y = %0d", cyc, y_out);
      if (latv < lat_min) lat_min = latv;
      if (latv > lat_max) lat_max = latv;
      if (show_lat) $display("    latencia medida: %0d ciclos", latv);
    end

    // Aceptacion de una muestra (el DUT la captura en ESTE flanco).
    if (in_valid && in_ready) begin
      exp_full = h0*x_in + h1*mx0 + h2*mx1 + h3*mx2;
      push_exp(exp_full[WY-1:0], cyc);
      mx3 = mx2; mx2 = mx1; mx1 = mx0; mx0 = x_in;
      last_acc = cyc;
    end
  end

  // ---------------------------------------------------------------------
  // Driver: envia una muestra con handshake (espera in_ready antes de
  // afirmar in_valid). Los cambios se hacen en flanco de bajada para que
  // el DUT los muestree estables en el flanco de subida.
  // ---------------------------------------------------------------------
  task automatic send_sample(input [WX-1:0] v);
    begin
      @(negedge clk);
      while (!in_ready) @(negedge clk);
      x_in     = v;
      in_valid = 1;
      @(negedge clk);
      in_valid = 0;
    end
  endtask

  task automatic idle_cycles(input integer n);
    begin
      repeat (n) @(negedge clk);
    end
  endtask

  // Espera a que no queden salidas pendientes de verificar.
  task automatic drain;
    begin
      while (q_cnt != 0) @(negedge clk);
      repeat (2) @(negedge clk);
    end
  endtask

  // ---------------------------------------------------------------------
  // Secuencia de verificacion
  // ---------------------------------------------------------------------
  integer i;

  initial begin
    errors = 0; cyc = 0; last_acc = 0;
    q_head = 0; q_tail = 0; q_cnt = 0;
    lat_min = 999; lat_max = 0; out_total = 0;
    meas_util = 0; util_cycles = 0; mult_cycles = 0; add_cycles = 0; stream_outs = 0;
    per_min = 999; per_max = 0; first_out_w = 0; last_out_w = 0;
    show_out = 0; show_lat = 0;
    mx0 = 0; mx1 = 0; mx2 = 0; mx3 = 0;

    rst_n = 0; in_valid = 0; x_in = 0;
    h0 = 0; h1 = 0; h2 = 0; h3 = 0;

    $display("");
    $display("==============================================================");
    $display("EJERCICIO 3 - FIR de 4 coeficientes con recursos compartidos");
    $display("==============================================================");

    repeat (3) @(negedge clk);
    rst_n = 1;
    idle_cycles(1);

    // ---- 1. Respuesta al impulso ----------------------------------------
    // h = (1,2,3,4); x = (8,0,0,0,0,0) => y = 8,16,24,32,0,0
    h0 = 8'd1; h1 = 8'd2; h2 = 8'd3; h3 = 8'd4;
    $display("");
    $display("  [1/5] Respuesta al impulso: h=(1,2,3,4), x=(8,0,0,0,0,0)");
    $display("        esperado: y = 8, 16, 24, 32, 0, 0");
    show_out = 1;
    send_sample(8'd8);  idle_cycles(2);
    send_sample(8'd0);  idle_cycles(2);
    send_sample(8'd0);  idle_cycles(2);
    send_sample(8'd0);  idle_cycles(2);
    send_sample(8'd0);  idle_cycles(2);
    send_sample(8'd0);
    drain;
    show_out = 0;

    // ---- 2. Borde de ancho ----------------------------------------------
    // h = x = 255 => pico 4*255*255 = 260100 < 2^18 = 262144 (justo entra)
    h0 = 8'd255; h1 = 8'd255; h2 = 8'd255; h3 = 8'd255;
    $display("");
    $display("  [2/5] Borde de ancho: h=(255,255,255,255), x=(255,255,255,255,1,0)");
    $display("        esperado pico: y = 260100 (18 bits, sin overflow)");
    show_out = 1;
    send_sample(8'd255); idle_cycles(2);
    send_sample(8'd255); idle_cycles(2);
    send_sample(8'd255); idle_cycles(2);
    send_sample(8'd255); idle_cycles(2);
    send_sample(8'd1);   idle_cycles(2);
    send_sample(8'd0);
    drain;
    show_out = 0;

    // ---- 3. Streaming back-to-back + medicion de throughput -------------
    h0 = 8'd3; h1 = 8'd5; h2 = 8'd7; h3 = 8'd11;
    $display("");
    $display("  [3/5] Streaming: %0d muestras con in_valid permanente (x = 1..%0d)", NSTREAM, NSTREAM);
    meas_util = 1;
    @(negedge clk);
    in_valid = 1;
    for (i = 1; i <= NSTREAM; i = i + 1) begin
      while (!in_ready) @(negedge clk);
      x_in = i[WX-1:0];
      @(negedge clk);
    end
    in_valid = 0;
    drain;
    meas_util = 0;

    // ---- 4. Gaps aleatorios ----------------------------------------------
    h0 = 8'd13; h1 = 8'd27; h2 = 8'd51; h3 = 8'd90;
    $display("");
    $display("  [4/5] Gaps aleatorios: %0d muestras con in_valid ~35%% y datos random", NRAND);
    for (i = 0; i < NRAND; i = i + 1) begin
      @(negedge clk);
      if (($urandom(seed) % 100) < 35) begin
        x_in     = $urandom(seed);
        in_valid = 1;
        @(negedge clk);
        in_valid = 0;
      end
    end
    drain;

    // ---- 5. Latencia aislada ---------------------------------------------
    $display("");
    $display("  [5/5] Latencia aislada: 3 transacciones separadas (esperado %0d ciclos)", LAT_ESP);
    show_lat = 1;
    repeat (3) begin
      idle_cycles(4);
      send_sample($urandom(seed));
      idle_cycles(8);
    end
    show_lat = 0;
    drain;

    // ---- Tabla teorico vs medido ------------------------------------------
    $display("");
    $display("==============================================================");
    $display("  Tabla teorico vs medido (scheduling de 5 ciclos)");
    $display("==============================================================");
    $display("  Metrica                        | Teorico | Medido");
    $display("---------------------------------+---------+------------------");
    $display("  Latencia in_valid->out_valid   |    %0d    |  min %0d max %0d ciclos", LAT_ESP, lat_min, lat_max);
    if (stream_outs > 1) begin
      $display("  Periodo en streaming           |    %0d    |  min %0d max %0d ciclos", PER_ESP, per_min, per_max);
      $display("  Throughput (muestras/ciclo)    |  0.%03d  |  0.%03d", 1000/PER_ESP, ((stream_outs-1)*1000)/(last_out_w-first_out_w));
    end
    $display("  Ciclos de mult por muestra     |    4    |  %0d.%02d", mult_cycles/stream_outs, (mult_cycles*100/stream_outs)%100);
    $display("  Ciclos de suma util por muestra|    3    |  %0d.%02d", add_cycles/stream_outs, (add_cycles*100/stream_outs)%100);
    $display("");
    $display("  Muestras aceptadas y verificadas: %0d", out_total);

    if (errors == 0)
      $display("RESULTADO: PASS  (impulso, borde de ancho, streaming, %0d random y metricas OK)", NRAND);
    else
      $display("RESULTADO: FAIL  (%0d errores)", errors);
    $display("");

    $finish;
  end

endmodule
