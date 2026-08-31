// cordic_vect.sv — CORDIC en modo VECTORING (datapath folded) para calcular
//
//     R   = sqrt(x^2 + y^2)      (magnitud del vector)
//     phi = atan(y/x)            (angulo, en unidades de pi)
//
// Formato de datos:
//   - Entradas x, y            : S(16,15), rango [-1, 1).
//   - Salida  R                : S(16,15), saturada a 0x7FFF (R = 1.0). La
//                                salida es exacta para entradas con R < 1.
//   - Salida  phi              : S(16,14) en unidades de pi: valor = angulo/pi,
//                                rango (-1, 1] = (-pi, pi]. El circulo completo
//                                no entra en S(16,14) en radianes (necesitaria
//                                ±pi ~ 3.14), por eso se normaliza a pi.
//
// Arquitectura (folded, N_ITER = 16 iteraciones en 16 ciclos):
//   - El ciclo de `start` SOLO precarga el vector pre-escalado por
//     K = 0.60725 (compensacion del factor de crecimiento de la rotacion).
//     Como K es una CONSTANTE, x*K se sintetiza como sumas y desplazamientos
//     (no como multiplicador real). Con eso R = x_N directo.
//   - Cada ciclo siguiente resuelve una iteracion. Pre-rotacion de 180 grados
//     si x < 0 (sugerencia del enunciado): con x positivo el angulo del vector
//     queda en [-pi/2, pi/2] y el acumulador z no sale del rango de
//     convergencia (~±0.555 pi).
//   - En vectoring se rota hasta llevar y -> 0; z acumula el angulo rotado.
//   - Correccion de cuadrante sobre z:
//       x >= 0           : phi = z
//       x <  0, y >= 0   : phi = z + pi    (cuadrante II)
//       x <  0, y <  0   : phi = z - pi    (cuadrante III)
//     con pi = 1.0 exacto en unidades de pi.
//
// Internamente X e Y usan S(18,15) (bits de guarda) y z usa S(16,14).
// Los desplazamientos por i (0..15) se implementan con redondeo a nearest.
//
// Latencia: N_ITER = 16 ciclos desde `start` hasta `done`. El resultado
// (R, phi) queda valido en el mismo ciclo en que se observa `done`.

