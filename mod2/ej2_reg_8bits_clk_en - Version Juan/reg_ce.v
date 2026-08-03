//Ejercicio registro de 8 bits con clock enable

//timescale indica el valor de la izquierda (1ns) es la unidad de tiempo que representa cada #
// el valor derecho indica la precision con la que puedo trabajar, en este caso hasta 0.001ns
`timescale 1ns/1ps

//Este parameter define un parametro global que varia al variarlo yo de aca, en este caso 

module reg_ce #( parameter WIDTH = 8) //el tamaño del registro
(
    input wire clk,
    input wire ce,
    input wire reset_n,
    input wire [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

//Always es comun para combinacional como para el secuencial, depende de la lista de sensibilidad
//En este caso esta funcionando con un flanco de subida del clk o de bajada del reset
always_ff @(posedge clk or negedge reset_n ) begin
    if (!reset_n) begin
        q <= 8'h00; //le asigno 0 a todas las salidas del registro si hay un reset
    end else if  (ce)
        q <= d; //le asigno el nuevo valor a todas las salidas del registro si hay clk y ce esta encendido              
end
endmodule

