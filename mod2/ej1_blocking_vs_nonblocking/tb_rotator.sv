`timescale 1ns/1ps

// tb_rotator.sv — Testbench SystemVerilog autocontenido.
// Reporta una tabla a/b/c para t = 0, 10, 20 ns comparando blocking (Caso A)
// vs nonblocking (Caso B), y además auto-verifica contra los valores
// esperados (PASS/FAIL).
module tb_rotator;
  logic clk;
  logic rst_n;

  logic [3:0] aA, bA, cA;   // Caso A: blocking
  logic [3:0] aB, bB, cB;   // Caso B: nonblocking

  integer errors = 0;

  // Clock 100 MHz (periodo 10 ns, 50% duty).
  always #5 clk = ~clk;
  initial clk = 0;

  rotator uA (.clk(clk), .rst_n(rst_n), .style(1'b0),
              .a(aA), .b(bA), .c(cA));   // blocking
  rotator uB (.clk(clk), .rst_n(rst_n), .style(1'b1),
              .a(aB), .b(bB), .c(cB));   // nonblocking

  // Graba para GTKWave.
  initial begin
    $dumpfile("tb_rotator.vcd");
    $dumpvars(0, tb_rotator);
  end

  // Muestra una fila de la tabla con los valores instantaneos de ambos casos.
  task show_row(input string label);
    $display("%s |  a=%0d b=%0d c=%0d           |  a=%0d b=%0d c=%0d",
             label, aA, bA, cA, aB, bB, cB);
  endtask

  // Compara una tripleta (va,vb,vc) vs espera (ea,eb,ec), con rótulo.
  task do_check;
    input integer ea, eb, ec;
    input [3:0] va, vb, vc;
    input integer label;
    begin
      if (va == ea && vb == eb && vc == ec) begin
        $display("      %s -> a=%0d b=%0d c=%0d ... OK ",
                 (label == 0) ? "Caso A (blocking)    " : "Caso B (nonblocking) ", va, vb, vc);
      end else begin
        $display("      %s -> a=%0d b=%0d c=%0d ... MAL (esperaba %0d %0d %0d)",
                 (label == 0) ? "Caso A (blocking)    " : "Caso B (nonblocking) ",
                 va, vb, vc, ea, eb, ec);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    errors = 0;
    rst_n = 0;
    #12 rst_n = 1;   // suelto reset asíncrono entre flancos de clock

    $display("");
    $display("Flanco |  Caso A (blocking)     |  Caso B (non-blocking) ");
    $display("-------+------------------------+-------------------------");
    show_row("   0  ");
    @(posedge clk); #1;
    show_row("   1  ");
    @(posedge clk); #1;
    show_row("   2  ");
    $display("-------+------------------------+-------------------------");

    $display("");
    $display("--- Reset y re-medicion sobre 2 flancos consecutivos ---");
    $display("");
    rst_n = 0;
    #12 rst_n = 1;

    @(posedge clk); #1;
    // 1er flanco.
    // A (blocking): a=b(2); b=c(3); c=a(ya=2) => 2,3,2   (NO rota)
    // B (nonblock): a=2; b=3; c=a_viejo(1)    => 2,3,1   (rota)
    do_check(2,3,2, aA,bA,cA, 0);
    do_check(2,3,1, aB,bB,cB, 1);

    @(posedge clk); #1;
    // 2do flanco: sobre 2,3,2 y 2,3,1.
    // A: a=b(3); b=c(2); c=a(3) => 3,2,3
    // B: a=3; b=1; c=2           => 3,1,2
    do_check(3,2,3, aA,bA,cA, 0);
    do_check(3,1,2, aB,bB,cB, 1);

    $display("");
    if (errors == 0)
      $display("RESULTADO PASS (0 errores). El rotador real es el Caso B (nonblocking).");
    else
      $display("RESULTADO FAIL (%0d errores).", errors);
    $display("");
    $finish;
  end

endmodule