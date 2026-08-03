//El ejercicio 4 pide una maquina de estados de Moore que detecte una secuencia binaria 101
//Que ingresa por una entrada serial X. Cuando se detecta el patron
//la salida Y permanece en 1 durante un ciclo de clk.

`timescale 1ns/1ps

module tb_detector_101;
    //definicion de puertos
    reg clk;
    reg reset_n;
    reg x;
    wire y;
    // logic secuencia[0:10] = '{1,1,0,1,0,1,1,0,1,0,1}; Intente hacerlo con array y no compila
    reg [2:0] shift_reg;

    logic secuencia [0:10];   // declaro el arreglo, sin inicializar acá

    //lo cargo de esta manera a la secuencia por el problema de compilacion
    initial begin
    secuencia[0]  = 1;
    secuencia[1]  = 1;
    secuencia[2]  = 0;
    secuencia[3]  = 1;
    secuencia[4]  = 0;
    secuencia[5]  = 1;
    secuencia[6]  = 1;
    secuencia[7]  = 0;
    secuencia[8]  = 1;
    secuencia[9]  = 0;
    secuencia[10] = 1;
    end

    //genero variable para el bucle for y contadores
    integer i=0;
    integer sequence_count_golden=0;
    integer sequence_count=0;

    //realizo el golden model con el shift_reg
    always_ff @( posedge clk or negedge reset_n ) begin
        if ( !reset_n) begin
            shift_reg <= 3'h0;
        end else begin
            shift_reg <= {shift_reg[1:0], x};   // desplaza a la izquierda, entra "x" por la derecha
            if ({shift_reg[1:0], x} === 3'b101) //lo introduzco adentro porque como es blocking necesito comparar en la misma secuencia
            sequence_count_golden = sequence_count_golden + 1;
        end
    end


    //Creo el clock
    initial clk =  0;  
    always #5 clk = ~clk;

    //genero el DUT
    detector_101 fsm1 (.clk(clk),.reset_n(reset_n),.x(x),.y(y));
    
    //inicializo simulacion
    initial begin
    $dumpfile ("tb_detector_101.vcd");
    $dumpvars (0,tb_detector_101);    
    reset_n = 0;
    #12 reset_n = 1;
    for (i=0;i<11;i=i+1) begin
        x = secuencia[i];
        @(posedge clk); #1;
        if (y===1) begin
            sequence_count = sequence_count + 1;
        end
        $display("Salida = %0d, estado = %0d",y,fsm1.state);
    end
    $display ("Secuencias encontradas= %0d, Secuencias esperadas= %0d",sequence_count,sequence_count_golden);
    $finish;
    end

endmodule