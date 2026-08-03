//Ejercicio 3 - realizar un contador BCD con incremento en flanco de reloj si En=1 
//Debe emitir un 1 en la salida tc cuando el contador pasa de 9 a 0 (rollover)
//Debe tener reset sincrono activo por alto, colca el contador en cero


`timescale 1ns/1ps

module tb_bcd_counter;
    reg clk;
    reg reset;
    reg en;
    wire tc;
    wire [3:0] q;

    //definicion del golden model
    reg [3:0] q_golden;
    wire tc_golden;

    always_ff @(posedge clk) begin
        if (reset)
            q_golden <= 4'h0;
        else if (en)
            q_golden <= (q_golden == 4'd9) ? 4'h0 : q_golden + 4'h1; //asignacion en una sola linea
    end

    assign tc_golden = en && (q_golden == 4'd9);  //tc_golden=1 si q=9 y en=1

    //defino el tiempo 
    initial clk = 0;
    always #5 clk = ~clk;
    bcd_counter counter (.clk(clk), .reset(reset), .en(en), .tc(tc), .q(q));

    //defino variables con integer que funciona en el testbench, es un tipo de dato 
    integer i;
    integer rollover_count=0;
    integer pass_count = 0;
    integer fail_count = 0;

    //realizo la evaluacion
    initial begin
        $dumpfile ("tb_bcd_counter.vcd");
        $dumpvars (0,tb_bcd_counter);
        $display ("Se realiza la simulación sobre 100 ciclos de reloj");
        en = 1;
        reset = 1;
        #13 reset = 0; 
        for (i=0 ; i<100 ; i=i+1 ) begin
            @(posedge clk); #1;
            if (q === q_golden && tc === tc_golden) begin
                pass_count = pass_count + 1;
            end else
                fail_count=fail_count+1;
            if (tc===1) begin
                rollover_count = rollover_count + 1;
            end
            end
            
        //muestro en display el resultado de la comparacion con el golden model.    
        $display("Resumen: %0d PASS, %0d FAIL, %0d Rollover's de, %0d ciclos", pass_count, fail_count, rollover_count , i);
        $finish;
    end
endmodule