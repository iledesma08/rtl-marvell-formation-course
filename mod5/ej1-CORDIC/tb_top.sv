/*
*   Testbench para el CORDIC folded completo 
*   Prueba con theta = pi/6, pi/4, pi/3, como pide la consigna.
*   
*/

`timescale 1ns/1ps

module tb_top;

    logic clk;
    logic reset;
    logic start;
    logic signed [15:0] titha_in;
    logic signed [15:0] cos_out;
    logic signed [15:0] sen_out;
    logic [3:0] contador_ciclos;

    //Instancio al TOP porque es el que controla ambos módulos

    top dut (
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .titha_in   (titha_in),
        .cos_out    (cos_out),
        .sen_out    (sen_out)
    );

    // Generador de clock
    always #5 clk = ~clk; //periodo de 10ns

    // Tarea para correr un caso de prueba completo
    task automatic run_case(input string nombre, input logic signed [15:0] theta, input real esperado_sen, input real esperado_cos);
        real sen_real, cos_real;
        begin
            // Cargamos el angulo y pulsamos start por un ciclo
            titha_in = theta;
            start    = 1;
            contador_ciclos = 1; //lo inicializo en 1 aca para que ya cuente el i=0 del start.
            @(posedge clk);
            start    = 0;

        
            while (dut.w_done !== 1) begin
                @(posedge clk);
                #1;
                contador_ciclos++;
            end
            contador_ciclos++; //Le sumo 1 más porque no esta llegando a contar i=13 por como funciona
            //la lógica de done

            @(posedge clk); // la FSM pasa de ITER a DONE; en este ciclo ya expone el resultado
            
            
            #1; 

            sen_real = $itor(sen_out) / 16384.0; //lo paso de entero a real para poder dividir por el escalado 2^14
            cos_real = $itor(cos_out) / 16384.0;

            $display("--------------------------------------------------");
            $display("Caso: %s (theta = %0d en S(16,14))", nombre, theta);
            $display("  sen_out = %0d -> %f  (esperado ~%f)", sen_out, sen_real, esperado_sen);
            $display("  cos_out = %0d -> %f  (esperado ~%f)", cos_out, cos_real, esperado_cos);
             $display("--------------------------------------------------");
              $display("Contador de ciclos: %0d", contador_ciclos);

            // Damos unos ciclos de margen antes del proximo caso
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        clk      = 0;
        reset    = 1;
        start    = 0;
        titha_in = 0;

        repeat (2) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // theta = pi/6 = 0.523599 rad -> 8579 en S(16,14)
        run_case("pi/6", 16'sd8579, 0.5, 0.866025);

        // theta = pi/4 = 0.785398 rad -> 12868 en S(16,14)
        run_case("pi/4", 16'sd12868, 0.707107, 0.707107);

        // theta = pi/3 = 1.047198 rad -> 17157 en S(16,14)
        run_case("pi/3", 16'sd17157, 0.866025, 0.5);

        $display("--------------------------------------------------");
        $display("Fin de la simulacion");
        $finish;
    end

endmodule