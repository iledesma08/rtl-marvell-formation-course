/*
*   Módulo que realiza la lógica del CORDIC
*   Recibe señales de la máquina de estados y luego define qué hacer
*   El cálculo de CORDIC se realiza de forma combinacional y el cambio de valor
*   de los registros se hace de forma secuencial.
*/


`timescale 1ns/1ps


module CORDIC (
    input logic clk,
    input logic reset,
    input logic start,
    input  logic signed [15:0] titha,
    output logic signed [15:0] cos,
    output  logic signed[15:0] sen,
    output logic done
);

/*
* //Registros que sostienen el resultado final
*/
logic signed [15:0] cos_reg = 0;
logic signed [15:0] sen_reg = 0;


//me decidi por registrarlos porque estabamos teniendo errores de sincronismo
assign cos = cos_reg;
assign sen = sen_reg;


/*
* //Señales donde se almacena el resultado de la iteracion post clock
*/

logic signed [15:0]  X = 0; 
logic signed [15:0] Y = 0;
logic signed [15:0] Z = 0;

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
* //contador de iteracion
*/

logic  [3:0] i = 0;
logic  [3:0] i_next = 0;

/*
* //Señales para interactuar con la máquina de estados
*/

logic Busy = 0;

ROM U_rom(

    .cordic_index(i), //Busca en base a la iteración el valor en la tabla
    .output_to_cordic(atang) //Se lo asigna a Atang

);




always_comb begin 

    /*
    *  Trabajo con el contador 
    */

    i_next = i;

    if (i == 13) begin
        i_next = 0;
        
    end else i_next ++;
    


    /*
    *   Primero decido con qué valores voy a operar
    */
    if (start) begin
        X_base = 16'sh26DD; //le asigno el valor de K 
        Y_base = 16'sd0; //cero
        Z_base = titha; //le asigno titha
        done = 0;
    end else begin //Si no es la etapa de start, cargamos con el valor actual de la salida
        X_base = X;
        Y_base = Y;
        Z_base = Z;
        done = 0;
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

    if (i == 13) begin
        done = 1;
    end
end



always_ff @( posedge clk or posedge reset ) begin 
    
    if (reset) begin
        //reinicio todos los operandos y el contador
        X <= 16'sd0;
        Y <= 16'sd0;
        Z <= 16'sd0;
        i <= 4'sd0;
        Busy <= 0;
    end else if (start || Busy) begin //Si recibo la señal 
        X <= X_next;
        Y <= Y_next;
        Z <= Z_next;
        i <= i_next;
        cos_reg <= X_next; //en el ciclo i==13 esto ya es el resultado final
        sen_reg <= Y_next;
        Busy <= (i == 13) ? 1'b0 : 1'b1; //se apaga UN CICLO DESPUES
        //me estaba faltando el último ciclo si lo hago combinacional.
    end



end

endmodule