//TB completamente funcional con los 200 vectores probados.
//Es similar al del ejercicio 4 pero con el conteo de PPs


`timescale 1ns/1ps



module tb_booth;

    localparam int N_VECTORS = 200;

    logic signed [7:0] a;
    logic  signed [7:0] b;
    logic  signed [15:0] p;

    int errores = 0;
    int Sumas_Parciales = 0;
    int flag = 0 ;

    //genero DUT
    booth_r2 #(.width_A(8), .width_B(8)) u_booth (
        .a (a),
        .b (b),
        .p (p)
    );



    task automatic run_booth(input signed [7:0] a_in, input signed [7:0] b_in, input int idx);
        logic signed [15:0] esperado;
        logic signed [8:0] b_radix_2_tb;
        begin
            esperado = a_in * b_in;

            
        
            a = a_in;
            b = b_in;

            #1; // le doy tiempo al simulador para evaluar el always_comb del DUT 
            
            b_radix_2_tb = {b, 1'b0}; //Genero para obtener cantidad de sumas parciales
            
            //Necestio este delay para que se establezcan todas las señales

             for (int i = 1; i <= 8; i = i + 1) begin       
                flag = b_radix_2_tb[i -: 2];

                 if (flag == 2'b01 || flag == 2'b10) begin
                        Sumas_Parciales = Sumas_Parciales + 1; //excplicito los casos porque 11 es distinto de 0 tambien
                    end
             end

            if (p !== esperado) begin
                errores++; //Si falla aumenta contador de errores
                $display("[FALLO] vector %0d: A=%0d B=%0d -> resultado=%0d esperado=%0d",
                          idx, a_in, b_in, p, esperado);
            end 
        end
    endtask


    initial begin

        $dumpfile ("tb_booth.vcd");
        $dumpvars (0,tb_booth);  
        errores      = 0;
        a            = 0;
        b            = 0;

        //Planteo algunos casos fijos, bordes de valores, llamo a la tarea
        run_booth(8'd0,   8'd0,   0);
        run_booth(8'd255, 8'd255, 1);
        run_booth(8'd1,   8'd255, 2);
        run_booth(8'd255, 8'd1,   3);

        //Hago vectores aleatorios
        for (int i = 4; i < N_VECTORS; i++) begin
            run_booth($urandom_range(0,255), $urandom_range(0,255), i);
        end

        //Muestro en displays
        $display("--------------------------------------------------");
        $display("Vectores totales : %0d", N_VECTORS);
        $display("Errores          : %0d", errores);
        $display("Productos Parciales  : %0d", Sumas_Parciales);
        if (errores == 0)
            $display("RESULTADO: TODOS LOS VECTORES PASARON");
        else
            $display("RESULTADO: HAY FALLOS - revisar log");
        $display("--------------------------------------------------");

        $finish;

    end


endmodule