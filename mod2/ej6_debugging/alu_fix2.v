//analizar el código para identificar el BUG que la sintesis convierte en latch y luego:
// 1) Identificar el BUG y por que se infiere el LATCH
// 2) Proponer dos fixes uno default y otro de pre-asignacion
// 3) Implementar ambas versiones y observar equivalencias
// 4) Inspeccionar con YOSYS que no quede LATCHES

// FIX con preasignacion


`timescale 1ns/1ps



module alu_fix2 #(parameter width = 8, widthOP = 2) //el parametro no se define fuera del modulo
    (
    input wire signed [width-1:0] a,
    input wire signed [width-1:0] b,
    input wire [widthOP-1:0] op,
    output reg signed [width-1:0] y  //el wire solo se puede modificar en assign.
    );
    

    
    always_comb begin

        y = 8'h0; //se le preasigna un valor antes de entrar al case, en caso de que no
                  //corresponda a ningun caso este es el valor que toma
        case (op)

            2'b00: y = a + b;

            2'b01: y = a - b;

            2'b10: y = a & b;
            
        endcase

    end



endmodule