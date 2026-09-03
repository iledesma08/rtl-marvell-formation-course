// fir4_folded.sv — FIR de 4 coeficientes con recursos compartidos (Ejercicio 3).
//
// Version ITERATIVA (folding) del FIR directo del Ejercicio 1: en vez de 4
// multiplicadores y 3 sumadores trabajando en paralelo, se reutiliza UN solo
// multiplicador y UN solo sumador a lo largo de 5 ciclos de reloj por muestra.
// El scheduling con recursos {1 x, 1 +} sale de explotar la movilidad que
// dejaron ASAP/ALAP en el Ejercicio 2: las multiplicaciones se escalonan y
// las sumas se solapan con las multiplicaciones que no tienen dependencia.
//
// Scheduling elegido (5 ciclos por muestra, P = registro de producto,
// acc = acumulador):
//
//   Ciclo | Multiplicador    | Sumador         | Escrituras
//   ------+------------------+-----------------+-------------------
//     1   | M0 = x0*h0       | -               | P <- M0
//     2   | M1 = x1*h1       | -               | P <- M1, acc <- M0
//     3   | M2 = x2*h2       | A1 = M0 + M1    | P <- M2, acc <- A1
//     4   | M3 = x3*h3       | A2 = A1 + M2    | P <- M3, acc <- A2
//     5   | -                | A3 = A2 + M3    | y_out <- A3 (= y)
//
// Por que 5 ciclos es el minimo con estos recursos:
//   - El multiplicador tiene que hacer 4 productos => >= 4 ciclos.
//   - A1 necesita M0 y M1; con un solo multiplicador M1 termina como muy
//     temprano al final del ciclo 2 => A1 >= ciclo 3, A2 >= ciclo 4,
//     A3 >= ciclo 5. La cota inferior es 5 y el scheduling la alcanza.
//
// Estimacion teorica:
//   - Latencia (in_valid -> out_valid): 6 ciclos = 5 de computo + 1 de
//     registro de salida.
//   - Throughput (modo streaming, in_valid permanente): 1 muestra cada
//     5 ciclos => Th = f_clk / 5. El multiplicador se usa 4/5 = 80% y el
//     sumador 3/5 = 60% de los ciclos.
//
// Estructura del codigo (separacion clasica control/datapath):
//   - fir4_ctrl     : FSM de 6 estados (IDLE + 5 de computo). Genera los
//                     selectores de los muxes y los enables de registros.
//   - fir4_datapath : linea de retardo de 4 taps, 2 mux 4:1, el multiplicador
//                     compartido, el registro de producto P, el sumador
//                     compartido y el acumulador con su mux de realimentacion.
//   - fir4_folded   : top que instancia y conecta ambos bloques.
//
// Interfaces:
//   - in_valid / in_ready : handshake valido-preparado. El modulo solo acepta
//     una muestra nueva cuando esta en IDLE o en el ultimo ciclo de computo
//     (A3); si el flujo entra mas rapido de lo que procesa, la muestra se
//     pierde (in_ready = 0 lo indica).
//   - y_out / out_valid : salida registrada. out_valid es un pulso de 1 ciclo
//     por muestra aceptada; y_out permanece estable 5 ciclos.
//
// Anchos: muestras y coeficientes de WX/WH bits sin signo. Cada producto
// ocupa WP = WX+WH bits y la suma de los 4 productos como maximo
// NTAPS*(2^WX-1)*(2^WH-1) requiere 2 bits extra de crecimiento:
// WY = WX + WH + 2 (con WX = WH = 8 => productos de 16 bits y acumulador de
// 18, que alcanza justo: 4*255*255 = 260100 < 2^18 = 262144).

// =====================================================================
// fir4_ctrl — FSM de control (Moore con un unico input Mealy: in_valid)
// =====================================================================
//
// Estados (identificados con el ciclo del scheduling que ejecutan):
//
//   S_IDLE  : espera una muestra (in_valid). Al aceptarla desplaza la linea
//             de retardo (ld_taps) y salta a S_M0.
//   S_M0    : ciclo 1 -> multiplicador calcula x0*h0.
//   S_M1    : ciclo 2 -> multiplicador calcula x1*h1; acc captura P (M0).
//   S_M2A1  : ciclo 3 -> multiplicador x2*h2 Y sumador acc+P en paralelo.
//   S_M3A2  : ciclo 4 -> multiplicador x3*h3 Y sumador acc+P en paralelo.
//   S_A3    : ciclo 5 -> sumador acc+P (= y). Si llega otra muestra
//             (in_valid) vuelve directo a S_M0

