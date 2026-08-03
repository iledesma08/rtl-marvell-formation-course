// pipeline_3stage.sv — Pipeline síncrono de 3 etapas con handshake AXI-Stream.
//
// Calcula:  y = ((x + A) * B) >>> 4
//   Etapa 1: suma  x + A
//   Etapa 2: multiplica el resultado por B
//   Etapa 3: shift aritmético a la derecha de SHIFT posiciones (>>>)
//
// Interfaz AXI-Stream (handshake valid/ready):
//   - Slave (entrada):  x_in, valid_in, ready_out
//   - Master (salida):  y_out, valid_out, ready_in
//
// Back-pressure: ready_out = ready_in (la presión se propaga de punta a punta).
// Cuando ready_in = 0 el pipeline entero se congela con un CE común sobre todos
// los FFs, de modo que ninguna etapa avanza y la entrada tampoco se acepta
// (ready_out = 0). Esto cumple el requisito del enunciado: con stall y
// valid_in = 1, ready_out = 0.
//
// Latencia: 3 ciclos. Throughput: 1 muestra/ciclo en régimen sin stalls.
module pipeline_3stage #(
  parameter int XW     = 8,                     // ancho de x_in (signed)
  parameter int YW     = 16,                    // ancho de y_out (signed)
  parameter int SHIFT  = 4,                     // desplazamiento de la etapa 3
  parameter logic signed [XW-1:0] A = 8'sd5,    // constante de la etapa 1
  parameter logic signed [XW-1:0] B = 8'sd3     // constante de la etapa 2
)(
  input  logic                 clk,
  input  logic                 rst_n,           // reset asíncrono activo-bajo

  // lado esclavo (entrada de datos)
  input  logic signed [XW-1:0] x_in,
  input  logic                 valid_in,
  output logic                 ready_out,

  // lado maestro (salida de datos)
  output logic signed [YW-1:0] y_out,
  output logic                 valid_out,
  input  logic                 ready_in
);

  // Anchos internos:
  //   Etapa 1: x + A        -> XW + 1 bits  (suma de dos signed de XW bits)
  //   Etapa 2: r1 * B       -> (XW + 1) + XW bits
  //   Etapa 3: r2 >>> SHIFT -> se conserva el ancho y se trunca a YW
  localparam int S1W = XW + 1;
  localparam int S2W = XW + 1 + XW;

  logic                  s1_valid, s2_valid, s3_valid;  // valid por etapa
  logic signed [S1W-1:0] r1;                            // registro etapa 1 (x+A)
  logic signed [S2W-1:0] r2;                            // registro etapa 2 (r1*B)
  logic signed [S2W-1:0] r3;                            // registro etapa 3 (r2>>SHIFT)

  // La presión de back-pressure se propaga directamente hacia la entrada.
  assign ready_out = ready_in;

  // Salidas del lado maestro.
  assign valid_out = s3_valid;
  assign y_out     = r3[YW-1:0];

  // Etapas registradas. ready_in actúa como CE común: si está en 0, TODOS los
  // FFs quedan congelados (stall global).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1_valid <= 1'b0;
      s2_valid <= 1'b0;
      s3_valid <= 1'b0;
      r1       <= '0;
      r2       <= '0;
      r3       <= '0;
    end else if (ready_in) begin
      // Etapa 3: captura el producto de la etapa 2 y aplica el shift aritmético.
      s3_valid <= s2_valid;
      r3       <= r2 >>> SHIFT;
      // Etapa 2: captura la suma de la etapa 1 y multiplica por B.
      s2_valid <= s1_valid;
      r2       <= r1 * B;
      // Etapa 1: captura la entrada y suma A.
      s1_valid <= valid_in;
      r1       <= x_in + A;
    end
  end

endmodule
