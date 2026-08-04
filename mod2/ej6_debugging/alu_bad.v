//analizar el código para identificar el BUG que la sintesis convierte en latch y luego:
// 1) Identificar el BUG y por que se infiere el LATCH
// 2) Proponer dos fixes uno default y otro de pre-asignacion
// 3) Implementar ambas versiones y observar equivalencias
// 4) Inspeccionar con YOSYS que no quede LATCHES

`timescale 1ns/1ps




module alu_bad #(parameter width = 8, widthOP = 2) //el parametro no se define fuera del modulo
    (
    input wire signed [width-1:0] a,
    input wire signed [width-1:0] b,
    input wire [widthOP-1:0] op,
    output reg signed [width-1:0] y  //el wire solo se puede modificar en assign.
    );
    

    
    always_comb begin

        case (op)

            2'b00: y = a + b;

            2'b01: y = a - b;

            2'b10: y = a & b;
            
            //el error que subyase aca es que si alu toma el valor de 11 no existe ninguna 
            //condición por lo que conserva el valor anterior esto infiere un LATCH 
            //Toda salida debe ser asignada en toda momento sino mantiene el error anterior (latch)
        endcase

    end



endmodule