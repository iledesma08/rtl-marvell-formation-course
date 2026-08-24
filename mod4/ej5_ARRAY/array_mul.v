//Ejercicio: Crear un array multiplier de 8X8
//Es combinacional.
//Estan planteadas dos formas de hacerlo. 

`timescale 1ns/1ps


module array_mul #(parameter Width_Op1 = 8, Width_Op2 = 8, Width_P = Width_Op1 + Width_Op2) 
(
    input logic [Width_Op1-1:0 ]a,
    input logic [Width_Op2-1:0]b,
    output logic [Width_P-1:0]p
);


//Lo primero que quiero hacer es obtener los productos parciales recorriendo 
//numero B y haciendo And con A.

logic [Width_P-1:0] PPs [8]; //Es el máximo de productos parciales que puedo tener
logic [Width_P-1:0] Si [7]; //Son los vectores de resultado
logic [Width_P-1:0] S [Width_Op2];
logic [Width_P-1:0] C [Width_Op2];

genvar i,j;

generate
    
    /*
    *
    *   Primera parte: Obtengo los productos parciales
    *    
    */

    for ( i = 0 ;i < (Width_Op2) ;i = i + 1 ) begin

       //realizo los productos parciales con asign. 
       assign PPs[i] = (a & {Width_Op1{b[i]}}) << i;
    end

endgenerate



assign S[0] = PPs[0]; //toma el valor del primer producto parcial
assign C[0] = '0; //Toma 0

generate

    /*
    *
    *   Segunda parte: Realizo la suma en cada celda.
    *    
    */
    
    

    for (i = 1 ; i <(Width_Op2) ;i = i+1 ) begin
        logic [Width_P-1:0] carry;
        for (j = 0 ;j <Width_P ;j=j+1 ) begin
            //Aca instancio los full-adders para recorrer la matriz de PPs con ellos.
            //Hago full-adder por cada columna entre dos filas.
            full_adder U_full(
                .a (S[i-1][j]), //recorro cada columna de cada fila
                .b (C[i-1][j]), //recorro cada columna de cada fila del carry 
                .cin(PPs[i][j]), //recorro las siguientes filas excepto la 0 porque es S0
                .S(S[i][j]),//Almaceno el resultado en el vector S de esta fila sería
                .cout(carry[j]) //Almaceno en un vector nuevo el carry de resultado.
            );
        end
        assign C[i] = carry << 1; //el carry pesa una columna mas
    end
endgenerate

logic [Width_P-1:0] RCA;

generate
    
    for (j = 0; j<Width_P ;j=j+1 ) begin

            full_adder u_RCA(
                .a(S[Width_Op2-1][j]), //Analizo el último sumador
                .b(C[Width_Op2-1][j]),
                .cin(j==0 ? 1'b0:RCA[j-1]),
                .S(p[j]),
                .cout(RCA[j])
            );
    end


endgenerate

    
/*---------------------------------------------
*   Hasta aca es compartido por ambos métods
*   La diferencia entre los dos es que una es behavioral (El segundo)
*   El primero tiene una explicación y desarrollo mas estructural
-----------------------------------------------*/



/*
    *
    *   Segunda parte: Realizo las sumas parciales por columna una vez ya obtenidos los PPs.
    *   Esta opcion es una version behavioral -> por el operando + que uso
    *   Debería ser una descripción mas estructural.    
    *
*/



/*
    *
    *   Segunda parte: Realizo las sumas parciales por columna una vez ya obtenidos los PPs.
    *   Esta opcion es una version behavioral -> por el operando + que uso
    *   Debería ser una descripción mas estructural.    
    *
*/

/*for (int j = 0 ;j < (Width_Op2-2); j = j + 1 ) begin
    
    if (j == 0) begin
        Si[0] = PPs[0] + PPs[1]; //Hago la suma entre el PPs 0 y el PPs 1, el primero puede ser Half-adder
    end else begin
        Si[j] = PPs[j+1] + Si[j-1]; //A partir de aca hago suma con el resultado anterior - a partir de aca son FA
    end
end

p = Si[Width_Op2-1];
*/


endmodule