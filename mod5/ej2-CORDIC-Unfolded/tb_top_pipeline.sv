/*
*   Mismas 3 pruebas de ángulo que el ejercicio 1: pi/6, pi/4, pi/3
*   Diferencia clave vs el testbench folded: acá se inyecta una muestra
*   nueva por ciclo (streaming) en vez de esperar a que termine cada una,
*   y se verifica el resultado 14 ciclos después de cada entrada.
*/

`timescale 1ns/1ps

module tb_top_pipeline;

    localparam int NSTAGES   = 14;      // cantidad de etapas del pipeline (latencia en ciclos)
    localparam real PI       = 3.14159265358979;
    localparam int  Q        = 14;      // bits fraccionarios, formato S(16,14)
    localparam real SCALE    = 2.0**Q;

    logic clk;
    logic reset;
    logic signed [15:0] Z;
    logic signed [15:0] X_out, Y_out, Z_out;

    // instancia del DUT
    TOP DUT (
        .clk    (clk),
        .reset  (reset),
        .Z      (Z),
        .X_out  (X_out),
        .Y_out  (Y_out),
        .Z_out  (Z_out)
    );

    // clock 100 MHz (constraint inicial del enunciado) -> periodo 10 ns
    initial clk = 0;
    always #5 clk = ~clk;

    // ángulos de entrada (mismos que ejercicio 1)
    // Nota: Icarus no soporta inicialización de arrays con '{...} en la
    // declaración (misma limitación ya vista con la ROM en el ejercicio 1);
    // se asignan elemento a elemento dentro del initial block.
    real angles [0:2];
    logic signed [15:0] z_in_fp [0:2];

    // resultados esperados (referencia en punto flotante)
    real exp_cos [0:2];
    real exp_sin [0:2];

    // función de conversión a fixed point S(16,14)
    function automatic logic signed [15:0] to_fixed(real val);
        integer tmp;
        tmp = $rtoi(val * SCALE);
        to_fixed = tmp[15:0];
    endfunction

    // función de conversión de fixed point a real, para reportar
    function automatic real to_real(logic signed [15:0] val);
        return $itor(val) / SCALE;
    endfunction

    int i;
    int cycle, t0, t1, t2;

    initial begin
        angles[0] = PI/6.0;
        angles[1] = PI/4.0;
        angles[2] = PI/3.0;

        // precomputo entradas fixed-point y referencias esperadas
        for (i = 0; i < 3; i++) begin
            z_in_fp[i] = to_fixed(angles[i]);
            exp_cos[i] = $cos(angles[i]);
            exp_sin[i] = $sin(angles[i]);
        end

        reset = 1;
        Z     = '0;
        repeat (2) @(posedge clk);
        cycle = 0;
        reset = 0;

        // --- inyección en streaming: una muestra por ciclo ---
        // Se registra el número de ciclo exacto en que cada muestra entra
        // (t0, t1, t2), en vez de asumir un offset fijo, para que el cálculo
        // de cuándo capturar cada salida sea robusto ante cambios en la
        // secuencia de inyección.
        @(posedge clk); cycle++;
        Z = z_in_fp[0];
        t0 = cycle;

        @(posedge clk); cycle++;
        Z = z_in_fp[1];
        t1 = cycle;

        @(posedge clk); cycle++;
        Z = z_in_fp[2];
        t2 = cycle;

        // ciclo siguiente: no hay más muestras nuevas, se sostiene la entrada
        @(posedge clk); cycle++;
        Z = '0;

        // --- captura de resultados: cada muestra sale NSTAGES ciclos
        // después de su propio ciclo de inyección (t0/t1/t2), no del último
        // evento del testbench. Se avanza hasta ese ciclo exacto usando la
        // diferencia (t_i + NSTAGES - cycle) en vez de un repeat() fijo.
        repeat (t0 + NSTAGES - cycle) @(posedge clk);
        cycle = t0 + NSTAGES;
        #1;
        $display("--------------------------------------------------------");
        $display("Muestra 0 (theta = pi/6 = %0.6f rad)", angles[0]);
        $display("  cos: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_cos[0], to_real(X_out), X_out);
        $display("  sin: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_sin[0], to_real(Y_out), Y_out);
        $display("  error cos = %0.6f | error sin = %0.6f",
                  exp_cos[0]-to_real(X_out), exp_sin[0]-to_real(Y_out));

        repeat (t1 + NSTAGES - cycle) @(posedge clk);
        cycle = t1 + NSTAGES;
        #1;
        $display("--------------------------------------------------------");
        $display("Muestra 1 (theta = pi/4 = %0.6f rad)", angles[1]);
        $display("  cos: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_cos[1], to_real(X_out), X_out);
        $display("  sin: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_sin[1], to_real(Y_out), Y_out);
        $display("  error cos = %0.6f | error sin = %0.6f",
                  exp_cos[1]-to_real(X_out), exp_sin[1]-to_real(Y_out));

        repeat (t2 + NSTAGES - cycle) @(posedge clk);
        cycle = t2 + NSTAGES;
        #1;
        $display("--------------------------------------------------------");
        $display("Muestra 2 (theta = pi/3 = %0.6f rad)", angles[2]);
        $display("  cos: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_cos[2], to_real(X_out), X_out);
        $display("  sin: esperado=%0.6f  obtenido=%0.6f (fp=%0d)", exp_sin[2], to_real(Y_out), Y_out);
        $display("  error cos = %0.6f | error sin = %0.6f",
                  exp_cos[2]-to_real(X_out), exp_sin[2]-to_real(Y_out));
        $display("--------------------------------------------------------");

        $finish;
    end

endmodule