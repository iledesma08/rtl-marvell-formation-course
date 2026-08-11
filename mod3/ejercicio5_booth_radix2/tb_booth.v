// tb_booth.sv — Testbench self-checking para booth_radix_2 (Ejercicio Booth).
`timescale 1ns/1ps
module tb_booth;
  localparam int NMAX = 65536;   // tope de almacenamiento de los vectores
  logic [3:0] a_mem [0:NMAX-1];  // A : S(4,0)
  logic [3:0] b_mem [0:NMAX-1];  // B : S(4,0)
  logic [7:0] p_mem [0:NMAX-1];  // esperado : S(8,0)
  reg   [31:0] n_buf[0:0];       // cantidad de vectores (nv.txt)

  logic signed [3:0] a;
  logic signed [3:0] b;
  logic signed [7:0] p;
  logic signed [7:0] p_exp;

  integer n_vectors;
  integer errors;
  integer i;

  // ---------------------------------------------------------------------
  // DUT: instancia el multiplicador Booth radix-2 con los formatos del enunciado
  // ---------------------------------------------------------------------
  booth_radix_2 #(.width_A(4), .width_B(4)) dut (
    .a (a),
    .b (b),
    .p (p)
  );


  // ---------------------------------------------------------------------
  // Verificacion
  // ---------------------------------------------------------------------
  initial begin
    $readmemh("nv.txt", n_buf);
    n_vectors = n_buf[0];
    $readmemh("a.hex", a_mem, 0, n_vectors - 1); //almaceno en el array desde 0 hasta el total de vectores - 1
    $readmemh("b.hex", b_mem, 0, n_vectors - 1);
    $readmemh("expected.hex", p_mem, 0, n_vectors - 1);

    errors = 0;
    for (i = 0; i < n_vectors; i = i + 1) begin
      a = a_mem[i];
      b = b_mem[i];
      p_exp = p_mem[i];
      #1;
      if (p !== p_exp) begin
        errors = errors + 1;
        if (errors <= 10)
          $display("  ERROR vec %4d: a=%05b  b=%05b  ->  p=%09b  esperado=%09b",
                   i, a, b, p, p_exp);
      end
      #1;
    end

    // Caso particular del enunciado (vector 0): A=+6, B=-5
    a = 4'b0110;
    b = 4'b1011;
    #1;
    $display("");
    $display("  Caso del enunciado: A=+6 (0110) x B=-5 (1011) = %0d  (S(8,0))", p);
    $display("");

    if (errors == 0)
      $display("RESULTADO: PASS  (%0d/%0d vectores OK)", n_vectors, n_vectors);
    else
      $display("RESULTADO: FAIL  (%0d errores sobre %0d)", errors, n_vectors);
    $display("");

    $finish;
  end
endmodule