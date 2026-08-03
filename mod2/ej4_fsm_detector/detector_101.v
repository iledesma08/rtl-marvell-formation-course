//El ejercicio 4 pide una maquina de estados de Moore que detecte una secuencia binaria 101
//Que ingresa por una entrada serial X. Cuando se detecta el patron
//la salida Y permanece en 1 durante un ciclo de clk.

`timescale 1ns/1ps

module detector_101 (
    input wire clk,
    input wire reset_n,
    input wire x,
    output reg y
);

//defino un tipo de dato enumerado para los estados
typedef enum logic [1:0] {S_00, S_01,S_10,S_11} state_t;
//defino dos variables de ese estado
state_t state, next;

// Registro de estado
     
//always 1
always_ff @(posedge clk or negedge reset_n)
    if (!reset_n) begin

        state <= S_00; //en el caso del reset va a 00
    end else
        state <= next; //si hay un clk se cambia al siguiente estado


//se define combinacionalmente cual es el siguiente estado - Always 2
always_comb begin

    next = state; //le asigna el estado actual como default

    unique case (state)

        S_00: if (x) next = S_01;

        S_01: if (!x) next = S_10;
                  
        S_10: if (x) next = S_11;
              else    next = S_00;  
                
        S_11: if (x) next =S_01;
              else    next = S_10; //es S_10 porque si le viene un 0 el x anterior era 1.

        endcase
    end

// Salida Moore (sólo del estado) - Always 3
always_comb begin  
    y = (state == S_11); //y=1 solo en el ultimo estado, a este se llega luego de la secuencia 
     
end 
   
endmodule