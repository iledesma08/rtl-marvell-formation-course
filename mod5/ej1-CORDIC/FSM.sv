/*
*
*   Máquina de estados que recibe una señal del usuario "start" y le envia una al cordic
*   Para empezar a iterar, hasta que no recibe start no sale del estado IDLE y cuando lo recibe
*   Comienza inicializa los valores desde el IDLE para no perder un ciclo de inicialización y contar
*   14 ciclos
*   
*   Luego recibe los resultados de coseno y seno y los muestra al recibir una señal done de CORDIC
* 
*/ 

`timescale 1ns/1ps


module FSM (
    input logic clk,
    input logic reset,
    input logic start, //señal que recibe del usuario para iniciar
    input logic done, //señal que recibe del CORDIC para mostrar el resultado
    input logic signed [15:0] titha_in, //el usuario introduce el titha
    input logic signed [15:0]seno_in, //Resultado que le llega del CORDIC
    input logic signed [15:0]coseno_in, //Resultado que le llega del CORDIC
    output logic signed [15:0]coseno_out, //Resultado que muestra afuera
    output logic signed [15:0]seno_out, //Resultado que muestra afuera
    output logic signed [15:0] titha_out,
    output logic start_cordic
);



//defino los estados
typedef enum logic [1:0] {IDLE = 2'b00, ITER = 2'b01, DONE = 2'b10} state_t;
state_t state;
state_t next;

always_ff @( posedge clk or posedge reset  ) begin 

    if (reset) begin
        state <= IDLE;
    end else begin
    
        state <= next;

    end

end
always_comb begin
        next = state; //case default

    case (state)
        IDLE: begin

            coseno_out = 0;
            seno_out = 0;
            titha_out = titha_in;
            start_cordic = start; //lee el valor de input y se lo asigna a una señal interna
            if (start_cordic) begin
                next = ITER;
            end
        end

        ITER: begin
            coseno_out = 0;
            seno_out = 0;

            start_cordic = 0; //baja la señal start
            titha_out = 0;
            if (done) begin
                next=DONE;
            end 
            

        end

        DONE: begin
            start_cordic = 0; //baja la señal start
            titha_out = 0;
            next = IDLE;
            coseno_out = coseno_in;
            seno_out = seno_in;

        end
     
    endcase

end

endmodule