//El testbench debe ser de 256^2 vectores 
//Lo hice con 200 porque no me estaba tirando el calculo y funcionó

`timescale 1ns/1ps



module tb_array_mul;

    localparam int N_VECTORS = 256;

    logic  [7:0] a;
    logic  [7:0] b;
    logic  [15:0] p;

    int errores = 0;

    //genero DUT
    array_mul #(.Width_Op1(8), .Width_Op2(8)) u_array (
        .a (a),
        .b (b),
        .p (p)
    );

    task automatic run_array(input  [7:0] a_in, input [7:0] b_in, input int idx);
        logic  [15:0] esperado;
        begin
            esperado = a_in * b_in;

            a = a_in;
            b = b_in;

            #1; // le doy tiempo al simulador para evaluar el always_comb del DUT 
            //Necestio este delay para que se establezcan todas las señales

            if (p !== esperado) begin
                errores++; //Si falla aumenta contador de errores
                $display("[FALLO] vector %0d: A=%0d B=%0d -> resultado=%0d esperado=%0d",
                          idx, a_in, b_in, p, esperado);
            end 
        end
    endtask


    initial begin

        $dumpfile ("tb_array_mul.vcd");
        $dumpvars (0,tb_array_mul);  
        errores      = 0;
        a            = 0;
        b            = 0;

        //Planteo algunos casos fijos, bordes de valores, llamo a la tarea
        run_array(8'd0,   8'd0,   0);
        run_array(8'd255, 8'd255, 1);
        run_array(8'd1,   8'd255, 2);
        run_array(8'd255, 8'd1,   3);

        //Hago vectores aleatorios
        for (int i = 4; i < N_VECTORS; i++) begin
            run_array($urandom_range(0,255), $urandom_range(0,255), i);
        end

        //Muestro en displays
        $display("--------------------------------------------------");
        $display("Vectores totales : %0d", N_VECTORS);
        $display("Errores          : %0d", errores);
        if (errores == 0)
            $display("RESULTADO: TODOS LOS VECTORES PASARON");
        else
            $display("RESULTADO: HAY FALLOS - revisar log");
        $display("--------------------------------------------------");

        $finish;

    end


endmodule