module fir4_ctrl (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       in_valid,   // hay muestra nueva disponible
  output logic       in_ready,   // 1 en los ciclos en que se puede aceptar
  output logic [1:0] sel_k,      // tap/coeficiente seleccionado (0..3)
  output logic       p_en,       // carga del registro de producto P
  output logic       acc_sel,    // 0: acc <- P (captura M0) | 1: acc <- acc+P
  output logic       acc_en,     // carga del acumulador
  output logic       y_en,       // carga del registro de salida
  output logic       ld_taps     // desplazamiento de la linea de retardo
);

  // Codificacion de estados.
  localparam logic [2:0] S_IDLE = 3'd0;
  localparam logic [2:0] S_M0   = 3'd1;
  localparam logic [2:0] S_M1   = 3'd2;
  localparam logic [2:0] S_M2A1 = 3'd3;
  localparam logic [2:0] S_M3A2 = 3'd4;
  localparam logic [2:0] S_A3   = 3'd5;

  logic [2:0] state;
  logic [2:0] next;

  // Registro de estado (reset asincronico activo bajo).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else        state <= next;
  end

  // Logica de proximo estado. La unica decision dependiente de entradas es
  // in_valid en IDLE y en A3 (transicion Mealy que ademas dispara ld_taps).
  always_comb begin
    next    = S_IDLE;
    ld_taps = 1'b0;
    case (state)
      S_IDLE:
        if (in_valid) begin
          next    = S_M0;
          ld_taps = 1'b1;          // acepta la muestra: desplaza los taps
        end
      S_M0:   next = S_M1;
      S_M1:   next = S_M2A1;
      S_M2A1: next = S_M3A2;
      S_M3A2: next = S_A3;
      S_A3:
        if (in_valid) begin
          next    = S_M0;          // back-to-back: la salida de una muestra
          ld_taps = 1'b1;          // coincide con la aceptacion de la siguiente
        end
      default: next = S_IDLE;
    endcase
  end

  // Salidas (decodificacion del estado actual).
  // in_ready: solo se acepta una muestra en IDLE o saliendo de A3.
  assign in_ready = (state == S_IDLE) || (state == S_A3);

  // sel_k elige el tap y el coeficiente del ciclo (S_M0 -> k=0 ... S_M3A2 -> k=3).
  assign sel_k = (state == S_M0)   ? 2'd0 :
                 (state == S_M1)   ? 2'd1 :
                 (state == S_M2A1) ? 2'd2 :
                                     2'd3;

  // El multiplicador trabaja en los ciclos 1..4; el P retiene M3 durante el 5.
  assign p_en = (state == S_M0) || (state == S_M1) ||
                (state == S_M2A1) || (state == S_M3A2);

  // El acumulador carga en los ciclos 2..5: en el 2 captura M0 directo de P
  // (acc_sel = 0) y en los ciclos 3..5 suma el producto que llega (acc_sel = 1).
  assign acc_en  = (state == S_M1) || (state == S_M2A1) ||
                   (state == S_M3A2) || (state == S_A3);
  assign acc_sel = (state == S_M2A1) || (state == S_M3A2) || (state == S_A3);

  // El registro de salida se carga al cerrar el ciclo 5 (estado A3).
  assign y_en = (state == S_A3);

endmodule

// =====================================================================
// fir4_datapath — camino de datos con 1 multiplicador y 1 sumador
// =====================================================================
//
// El truco del scheduling: en el ciclo 2 acc captura M0 directo desde P, y a
// partir del ciclo 3 el sumador siempre trabaja con el par (acc, P). Asi los
// dos operandos del sumador nunca cambian de fuente y no hacen falta muxes
// extra en sus entradas.

