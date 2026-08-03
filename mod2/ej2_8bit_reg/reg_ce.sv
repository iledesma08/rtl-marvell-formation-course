// reg_ce.sv — Registro de N bits parametrizable con clock enable.
// Implementa el patrón canónico de un registro RTL:
//
//   - Reset asíncrono activo-bajo (rst_n) chequeado PRIMERO.
//   - Si ce = 1, captura el dato presente en d en cada posedge clk.
//   - Si ce = 0, el registro mantiene el valor anterior (hold).
//   - En reset, q se inicializa en 0.
//
// Pista del enunciado: en el always_ff primero la rama de reset (if (!rst_n))
// y después la lógica habilitada por ce. Ese es el patrón canónico.
module reg_ce #(
  parameter int W = 8
)(
  input  logic clk,
  input  logic rst_n,      // reset asíncrono activo-bajo
  input  logic ce,         // clock enable activo-alto
  input  logic [W-1:0] d,  // dato de entrada
  output logic [W-1:0] q   // registro de salida
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      q <= '0;             // reset: q = 8'h00
    end else if (ce) begin
      q <= d;              // ce = 1: cargar el dato
    end
    // ce = 0: no hay asignación -> el FF mantiene el valor previo (hold)
  end

endmodule