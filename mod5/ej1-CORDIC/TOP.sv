/*
*   Módulo top: instancia FSM y CORDIC 
*/

`timescale 1ns/1ps

module top (
    input  logic clk,   //entrada del clk
    input  logic reset, 
    input  logic start, //entrada de start por el tb                   
    input  logic signed [15:0] titha_in,   // angulo pedido 
    output logic signed [15:0] cos_out,    // resultados que se van a mostrar
    output logic signed [15:0] sen_out
);

    //Señales que van a conectar la FSM con el CORDIC
    logic        w_start_cordic;   // señal start_cordic 
    logic        w_done;           // señal done del cordic para la FSM
    logic signed [15:0] w_titha;   // Señal envía LA FSM al CORDIC con el angulo
    logic signed [15:0] w_cos;     // Resulado del CORDIC
    logic signed [15:0] w_sen;     

    FSM U_fsm (
        //conecto todos los puertos a una señal del TOP
        .clk        (clk),
        .reset      (reset),
        .start      (start),
        .done       (w_done),
        .titha_in   (titha_in),
        .seno_in    (w_sen),
        .coseno_in  (w_cos),
        .coseno_out (cos_out),
        .seno_out   (sen_out),
        .titha_out  (w_titha),
        .start_cordic(w_start_cordic)
    );

    CORDIC U_cordic (
         //conecto todos los puertos a una señal del TOP
        .clk    (clk),
        .reset  (reset),
        .start  (w_start_cordic),
        .titha  (w_titha),
        .cos    (w_cos),
        .sen    (w_sen),
        .done   (w_done)
    );

endmodule