`timescale 1ns/1ps

module cordic_vect (
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  start,
  input  logic signed [15:0]    x,     // S(16,15)
  input  logic signed [15:0]    y,     // S(16,15)
  output logic signed [15:0]    R,     // S(16,15), saturado
  output logic signed [15:0]    phi,   // S(16,14), unidades de pi
  output logic                  done,
  output logic                  busy
);

  localparam int N_ITER = 16;
  localparam signed [15:0] K_Q   = 16'sd19898;   // 0.6072529... en S(16,15)
  localparam signed [15:0] PI_1  = 16'sd16384;   // 1.0 en unidades de pi

  // ---- Registros del datapath -------------------------------------------
  logic signed [17:0] X, Y;          // S(18,15)
  logic signed [17:0] X_next, Y_next;
  logic signed [15:0] Z;             // S(16,14), unidades de pi
  logic signed [15:0] Z_next;
  logic        [3:0]  i, i_next;
  logic               x_neg, y_neg;  // signos ORIGINALES (para el cuadrante)
  logic signed [15:0] atan_val;

  // ---- Pre-escalado por K (multiplicacion por constante) -----------------
  logic signed [16:0] x17, y17;         // x, y extendidos a 17 bits
  logic signed [16:0] x_rot, y_rot;     // vector pre-rotado 180 si x < 0
  logic signed [31:0] x_prod, y_prod;   // x*K, y*K en 32 bits (contexto 16b
                                        // desbordaria: 32767*19898 ~ 2^30)
  logic signed [15:0] x_ps, y_ps;       // x*K, y*K en S(16,15)

  // Pre-rotacion de 180 grados si x < 0 (sugerencia del enunciado): con x
  // positivo el angulo del vector queda en [-pi/2, pi/2] y z no sale del rango
  // de convergencia. La magnitud no cambia (R igual).
  assign x17 = x;
  assign y17 = y;
  assign x_rot = x17[16] ? -x17 : x17;
  assign y_rot = x17[16] ? -y17 : y17;

  assign x_prod = $signed(x_rot) * $signed(K_Q);
  assign y_prod = $signed(y_rot) * $signed(K_Q);
  assign x_ps = (x_prod + 32'sd16384) >>> 15;   // redondeo a nearest
  assign y_ps = (y_prod + 32'sd16384) >>> 15;

  // Extension a 18 bits (S(18,15)) para el registro X/Y.
  logic signed [17:0] xps18, yps18;
  assign xps18 = x_ps;
  assign yps18 = y_ps;

  // -----------------------------------------------------------------------
  // Redondeo a nearest de un desplazamiento aritmetico: round(v * 2^-sh).
  // -----------------------------------------------------------------------
  function automatic logic signed [17:0] round_shift(
      input logic signed [17:0] v, input logic [3:0] sh);
    logic signed [17:0] r;
    begin
      r = v;
      if (sh != 0)
        r = r + (18'sd1 << (sh - 1));
      round_shift = r >>> sh;
    end
  endfunction

  // -----------------------------------------------------------------------
  // Logica combinacional de la iteracion.
  // -----------------------------------------------------------------------
  logic signed [17:0] rx, ry;        // y>>i, x>>i con redondeo
  logic signed [15:0] d;             // +1 / -1
  logic signed [15:0] phi_next;
  logic signed [15:0] R_next;

  always_comb begin
    // Defaults para evitar latches en las ramas.
    X_next = X;
    Y_next = Y;
    Z_next = Z;
    i_next = i;
    d      = -16'sd1;
    rx     = 18'sd0;
    ry     = 18'sd0;
    R_next = R;
    phi_next = phi;

    if (start) begin
      // Solo precarga del vector pre-escalado (la iteracion 0 es el proximo
      // ciclo, cuando busy=1 e i=0).
      X_next = xps18;
      Y_next = yps18;
      Z_next = 16'sd0;
      i_next = 4'd0;
    end else begin
      // Decision del vectoring: rotar hasta llevar Y a cero.
      d = (Y >= 0) ? -16'sd1 : 16'sd1;

      // Productos rotacionales con redondeo.
      rx = round_shift(Y, i);
      ry = round_shift(X, i);

      X_next = (d == 1) ? X - rx : X + rx;
      Y_next = (d == 1) ? Y + ry : Y - ry;
      Z_next = (d == 1) ? Z - atan_val : Z + atan_val;

      i_next = (i == N_ITER - 1) ? 4'd0 : i + 1;
    end

    // R: x tras 16 iteraciones, saturado a S(16,15).
    if (X_next > 18'sd32767)
      R_next = 16'sd32767;
    else if (X_next < 18'sd0)
      R_next = 16'sd0;
    else
      R_next = X_next;              // trunca a 16 bits (bits altos en 0)

    // phi: correccion de cuadrante sobre z (unidades de pi).
    if (!x_neg)
      phi_next = Z_next;
    else if (!y_neg)
      phi_next = Z_next + PI_1;      // cuadrante II: z + pi
    else
      phi_next = Z_next - PI_1;      // cuadrante III: z - pi
  end

  // -----------------------------------------------------------------------
  // Secuencial: registros del datapath + contador + senales de control.
  // -----------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      X     <= 18'sd0;
      Y     <= 18'sd0;
      Z     <= 16'sd0;
      i     <= 4'd0;
      R     <= 16'sd0;
      phi   <= 16'sd0;
      busy  <= 1'b0;
      done  <= 1'b0;
      x_neg <= 1'b0;
      y_neg <= 1'b0;
    end else begin
      done <= 1'b0;                    // pulso registrado de 1 ciclo
      if (start) begin
        X     <= xps18;
        Y     <= yps18;
        Z     <= 16'sd0;
        i     <= 4'd0;
        busy  <= 1'b1;
        x_neg <= x[15];                // signo ORIGINAL (pre-rotacion)
        y_neg <= y[15];
      end else if (busy) begin
        X   <= X_next;
        Y   <= Y_next;
        Z   <= Z_next;
        i   <= i_next;
        R   <= R_next;
        phi <= phi_next;
        if (i == N_ITER - 1)
          done <= 1'b1;                // R/phi quedan validos en este ciclo
        busy <= (i != N_ITER - 1);
      end
    end
  end

  // -----------------------------------------------------------------------
  // Instancia de la tabla de atan(2^-i) (S(16,14), unidades de pi).
  // -----------------------------------------------------------------------
  rom_atan u_rom (
    .index(i),
    .value(atan_val)
  );

endmodule