// Realiza la prueba de saturación.

`timescale 1ns/1ps
module tb_resize_sat;
  localparam int NMAX = 8192;

  logic [10:0] x_mem  [0:NMAX-1];
  logic [1:0]  op_mem [0:NMAX-1];
  logic [4:0]  y_mem  [0:NMAX-1];
  reg   [31:0] n_buf  [0:0];

  logic [10:0] x;
  logic [1:0]  op;
  logic [4:0]  y;
  logic [4:0]  y_exp;

  integer n_vectors;
  integer errors;
  integer i;

  fixed_point_resize #(
    .width_NB_in(11), .width_NBF_in(6),
    .width_NB_out(5), .width_NBF_out(3)
  ) dut (
    .x  (x),
    .op (op),
    .y  (y)
  );

  initial begin
    $readmemh("nv_sat.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("x_sat.hex", x_mem, 0, n_vectors - 1);
    $readmemh("op_sat.hex", op_mem, 0, n_vectors - 1);
    $readmemh("expected_sat.hex", y_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      x = x_mem[i];
      op = op_mem[i];       // op_sat.hex ya guarda 2/3 (OP_SAT/OP_WRAP) directo
      y_exp = y_mem[i];
      #1;
      if (y !== y_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %5d: x=%011b op=%02b -> y=%05b  esperado=%05b",
                   i, x, op, y, y_exp);
      end
      #1;
    end

    if (errors == 0)
      $display("RESULTADO (saturacion/wrap-around): PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO (saturacion/wrap-around): FAIL  (%0d errores sobre %0d)", errors, n_vectors);

    $finish;
  end
endmodule