`timescale 1ns/1ps

module Tb_mul_seq;

    localparam int N_VECTORS = 200;

    logic clock;
    logic Reset;
    logic iniciar_mul;

    logic start_w;
    logic shift_en_w; 
    logic end_cy_w;

    logic [7:0] A;
    logic [7:0] B;
    logic [15:0] resultado;

    int errores;
    int ciclos;          // cuenta ciclos de clock dentro de la operacion actual
    int ciclos_op [N_VECTORS];

    //genero el clock
    initial clock = 0;
    always #5 clock = ~clock; // periodo 10ns

    //genero los DUT
    Control_FSM u_fsm (
        .clock       (clock),
        .Reset       (Reset),
        .iniciar_mul (iniciar_mul),
        .start       (start_w),
        .shift_en    (shift_en_w),
        .end_cy      (end_cy_w)
    );

    Mul_seq #(.Width_Op1(8), .Width_Op2(8)) u_mul (
        .clock    (clock),
        .Reset    (Reset),
        .start    (start_w),
        .shift_en (shift_en_w),
        .end_cy  (end_cy_w),
        .A        (A),
        .B        (B),
        .resultado(resultado)
    );

    // Cuenta flancos de clock mientras la FSM no esta en IDLE (start=0,shift_en=0,end_cy=0 en reposo)
    logic contando;

    always_ff @(posedge clock or posedge Reset) begin
        if (Reset) begin
            ciclos   <= 0;
            contando <= 1'b0;
        end else begin
            if (start_w && !contando) begin
                contando <= 1'b1; //Pongo una bandera para saber si ya esta contando
                ciclos   <= 0;
            end else if (contando) begin
                ciclos <= ciclos + 1; //Comienzo a contar ciclos mientras la bandera esta en uno
                if (end_cy_w)
                    contando <= 1'b0; //Si recibo el end_Cy termino de contar, bajo bandera
            end
        end
    end 

    task automatic run_mul(input [7:0] a_in, input [7:0] b_in, input int idx);
        logic [15:0] esperado;
        begin
            esperado = a_in * b_in;

            A = a_in;
            B = b_in;

            @(posedge clock);
            iniciar_mul = 1'b1; //Coloco manualmente el iniciar mul

            @(posedge clock);
            iniciar_mul = 1'b0; //Lo bajo 

            // Espera a que la FSM ponga uno en end_cy (Que termine de multiplicar)
            wait (end_cy_w === 1'b1); 
            @(posedge clock); // dejar que resultado se registre

            #1; // Me esataba dando problemas la lectura del vector, me daba correcto como el siguiente

            ciclos_op[idx] = ciclos;

            if (resultado !== esperado) begin
                errores++; //Si falla aumenta contador de errores
                $display("[FALLO] vector %0d: A=%0d B=%0d -> resultado=%0d esperado=%0d",
                          idx, a_in, b_in, resultado, esperado);
            end 

            
            repeat (2) @(posedge clock); //espero dos flancos de subida para seguir
        end
    endtask

    
    int total_ciclos;

    initial begin

        $dumpfile ("Tb_mul_seq.vcd");
        $dumpvars (0,Tb_mul_seq);  
        errores      = 0;
        iniciar_mul  = 0;
        A            = 0;
        B            = 0;
        total_ciclos = 0;

        Reset = 1; //arranco con reset en uno
        repeat (3) @(posedge clock); //espero tres flancos
        Reset = 0; //arranco a contar
        @(posedge clock); //espero un flanco

        //Planteo algunos casos fijos, bordes de valores, llamo a la tarea
        run_mul(8'd0,   8'd0,   0);
        run_mul(8'd255, 8'd255, 1);
        run_mul(8'd1,   8'd255, 2);
        run_mul(8'd255, 8'd1,   3);

        //Hago vectores aleatorios
        for (int i = 4; i < N_VECTORS; i++) begin
            run_mul($urandom_range(0,255), $urandom_range(0,255), i);
        end

        for (int i = 0; i < N_VECTORS; i++)
            total_ciclos += ciclos_op[i]; //Acumulo los ciclos.

        //Muestro en displays
        $display("--------------------------------------------------");
        $display("Vectores totales : %0d", N_VECTORS);
        $display("Errores          : %0d", errores);
        $display("Ciclos por operacion (vector 0): %0d", ciclos_op[0]); //El resultado actual da 9
        //pero debería ser 8 porque estoy contando desde el start, si cuento solo el tiempo en COMPUTE son 8
        $display("Total ciclos acumulados: %0d", total_ciclos);
        if (errores == 0)
            $display("RESULTADO: TODOS LOS VECTORES PASARON");
        else
            $display("RESULTADO: HAY FALLOS - revisar log");
        $display("--------------------------------------------------");

        $finish;

    end


endmodule