// nr_div.sv — Divisor por Newton-Raphson: calcula y = 1/a.
//
// Entrada normalizada: a in [0.5, 1.0) en U(16,16) (a_q = a * 2^16, con el
// MSB siempre en 1). 
// Salida: y = 1/a in (1, 2] en U(16,15) (y_q = y * 2^15,
// el MSB vale 1 y los 15 bits restantes son fraccionarios).
//
// La iteracion de Newton-Raphson para el reciproco es:
//     y_{n+1} = y_n * (2 - a * y_n)
// con convergencia cuadratica: cada iteracion duplica los bits correctos.
//
// El punto de partida y0 sale de una LUT de 8 entradas (lut_y0.vh,
// generada por gen_lut.py), suficiente para que 3-4 iteraciones alcancen el
// piso de precision del punto fijo (1 ULP de U(16,15)).
//
// Datapath FOLDED: se reutiliza UN solo multiplicador 16x16 -> 32, muxado
// por el estado de la FSM. Cada iteracion usa el multiplicador dos veces:
//   MUL1: p1 = a * y_n
//   MUL2: t  = 2 - round(p1[31:16]);  p2 = t * y_n;  y_{n+1} = clamp(round(p2 >> 15))
//
// El redondeo es a "nearest" en los dos pasos (suma media escala antes del
// shift) y la salida se satura a 0xFFFF (caso limite a = 0.5, y = 2.0,
// que no cabe en U(16,15)).
//
// FSM: IDLE -> (MUL1 -> MUL2) x N_ITER -> DONE.
//   - `start` arranca una division (a debe estar valida en ese ciclo).
//   - `done` es un pulso de un ciclo cuando el resultado queda listo.
//   - `busy` indica datapath ocupado.
//
// Latencia: 2*N_ITER + 1 ciclos desde `start` hasta observar `done`
// (el resultado `y` queda valido en 2*N_ITER ciclos y `done` lo avisa el
// ciclo siguiente, con `y` listo para leerse).

module nr_div #(
  parameter int N_ITER = 4
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [15:0] a,
  output logic [15:0] y,
  output logic        done,
  output logic        busy
);

  `include "lut_y0.vh"

  localparam logic [1:0] IDLE = 2'd0;
  localparam logic [1:0] MUL1 = 2'd1;
  localparam logic [1:0] MUL2 = 2'd2;
  localparam logic [1:0] DONE = 2'd3;

  // Ancho del contador de iteraciones: 1 bit minimo (N_ITER = 1 no cuenta).
  localparam int ITER_W = ($clog2(N_ITER) > 1) ? $clog2(N_ITER) : 1;

  logic [1:0]            state;
  logic [15:0]           a_reg;      // "a" capturado en el arranque
  logic [15:0]           y_reg;      // iterado actual (y_n) o resultado final
  logic [31:0]           p1_reg;     // producto a*y_n
  logic [ITER_W-1:0]     iter;       // contador de iteraciones (0..N_ITER-1)

  logic [15:0]           y0;         // LUT: y0(a) del ciclo de arranque
  logic [15:0]           mul_x;      // operando A muxado del multiplicador
  logic [31:0]           mul_out;    // salida del multiplicador 16x16 -> 32
  logic [32:0]           p1_wide;    // p1_reg + media escala (redondeo)
  logic [15:0]           p1_hi;      // round(p1_reg[31:16])
  logic [16:0]           t_ext;      // t = 2 - a*y (17 bits, siempre en 16)
  logic [15:0]           t;          // t en U(16,15)
  logic [32:0]           mul_rnd;    // mul_out + media escala (redondeo)
  logic [15:0]           y_new;      // y_{n+1} = clamp(round(t*y >> 15))

  // ---------------------------------------------------------------------
  // LUT de arranque: y0 = 1/a del punto medio del bin, U(16,15). Se calcula
  // sobre el "a" de ENTRADA (aun no capturado) en el ciclo de `start`.
  // ---------------------------------------------------------------------
  assign y0 = lut_y0((a >> 12) & 3'h7);

  // ---------------------------------------------------------------------
  // Multiplicador UNICO compartido (folded). El operando A se muxea por
  // estado: en MUL1 multiplica a_reg*y_reg, en MUL2 multiplica t*y_reg.
  // ---------------------------------------------------------------------
  assign mul_x = (state == MUL1) ? a_reg : t;
  assign mul_out = mul_x * y_reg;

  // round(p1[31:16]): suma media escala (2^15) y recorta. Nunca desborda el
  // bit 32 (max producto 16x16 = 2^32 - 2^17 < 2^32).
  assign p1_wide = {1'b0, p1_reg} + 33'h8000;
  assign p1_hi   = p1_wide[31:16];

  // t = 2 - a*y en U(16,15): el resultado siempre cae en [1, 0xC000], asi
  // que el bit 17 del temporal nunca se usa.
  assign t_ext = 17'h10000 - {1'b0, p1_hi};
  assign t     = t_ext[15:0];

  // round(t*y >> 15) + saturacion a 0xFFFF (y = 2.0 exacto no cabe en 16b).
  assign mul_rnd = {1'b0, mul_out} + 33'h4000;
  assign y_new = (mul_rnd[32:15] >= 18'h10000) ? 16'hFFFF : mul_rnd[31:15];

  assign busy = (state != IDLE);
  assign done = (state == DONE);

  // ---------------------------------------------------------------------
  // FSM de control
  // ---------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      a_reg  <= '0;
      y_reg  <= '0;
      p1_reg <= '0;
      iter   <= '0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            a_reg <= a;
            y_reg <= y0;          // semilla de la LUT (comb. sobre `a`)
            iter  <= '0;
            state <= MUL1;
          end
        end
        MUL1: begin
          p1_reg <= mul_out;      // p1 = a_reg * y_reg
          state  <= MUL2;
        end
        MUL2: begin
          if (iter == N_ITER - 1) begin
            y_reg <= y_new;       // ultima iteracion: guarda y y avisa done
            state <= DONE;
          end else begin
            y_reg <= y_new;
            iter  <= iter + 1;
            state <= MUL1;
          end
        end
        DONE: begin
          if (!start) state <= IDLE;
        end
      endcase
    end
  end

  assign y = y_reg;

endmodule