// tb_rca_delay.sv — Barrido de delay del RCA para N = {4, 8, 16, 32}.
//
// Instancia cuatro RCA de distinto ancho, les aplica el peor caso de ripple
// de carry (a = todos-1, b = 1, cin = 0) y mide, para cada uno, el instante
// en que la ultima salida deja de cambiar (t_last). Escribe los resultados en
// delays.txt (los consume plot_delay.py) y ademas los muestra en consola.

`timescale 1ns/1ps

module tb_rca_delay;

  // ---- Instancias del DUT para cada ancho ---------------------------------
  logic [ 3:0] a4,  b4,  sum4;
  logic        cin4, cout4;
  logic [ 7:0] a8,  b8,  sum8;
  logic        cin8, cout8;
  logic [15:0] a16, b16, sum16;
  logic        cin16, cout16;
  logic [31:0] a32, b32, sum32;
  logic        cin32, cout32;

  rca #(.N(4))  dut4  (.a(a4),  .b(b4),  .cin(cin4),  .sum(sum4),  .cout(cout4));
  rca #(.N(8))  dut8  (.a(a8),  .b(b8),  .cin(cin8),  .sum(sum8),  .cout(cout8));
  rca #(.N(16)) dut16 (.a(a16), .b(b16), .cin(cin16), .sum(sum16), .cout(cout16));
  rca #(.N(32)) dut32 (.a(a32), .b(b32), .cin(cin32), .sum(sum32), .cout(cout32));

  time t_last [0:3];           // ultimo instante de cambio por cada DUT
  time t0;
  time delay [0:3];
  integer fd;
  integer k;

  // Forma de onda para GTKWave
  initial begin
    $dumpfile("tb_rca_delay.vcd");
    $dumpvars(0, tb_rca_delay);
  end

  // Monitores: registran el instante de la ultima transicion de cada salida.
  always @(sum4  or cout4)  t_last[0] = $time;
  always @(sum8  or cout8)  t_last[1] = $time;
  always @(sum16 or cout16) t_last[2] = $time;
  always @(sum32 or cout32) t_last[3] = $time;

  initial begin
    $display("");
    $display("==============================================================");
    $display("EJERCICIO 1 - Barrido de delay del RCA (peor caso de ripple)");
    $display("==============================================================");

    // Estado inicial estable: 0 + 0.
    a4=0; a8=0; a16=0; a32=0; b4=0; b8=0; b16=0; b32=0;
    cin4=0; cin8=0; cin16=0; cin32=0;
    #100; // Estabilizamos

    // Aplicamos el peor caso a los cuatro DUTs a la vez.
    t0 = $time;
    foreach (t_last[i]) t_last[i] = t0;
    a4   = '1; b4   = 1;
    a8   = '1; b8   = 1;
    a16  = '1; b16  = 1;
    a32  = '1; b32  = 1;
    cin4 = 0; cin8 = 0; cin16 = 0; cin32 = 0;
    #200;                        // mas que suficiente para que estabilice todo

    fd = $fopen("delays.txt", "w");
    $display("");
    $display("  N | full_adders | delay [ns]");
    $display("----+-------------+-----------");
    for (k = 0; k < 4; k = k + 1) begin
      delay[k] = t_last[k] - t0;
      // Anchos barridos: 4, 8, 16, 32 = 1 << (k+2)
      $fdisplay(fd, "%0d %0d", (1 << (k + 2)), delay[k]);
      $display("%3d |     %3d     |  %0d", (1 << (k + 2)), (1 << (k + 2)), delay[k]);
    end
    $fclose(fd);

    $display("");
    $display("Tabla guardada en delays.txt  ->  plot_delay.py genera la grafica.");
    $display("");
    $finish;
  end

endmodule