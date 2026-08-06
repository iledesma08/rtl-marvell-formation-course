//Ejercicio 3 - realizar un contador BCD con incremento en flanco de reloj si En=1 
//Debe emitir un 1 en la salida tc cuando el contador pasa de 9 a 0 (rollover)
//Debe tener reset sincrono activo por alto, coloca el contador en cero

//defino el tiempo y precision
`timescale 1ns/1ps

//defino puertos del modulo
module bcd_counter (
    input wire clk,
    input wire reset,
    input wire en,
    output wire tc,
    output reg [3:0] q
);
//defino funcionamiento del modulo
    always_ff @( posedge clk ) begin 
        if (reset) begin
            q <= 4'h0; 
        end
        else if (en)
            if (q!==9) begin
                q <= q+1; //es valido en system, no como en VHDL que no deja leer salidas.
            end else
                q <= 0;
             
    end
    
    //tc debe ser combinacional para que dure 1 ciclo.
    assign tc = en && (q == 4'd9);  //tc=1 si q=9 y en=1
endmodule