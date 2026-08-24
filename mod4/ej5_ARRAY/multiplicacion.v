//PARA CREAR EL YOSYS

`timescale 1ns/1ps


module multiplicacion (
    input logic [7:0] A,
    input logic [7:0] B,
    output logic [15:0]P
);
    
assign P = A*B;


endmodule