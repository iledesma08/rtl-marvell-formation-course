/*
*   Módulo que realiza la lógica del CORDIC
*   Se intenta reutilizar el mismo módulo secuencial del ejercicio 1
*   Para este ejercicio no se requieren algunas señales de control
*/


`timescale 1ns/1ps


module CORDIC_stage #(parameter [3:0] i = 0 ) //para seleccionar a que etapa corresponde
 (
    input logic clk,
    input logic reset,
    input logic signed [15:0]  X, //señales que vienen del módulo anterior o del inicio
    input logic signed [15:0] Y,  
    input logic signed [15:0] Z,
    output  logic signed [15:0] Z_out, //señales que van al módulo siguiente
    output logic signed [15:0] X_out,
    output  logic signed[15:0] Y_out
);

/*
* //Registros que sostienen el resultado final
*/
logic signed [15:0] cos_reg = 0;
logic signed [15:0] sen_reg = 0;
logic signed [15:0] titha_reg = 0;


//me decidi por registrarlos porque estabamos teniendo errores de sincronismo
assign X_out = cos_reg;
assign Y_out = sen_reg;
assign Z_out = titha_reg;


/*
* //Señales que se utilizan para el calculo de la iteración
*/

logic signed [15:0] X_base = 0;
logic signed [15:0] Y_base = 0;
logic signed [15:0] Z_base = 0;

/*
* //Señales donde se almacena el resultado de la iteracion previo al clock (resultado combinacional)
*/


logic signed [15:0] X_next = 0;
logic signed [15:0] Y_next = 0;
logic signed [15:0] Z_next = 0;

/*
* //Señal donde se almacena la decisión
*/

logic signed [1:0] D_i = 0; //Para que pueda valer -1
logic signed [15:0] atang;

/*
*   selector de módulo por el generate
*/ 

 

ROM U_rom(

    .cordic_index(i), //Busca en base a la iteración el valor en la tabla
    .output_to_cordic(atang) //Se lo asigna a Atang

);




always_comb begin 

    /*
    *   Primero decido con qué valores voy a operar
    */
    if (i == 0) begin
        X_base = 16'sh26DD; //le asigno el valor de K 
        Y_base = 16'sd0; //cero
        Z_base = Z; //le asigno titha
    end else begin //Si no es la etapa de start, cargamos con el valor actual de la salida
        X_base = X;
        Y_base = Y;
        Z_base = Z;
    end



    /*
    *   En base a esos valores decido 
    */
    if (Z_base >= 0) begin
        D_i = 1;

    end else begin
        D_i = -1;
    end
    
    /*
    *  Opero 
    */

    //Ecuación del CORDIC
    X_next = X_base - ((D_i * Y_base) >>> (i)); 
    Y_next = Y_base + ((D_i * X_base) >>> (i));
    Z_next = Z_base - (D_i * atang);
end



always_ff @( posedge clk or posedge reset ) begin 
    
    if (reset) begin
        cos_reg <= 16'sd0; //en el ciclo i==13 esto ya es el resultado final
        sen_reg <= 16'sd0;
        titha_reg   <= 16'sd0;
        
    end else begin //debo operar sin esperar ninguna señal
        cos_reg <= X_next; //en el ciclo i==13 esto ya es el resultado final
        sen_reg <= Y_next;
        titha_reg   <= Z_next;
    end



end

endmodule