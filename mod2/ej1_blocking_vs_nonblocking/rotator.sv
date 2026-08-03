// rotator.sv — Módulo SystemVerilog con dos estilos de asignación.
// Compara blocking (=) vs non-blocking (<=) en un barrido de 3 registros
// {a,b,c}, con reset a los valores iniciales del enunciado (a=1, b=2, c=3).
//
// Parámetro STYLE:
//   0 = BLOCKING:    a = b; b = c; c = a;    (ejercicio: Caso A)
//   1 = NONBLOCKING: a <= b; b <= c; c <= a  (ejercicio: Caso B)
module rotator #(
  parameter int W = 4
)(
  input  logic clk,
  input  logic rst_n,
  input  logic style,              // 0 = blocking, 1 = nonblocking
  output logic [W-1:0] a,
  output logic [W-1:0] b,
  output logic [W-1:0] c
);

  // Reset asíncrono activo-bajo hacia los valores iniciales del enunciado.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a <= W'(1);
      b <= W'(2);
      c <= W'(3);
    end else if (style) begin
      // nonblocking — evalúa RHS, asigna LHS al final. Rota.
      a <= b;
      b <= c;
      c <= a;
    end else begin
      // blocking — el orden ESCRIBE el registro y luego lo relee.
      a = b;
      b = c;
      c = a;   // a ya fue actualizado -> usa el nuevo valor de a.
    end
  end

endmodule