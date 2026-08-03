// tb_casos.v — compara caso_a (blocking) vs caso_b (non-blocking)
`timescale 1ns/1ps

module tb_casos;
  reg clk;
  reg rst_n;
  wire [3:0] aA, bA, cA;
  wire [3:0] aB, bB, cB;

  // Clock 100 MHz
  initial clk = 0;
  always #5 clk = ~clk;

  caso_a uA (.clk(clk), .rst_n(rst_n), .a(aA), .b(bA), .c(cA));
  caso_b uB (.clk(clk), .rst_n(rst_n), .a(aB), .b(bB), .c(cB));

  initial begin
    $dumpfile("tb_casos.vcd");
    $dumpvars(0, tb_casos);

    rst_n = 0;
    #12 rst_n = 1;   // Suelto reset entre flancos

    $display("");
    $display("Tiempo |  Caso A (blocking)   |  Caso B (non-blocking)");
    $display("-------+----------------------+------------------------");
    $display("  reset|  a=%0d b=%0d c=%0d         |  a=%0d b=%0d c=%0d", aA, bA, cA, aB, bB, cB);

    @(posedge clk); #1;
    $display("  10ns |  a=%0d b=%0d c=%0d         |  a=%0d b=%0d c=%0d", aA, bA, cA, aB, bB, cB);

    @(posedge clk); #1;
    $display("  20ns |  a=%0d b=%0d c=%0d         |  a=%0d b=%0d c=%0d", aA, bA, cA, aB, bB, cB);

    @(posedge clk); #1;
    $display("  30ns |  a=%0d b=%0d c=%0d         |  a=%0d b=%0d c=%0d", aA, bA, cA, aB, bB, cB);

    $display("");
    $display("Observar: Caso B rota circularmente (1,2,3)->(2,3,1)->(3,1,2)->(1,2,3)");
    $display("          Caso A NO rota -- el orden de = importa y rompe la abstraccion.");
    $display("");
    $finish;
  end
endmodule
