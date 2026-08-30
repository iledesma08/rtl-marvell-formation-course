
/*
*   Módulo TOP que instancia los 14 CORDIC_stage con generate
*
*/

`timescale 1ns/1ps

module TOP (
    input logic clk,
    input logic reset,
    input logic signed [15:0] Z, //señal para iniciar con thitha
    output  logic signed [15:0] Z_out, //señales para mostrar
    output logic signed [15:0] X_out,
    output  logic signed[15:0] Y_out
);

    logic signed [15:0] X_pass[14:0]; //señales donde se almacena lo del modulo siguiente 
    logic signed [15:0] Y_pass[14:0]; //señales donde se almacena lo del modulo siguiente 
    logic signed [15:0] Z_pass[14:0]; //señales donde se almacena lo del modulo siguiente 

    genvar k;


    CORDIC_stage #(.i(0)) U_CORDIC0     //para i=0
    ( 
        .clk(clk),
        .reset(reset),
        .X(0),  
        .Y(0),
        .Z(Z), //titha inicial
        .X_out(X_pass[1]), //la salida de este módulo carga la de los siguientes
        .Y_out(Y_pass[1]),
        .Z_out(Z_pass[1])

    );

   

    generate
        
        for (k = 1 ; k < 14 ; k++ ) begin
            
        CORDIC_stage #(.i(k)) U_CORDIC_K    //para i=0
        ( 
        .clk(clk),
        .reset(reset),
        .X(X_pass[k]),  //salida de esta etapa 
        .Y(Y_pass[k]),
        .Z(Z_pass[k]), 
        .X_out(X_pass[k+1]), //la salida de este módulo carga la de los siguientes
        .Y_out(Y_pass[k+1]),
        .Z_out(Z_pass[k+1])
        );

        end


    endgenerate


assign X_out = X_pass[14];
assign Y_out = Y_pass[14];
assign Z_out = Z_pass[14];    
endmodule