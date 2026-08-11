//Realiza unicamente la prueba de truncamiento.
// NBI constante. 
`timescale 1ns/1ps
module tb_resize_tr;
  localparam int NMAX = 8192;

  logic [9:0] x_mem  [0:NMAX-1];
  logic [1:0] op_mem [0:NMAX-1];
  logic [6:0] y_mem  [0:NMAX-1];
  reg  [31:0] n_buf  [0:0];

  logic [9:0] x;
  logic [1:0] op;
  logic [6:0] y;
  logic [6:0] y_exp;

  integer n_vectors;
  integer errors;
  integer i;

  fixed_point_resize #(
    .width_NB_in(10), .width_NBF_in(6),
    .width_NB_out(7), .width_NBF_out(3)
  ) dut (
    .x  (x),
    .op (op),
    .y  (y)
  );

  initial begin
    $readmemh("nv_tr.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("x_tr.hex", x_mem, 0, n_vectors - 1);
    $readmemh("op_tr.hex", op_mem, 0, n_vectors - 1);
    $readmemh("expected_tr.hex", y_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      x = x_mem[i];
      op = op_mem[i];
      y_exp = y_mem[i];
      #1;
      if (y !== y_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %5d: x=%010b op=%02b -> y=%07b  esperado=%07b",
                   i, x, op, y, y_exp);
      end
      #1;
    end

    if (errors == 0)
      $display("RESULTADO (truncamiento/redondeo): PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO (truncamiento/redondeo): FAIL  (%0d errores sobre %0d)", errors, n_vectors);

    $finish;
  end
endmodule