// tb_reg_ce.sv — Testbench SystemVerilog autocontenido para reg_ce.
// Aplica 10 vectores que cubren: reset, escritura con ce=1, hold con ce=0,
// y cambio de valor mientras ce=0 (que NO debe actualizar q).
//
// Convención de timing: los estímulos se presentan en el valle del reloj y la
// salida se muestrea justo después del posedge, replicando el comportamiento
// de un registro sincrónico. Reporta PASS/FAIL por vector y un resumen final.
`timescale 1ns/1ps

module tb_reg_ce;
  logic       clk;
  logic       rst_n;
  logic       ce;
  logic [7:0] d;
  logic [7:0] q;

  integer vector_no = 0;
  integer errors    = 0;
  integer maxvec    = 10;

  // Clock 100 MHz (periodo 10 ns, 50% duty).
  always #5 clk = ~clk;
  initial clk = 0;

  reg_ce #(.W(8)) dut (
    .clk   (clk ),
    .rst_n (rst_n),
    .ce    (ce),
    .d     (d),
    .q     (q)
  );

  // Graba señal digital para GTKWave.
  initial begin
    $dumpfile("tb_reg_ce.vcd");
    $dumpvars(0, tb_reg_ce);
  end

  // Aplica un vector: presenta estímulos en el negedge , espera el posedge donde el registro
  // captura, y compara la salida contra el valor esperado.
  task drive(input logic r, input logic c, input logic [7:0] dv,
             input logic [7:0] exp);
    begin
      @(negedge clk);         
      rst_n = r;
      ce    = c;
      d     = dv;

      @(posedge clk);         // flanco activo: el registro captura
      #1;                     // margen de muestreo de q

      vector_no = vector_no + 1;
      if (q == exp) begin
        $display("  %2d | rst=%b  ce=%b  d=%02h | q=%02h  OK ",
                 vector_no, r, c, dv, q);
      end else begin
        $display("  %2d | rst=%b  ce=%b  d=%02h | q=%02h  ERROR (esperaba %02h)",
                 vector_no, r, c, dv, q, exp);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    $display("");
    $display("   # | rst    ce    d    | resultado");
    $display("-----+-------------------+----------");

    // V1: reset asíncrono activo-bajo -> q = 0
    drive(1'b0, 1'b0, 8'h00, 8'h00);
    // V2: write con ce=1 -> carga el dato
    drive(1'b1, 1'b1, 8'hAA, 8'hAA);
    // V3: write con ce=1 -> sobreescribe con el dato nuevo
    drive(1'b1, 1'b1, 8'h55, 8'h55);
    // V4: hold con ce=0 -> el dato que llega se ignora
    drive(1'b1, 1'b0, 8'hFF, 8'h55);
    // V5: hold: cambia d pero ce=0 -> no debe actualizarse
    drive(1'b1, 1'b0, 8'h12, 8'h55);
    // V6: write -> vuelve a cargar el dato
    drive(1'b1, 1'b1, 8'h12, 8'h12);
    // V7: reset asíncrono en mitad de un write -> manda el reset
    drive(1'b0, 1'b1, 8'h33, 8'h00);
    // V8: write tras reset -> carga el dato
    drive(1'b1, 1'b1, 8'h33, 8'h33);
    // V9: hold con dato nuevo mientras ce=0 -> se conserva el previo
    drive(1'b1, 1'b0, 8'h99, 8'h33);
    // V10: write a cero
    drive(1'b1, 1'b1, 8'h00, 8'h00);

    $display("-----+-------------------+----------");
    $display("");
    if (errors == 0)
      $display("RESULTADO: PASS  (%0d/%0d vectores OK)", maxvec - errors, maxvec);
    else
      $display("RESULTADO: FAIL  (%0d errores sobre %0d)", errors, maxvec);
    $display("");
    $finish;
  end

endmodule