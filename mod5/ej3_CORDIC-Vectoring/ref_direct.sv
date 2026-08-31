// ref_direct.sv — Implementacion de REFERENCIA "directa" para comparar contra
// el CORDIC vectoring. Calcula lo mismo (R = sqrt(x^2+y^2), phi = atan(y/x))
// pero por el camino clasico: un multiplicador y ROMs grandes.
//
// Camino de R:
//   1) Un UNICO multiplicador 16x16 -> 32, reutilizado, calcula x^2 y y^2.
//   2) s = x^2 + y^2.
//   3) ROM de raiz cuadrada de 64K x 16 (1 Mbit) indexada por s[30:15] -> R.
//
// Camino de phi:
//   1) Divisor restoring (16 etapas combinacionales) calcula el cociente
//      q = min(|y|,|x|) / max(|y|,|x|)  en U(16,16), con |q| <= 1.
//   2) ROM de atan de 64K x 16 (1 Mbit) indexada por q -> atan(q)/pi.
//   3) Si |y| > |x| se complementa a pi/2 y se reconstruye el cuadrante a
//      partir de los signos de x e y. Salida en unidades de pi (S(16,14)).
//
// El area de esta referencia esta dominada por las dos ROMs (2 Mbit totales)
// y por el divisor; el CORDIC no usa multiplicador ni ROMs grandes.
//
// FSM: IDLE -> SQ1 (x^2) -> SQ2 (y^2, s lista, se captura la salida) -> IDLE,
// con done de 1 ciclo. Latencia: 2 ciclos desde start.

`timescale 1ns/1ps

module ref_direct (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic signed [15:0]    x,     // S(16,15)
  input  logic signed [15:0]    y,     // S(16,15)
  output logic signed [15:0]    R,     // S(16,15), saturado (igual que CORDIC)
  output logic signed [15:0]    phi,   // S(16,14), unidades de pi
  output logic                  done,
  output logic                  busy
);

  localparam signed [15:0] PI_1  = 16'sd16384;   // pi en unidades de pi
  localparam signed [15:0] PI_2  = 16'sd8192;    // pi/2

  // ---- FSM ----
  typedef enum logic [1:0] { IDLE, SQ1, SQ2 } state_t;
  state_t state;

  // ---- Multiplicador unico (16x16 -> 32) ---------------------------------
  logic signed [15:0] mul_a;
  logic signed [31:0] mul_out;
  assign mul_a   = (state == SQ1) ? x : y;   // en SQ1 calcula x^2, si no y^2
  assign mul_out = mul_a * mul_a;

  logic signed [31:0] p1_reg;                // x^2 (registrado)
  logic [31:0]        s_u;                  // x^2 + y^2, hasta 2^31
  logic [30:0]        s_cap;                // s saturado a 2^30-1 (R < 1)
  assign s_u   = $unsigned(p1_reg) + $unsigned(mul_out);
  assign s_cap = (s_u[31] | s_u[30]) ? 31'h3FFFFFFF : s_u[30:0];

  // ---- ROMs (generadas por gen_roms.py) ----------------------------------
  logic [15:0] sqrt_mem  [0:65535];
  logic [15:0] atan2_mem [0:65535];
  initial begin
    $readmemh("datos/sqrt_rom.hex",  sqrt_mem);
    $readmemh("datos/atan2_rom.hex", atan2_mem);
  end

  logic [15:0] sqrt_val;                    // R sin saturar (hasta ~46340)
  logic [15:0] base;                        // atan(q)/pi en S(16,14)
  assign sqrt_val = sqrt_mem[s_cap[30:15]];
  assign base     = atan2_mem[q];

  // ---- Divisor restoring combinacional: q = min/max en U(16,16) -----------
  logic signed [16:0] x17, y17;             // x, y extendidos a 17 bits
  logic signed [16:0] ax, ay;               // |x|, |y| en 17 bits (tolera 1.0)
  logic [16:0]        num, den;
  logic               swapped;
  logic [16:0]        rem [0:16];
  logic [15:0]        quo [0:16];
  logic [15:0]        q;

  assign x17 = x;
  assign y17 = y;
  assign ax = x17[16] ? -x17 : x17;         // |x|: -x17 es 17-bit y no desborda
  assign ay = y17[16] ? -y17 : y17;
  assign swapped = (ay > ax);
  assign num = swapped ? ax[16:0] : ay[16:0];
  assign den = swapped ? ay[16:0] : ax[16:0];

  assign rem[0] = num;
  assign quo[0] = 16'd0;
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : div_stage
      logic [17:0] r2;
      assign r2 = {rem[gi], 1'b0};
      assign rem[gi + 1] = (r2 >= {1'b0, den}) ? (r2 - {1'b0, den}) : r2[16:0];
      assign quo[gi + 1] = (r2 >= {1'b0, den}) ? {quo[gi][14:0], 1'b1}
                                               : {quo[gi][14:0], 1'b0};
    end
  endgenerate
  assign q = quo[16];

  // ---- Reconstruccion del angulo en unidades de pi ------------------------
  logic signed [15:0] theta_qtr;            // angulo en [0, pi/2] dentro del cuadrante
  logic signed [15:0] phi_next;
  logic signed [15:0] R_next;

  assign theta_qtr = swapped ? (PI_2 - base) : base;

  always_comb begin
    if (x17 >= 0 && y17 >= 0)       phi_next = theta_qtr;            // cuadrante I
    else if (x17 < 0 && y17 >= 0)   phi_next = PI_1 - theta_qtr;     // cuadrante II
    else if (x17 < 0 && y17 < 0)    phi_next = theta_qtr - PI_1;     // cuadrante III
    else                            phi_next = -theta_qtr;           // cuadrante IV

    if (sqrt_val > 16'sd32767)
      R_next = 16'sd32767;                  // saturacion a R = 1.0
    else
      R_next = sqrt_val[15:0];
  end

  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      p1_reg <= '0;
      R      <= '0;
      phi    <= '0;
      done   <= 1'b0;
      busy   <= 1'b0;
    end else begin
      done <= 1'b0;                         // pulso de un ciclo
      case (state)
        IDLE: begin
          busy <= start;
          if (start)
            state <= SQ1;
        end
        SQ1: begin
          p1_reg <= mul_out;                // x^2
          state  <= SQ2;
        end
        SQ2: begin
          R   <= R_next;                    // ya tiene s = x^2 + y^2
          phi <= phi_next;
          done <= 1'b1;
          state <= IDLE;
          busy  <= 1'b0;
        end
      endcase
    end
  end

endmodule