module fir4_datapath #(
  parameter int WX = 8,   // ancho de las muestras
  parameter int WH = 8    // ancho de los coeficientes
)(
  input  logic       clk,
  input  logic       rst_n,
  input  logic       ld_taps,
  input  logic       p_en,
  input  logic       acc_sel,
  input  logic       acc_en,
  input  logic       y_en,
  input  logic [1:0] sel_k,
  input  logic [WX-1:0] x_in,
  input  logic [WH-1:0] h0,
  input  logic [WH-1:0] h1,
  input  logic [WH-1:0] h2,
  input  logic [WH-1:0] h3,
  output logic [WX+WH+1:0] y_out   // WY = WX+WH+2 bits
);

  localparam int WP = WX + WH;      // ancho de cada producto
  localparam int WY = WX + WH + 2;  // ancho del acumulador/salida

  // ---- Linea de retardo de 4 taps -----------------------------------
  // Se desplaza UNA vez por muestra (cuando el control acepta), no una vez
  // por ciclo: x0 guarda la muestra actual y x1..x3 las tres anteriores.
  logic [WX-1:0] x0, x1, x2, x3;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x0 <= '0; x1 <= '0; x2 <= '0; x3 <= '0;
    end else if (ld_taps) begin
      x0 <= x_in;
      x1 <= x0;
      x2 <= x1;
      x3 <= x2;
    end
  end

  // ---- Mux 4:1 de operandos (muestras y coeficientes) ----------------
  logic [WX-1:0] xa;   // muestra seleccionada
  logic [WH-1:0] ha;   // coeficiente seleccionado
  always_comb begin
    case (sel_k)
      2'd0: begin xa = x0; ha = h0; end
      2'd1: begin xa = x1; ha = h1; end
      2'd2: begin xa = x2; ha = h2; end
      default: begin xa = x3; ha = h3; end
    endcase
  end

  // ---- Multiplicador compartido + registro de producto P ------------
  logic [WP-1:0] mult_out;
  logic [WP-1:0] prod;
  assign mult_out = xa * ha;                       // unico multiplicador
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) prod <= '0;
    else if (p_en) prod <= mult_out;
  end

  // ---- Sumador compartido -------------------------------------------
  // acc (WY bits) + P extendido a WY.
  logic [WY-1:0] acc;
  logic [WY-1:0] add_out;
  logic [WY-1:0] prod_ext;
  assign prod_ext = {{(WY-WP){1'b0}}, prod};       // P a 18 bits
  assign add_out  = acc + prod_ext;                // sumador compartido

  // ---- Acumulador con mux de realimentacion -------------------------
  // acc_sel = 0: captura el producto P (solo en el ciclo 2, guarda M0).
  // acc_sel = 1: carga acc + P (ciclos 3, 4 y 5).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)      acc <= '0;
    else if (acc_en) acc <= acc_sel ? add_out : prod_ext; // mux 2:1
  end

  // ---- Registro de salida -------------------------------------------
  // Copia el resultado final al cerrar el ciclo 5 y lo mantiene estable
  // hasta la proxima muestra (out_valid lo senala desde el control).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  y_out <= '0;
    else if (y_en) y_out <= add_out;
  end

endmodule

// =====================================================================
// fir4_folded — top: FSM + datapath del FIR iterativo
// =====================================================================
module fir4_folded #(
  parameter int WX = 8,   // ancho de las muestras
  parameter int WH = 8    // ancho de los coeficientes
)(
  input  logic             clk,
  input  logic             rst_n,
  input  logic             in_valid,
  output logic             in_ready,
  input  logic [WX-1:0]    x_in,
  input  logic [WH-1:0]    h0,
  input  logic [WH-1:0]    h1,
  input  logic [WH-1:0]    h2,
  input  logic [WH-1:0]    h3,
  output logic [WX+WH+1:0] y_out,
  output logic             out_valid
);

  logic [1:0] sel_k;
  logic       p_en, acc_sel, acc_en, y_en, ld_taps;

  fir4_ctrl u_ctrl (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (in_valid),
    .in_ready (in_ready),
    .sel_k    (sel_k),
    .p_en     (p_en),
    .acc_sel  (acc_sel),
    .acc_en   (acc_en),
    .y_en     (y_en),
    .ld_taps  (ld_taps)
  );

  fir4_datapath #(.WX(WX), .WH(WH)) u_dp (
    .clk     (clk),
    .rst_n   (rst_n),
    .ld_taps (ld_taps),
    .p_en    (p_en),
    .acc_sel (acc_sel),
    .acc_en  (acc_en),
    .y_en    (y_en),
    .sel_k   (sel_k),
    .x_in    (x_in),
    .h0      (h0),
    .h1      (h1),
    .h2      (h2),
    .h3      (h3),
    .y_out   (y_out)
  );

  // out_valid es un pulso de 1 ciclo: se activa al cerrar el ciclo 5 de cada
  // muestra (estado A3) y se apaga solo en el ciclo siguiente.
  logic out_valid_r;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) out_valid_r <= 1'b0;
    else        out_valid_r <= y_en;
  end
  assign out_valid = out_valid_r;

endmodule
