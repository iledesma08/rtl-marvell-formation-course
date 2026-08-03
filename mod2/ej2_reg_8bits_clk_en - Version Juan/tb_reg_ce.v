//Testbench del ejercicio 2 - registro de 8 bits con clk enable

//Defino valores de tiempo y precision
`timescale 1ns/1ps

//Defino ancho de los registros


//Defino puertosñ
module tb_reg_ce;
    localparam WIDTH = 8;
    reg clk; //si en el modulo es input se le coloca REG por regla de sintaxis
    reg ce1,ce2;
    reg reset_n;
    reg [WIDTH-1:0] q1_esperado; //utilizado para la verificacion
    reg [WIDTH-1:0] q2_esperado; //utilizado para la verificacion
    reg [WIDTH-1:0] d;
    wire [WIDTH-1:0] q1 , q2; //si en el modulo es output se le coloca WIRE por regla de sintaxis

    //genero variable para el for y contadores
    integer i;
    integer pass_count=0;
    integer fail_count=0;
    integer tiempo=0;

    //Defino clk
    initial clk = 0; //inicializa clk en 0
    always #5 clk = ~clk; //cada 5ns hay un flanco, esto genera periodo de 10ns

    //Defino DUT, la salida debe ser diferenciada, por eso defino q1 y q2
    reg_ce registro_1 (.clk(clk),.ce(ce1),.reset_n(reset_n),.d(d),.q(q1)); 
    reg_ce registro_2 (.clk(clk),.ce(ce2),.reset_n(reset_n),.d(d),.q(q2)); //hago dos para que corran con Ce = 1 y Ce = 0 a la vez

    initial begin
    $dumpfile ("tb_reg_ce.vcd");
    $dumpvars (0, tb_reg_ce);
    reset_n=0;
    #12 reset_n=1; //a los 12 ns activa el reset
    $display("Simulación iniciada");
    $display("Tiempo    |    D    |    Q1   |    Q2    |    CE 1    |    CE 2    |   STATUS   |");
    d = 8'h00; //inicializa con d en 0
    ce1 = 1;
    ce2 = 1;
    
    //for para generar los valores
    for (i=0 ;i<11;i=i+1 ) begin
      tiempo = tiempo + 10; //contador para el display

    //flanco
     @(posedge clk); #1; 

    //se realiza la evaluación para verificar.
    if (!reset_n)
        q1_esperado = 0;
    else if (ce1)
        q1_esperado = d;
    if (!reset_n)
        q2_esperado = 0;
    else if (ce2)
        q2_esperado = d;
    if(q1 === q1_esperado && q2 === q2_esperado) begin
    $display(" %0d ns  |   D=%0d   |   Q1=%0d   |   Q2=%0d   |   Ce1=%0d   |   Ce2=%0d   | PASS",tiempo ,d, q1, q2, ce1, ce2);
    pass_count=pass_count+1;
    end else begin
    $display(" %0d ns   |   D=%0d   |   Q1=%0d   |   Q2=%0d   |   Ce1=%0d   |   Ce2=%0d   | FAIL", tiempo ,d, q1, q2, ce1, ce2); 
    fail_count=fail_count+1;
    end

    d = $random;
    ce1 = 1;
    ce2 = 1;  
    
    end
    
    $display("Simulación finalizada, Cantidad de PASS = %0d, Cantidad de FAIL= %0d ", pass_count, fail_count);
    $finish;   
    end
endmodule