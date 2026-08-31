/*
* Es un módulo que funciona como ROM a la que el módulo CORDIC
* accedera con un index para obtener el valor correspondiente
* NB = 16, NBF = 14, N_ITER = 14
*/


`timescale 1ns/1ps

module ROM (
    input  logic [3:0] cordic_index, //Utilizado para seleccionar valor
    output logic signed [15:0] output_to_cordic //Salida que va hacia el cordic
);

    always_comb begin
        case (cordic_index) //Tuve que hacerlo con case porque no me dejaba con localparam a causa de un error de icarus
        
            4'd0:  output_to_cordic = 16'sh3244; // i=0  -> arctan(2^0)   = 0.785398 rad
            4'd1:  output_to_cordic = 16'sh1DAC; // i=1  -> arctan(2^-1)  = 0.463648 rad
            4'd2:  output_to_cordic = 16'sh0FAE; // i=2  -> arctan(2^-2)  = 0.244979 rad
            4'd3:  output_to_cordic = 16'sh07F5; // i=3  -> arctan(2^-3)  = 0.124355 rad
            4'd4:  output_to_cordic = 16'sh03FF; // i=4  -> arctan(2^-4)  = 0.062419 rad
            4'd5:  output_to_cordic = 16'sh0200; // i=5  -> arctan(2^-5)  = 0.031240 rad
            4'd6:  output_to_cordic = 16'sh0100; // i=6  -> arctan(2^-6)  = 0.015624 rad
            4'd7:  output_to_cordic = 16'sh0080; // i=7  -> arctan(2^-7)  = 0.007812 rad
            4'd8:  output_to_cordic = 16'sh0040; // i=8  -> arctan(2^-8)  = 0.003906 rad
            4'd9:  output_to_cordic = 16'sh0020; // i=9  -> arctan(2^-9)  = 0.001953 rad
            4'd10: output_to_cordic = 16'sh0010; // i=10 -> arctan(2^-10) = 0.000977 rad
            4'd11: output_to_cordic = 16'sh0008; // i=11 -> arctan(2^-11) = 0.000488 rad
            4'd12: output_to_cordic = 16'sh0004; // i=12 -> arctan(2^-12) = 0.000244 rad
            4'd13: output_to_cordic = 16'sh0002; // i=13 -> arctan(2^-13) = 0.000122 rad
            default: output_to_cordic = 16'sh0000; // indices 14,15 no deberian ocurrir nunca
        endcase
    end

endmodule