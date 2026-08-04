//analizar el código para identificar el BUG que la sintesis convierte en latch y luego:
// 1) Identificar el BUG y por que se infiere el LATCH
// 2) Proponer dos fixes uno default y otro de pre-asignacion
// 3) Implementar ambas versiones y observar equivalencias
// 4) Inspeccionar con YOSYS que no quede LATCHES

`timescale 1ns/1ps




module tb_alu; 
    parameter width = 8, 
    widthOP = 2;

    //Como a,b y op estan bajo el mismo estimulo no es necesario hacer 3 señales distintas
    reg signed [width-1:0]  a;
    reg signed [width-1:0]  b;
    reg [widthOP-1:0] op;

    //Las salidas si requieren de 3 señales distintas porque pueden tomar valores distintos
    wire  signed [width-1:0]  y_bad;
    wire  signed [width-1:0]  y_fix1;
    wire  signed [width-1:0]  y_fix2;

    //defino variables para el testbench
    integer pass_count = 0;
    integer fail_count = 0;
    integer i;
    integer j;

    //en este caso no es necesario definir el clk porque es logica combinacional.

    //Genero los DUT
    alu_bad bad (.a(a), .b(b), .op(op), .y(y_bad));
    alu_fix1 fix1 (.a(a), .b(b), .op(op), .y(y_fix1));
    alu_fix2 fix2 (.a(a), .b(b), .op(op), .y(y_fix2));


    //defino una task para simplificar el codigo, la task compara el valor de las Y para ver en cuanto coiniciden las 3
    task automatic evalauacion_y_verificacion(); //no necesita parametros porque no hace mas que comparar el valor de Y
        if (y_bad === y_fix1 && y_fix1 === y_fix2) begin
            pass_count = pass_count + 1;
        end else begin
            fail_count = fail_count + 1;
            $display("OP= %0b ,y_bad= %0d , y_default= %0d , y_preasignacion= %0d ", op,y_bad, y_fix1, y_fix2); //para simplificar display y que no muestre siempre resultados
        end

    endtask //automatic

    initial begin
        $dumpfile ("tb_alu.vcd");
        $dumpvars (0,tb_alu);


        //no es necesario colocar valores iniciales ni de reset ni de En    

        //realizo el bucle for para recorrer el vector 
        for ( i=0 ; i<64 ; i=i+1 ) begin
            for ( j=0 ; j<4 ; j=j+1 ) begin
                //lo que hago es asignarle nuevos valores a las entradas del combinacional
                a=$random; //a toma valores randoms
                b=$random; //b toma valores randoms
                op=j;      //con OP=j lo que hace es tomar valores entre 0 y 3 para hacer todas las OP
                #1; //es para que la logica combinacional se establezca 
                evalauacion_y_verificacion();
            end

            
        end

        $display("PASS= %0d, FAIL= %0d", pass_count, fail_count);
        $finish;

    end

endmodule