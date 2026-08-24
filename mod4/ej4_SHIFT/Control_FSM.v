`timescale 1ns/1ps


module Control_FSM (
    input logic clock,
    input logic Reset,
    input logic iniciar_mul,
    output logic start, //Bandera de inicio
    output logic shift_en, //Bandera que se prende con el acumulador
    output logic end_cy //Bandera que se prende al final
);


//defno en
logic en=0;
logic [3:0]q=0;
logic q_reset=0;

//defino un tipo de dato enumerado para los estados
// typedef enum logic [1:0] {IDLE, COMPUTE,DONE} state_t; SALTA ERROR EN YOSYS
//defino dos variables de ese estado
//state_t state, next; //estado actual o el siguiente LO MISMO

localparam [1:0] IDLE=2'b00, COMPUTE=2'b01, DONE=2'b10;

logic [1:0] state, next;

// Registro de estado
     
//always 1
always_ff @(posedge clock or posedge Reset) begin
    if (Reset) begin

        state <= IDLE; //en el caso del reset va a 00
    end else
        state <= next; //si hay un clk se cambia al siguiente estado
    
    if(q_reset) begin
        q <= 0;

    end else if (en) begin
        q <= q+1;
    end //HAGO EL CONTADOR MAS ROBUSTO

end

always_comb begin 

    next = state; //se carga como estado default
    start    = 0;
    shift_en = 0;
    end_cy   = 0;
    en       = 0;
    q_reset = 0;
    //Los anteriores para no inferir LATCH
    unique case ( state ) //defino que sucede en cada estado
        IDLE: begin if (iniciar_mul) begin
            next = COMPUTE;
            q_reset = 1;
        end
        end

        COMPUTE: begin 
           en = 1;
           if (q == 0) begin
           start = 1;
         end else begin
           shift_en = 1;
            if (q == 8)
            next = DONE;  // el ultimo shift y la transicion pasan en el MISMO ciclo ESTO ES PARA NO DESPERDICIAR UN CICLO
            end
        end
        DONE: begin 
              next = IDLE;
              end_cy = 1; 
        end
             
    endcase



    
end


endmodule