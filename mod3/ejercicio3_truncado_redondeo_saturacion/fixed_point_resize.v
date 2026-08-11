//módulo para manejar los tamaños de formato de punto fijo
// No se esta usando complemento a 2, el bit de signo se trabaja a parte.
// Es un módulo no robusto, es util para la evaluación en ejemplos de la clase.
//FALTA EL .PY

`timescale 1ns/1ps

module fixed_point_resize #(
    parameter width_NB_in = 11, 
    width_NBF_in = 5, 
    width_NBI_in = width_NB_in - width_NBF_in - 1 ,
    width_NB_out = 5,
    width_NBF_out = 3,
    width_NBI_out = width_NB_out - width_NBF_out-1   )
(
    input logic  [width_NB_in-1:0] x,
    input logic [1:0] op,
    output logic [width_NB_out-1:0] y
);

    //defino señales para trabajar logicamente

    logic sign_bit;
    logic last_bit;
    logic overflow;
    logic [width_NBI_out-1:0] NBI_out;
    logic [width_NBF_out-1:0] NBF_out;
    
    //defino parametro internos

    localparam diferencia_redondeo = width_NBF_in - width_NBF_out - 1; //Es para observar el primer bit a descartar, usado en redondeo
    localparam diferencia_saturacion = width_NBI_in - width_NBI_out; //Es para analizar si hay overflow


always_comb begin 

   sign_bit = x >> (width_NB_in - 1); //obtengo bit de signo

case (op)
    

    //defino el caso de truncamiento
    2'b00 : begin
        NBI_out = x[width_NBF_in +: width_NBI_out]; //Me paro luego de la coma y tomo los datos que requiere para rellenar NBI_OUT
        NBF_out = x[width_NBF_in-1 -: width_NBF_out]; //Me paro desde la coma y solo traigo los numeros que necesito    
        y = {sign_bit,NBI_out,NBF_out};
    end

    //defino el caso de redondeo
    2'b01: begin
        last_bit = x[diferencia_redondeo];
        if (last_bit) begin
            NBI_out = x[width_NBF_in +: width_NBI_out];
            NBF_out = x[width_NBF_in-1 -: width_NBF_out];
            y = {sign_bit,NBI_out,NBF_out} + 1;

        end else begin

            //en caso de ser 0 no hay suma 
           NBI_out = x[width_NBF_in +: width_NBI_out];
           NBF_out = x[width_NBF_in-1 -: width_NBF_out];
           y = {sign_bit,NBI_out,NBF_out};
        end
    end

    //defino el caso de saturación 
    2'b10: begin
        overflow = | x[width_NB_in-2 -: diferencia_saturacion]; //Toma los bits descartados y se fija si hay alguno en 1 con la OR
        //Pongo -2 para excluir 
        if (overflow) begin
            NBI_out = {width_NBI_out{1'b1}};
            NBF_out = {width_NBF_out{1'b1}};
        end else begin
           NBI_out = x[width_NBF_in +: width_NBI_out];
           NBF_out = x[width_NBF_in-1 -: width_NBF_out];
        end
        y = {sign_bit,NBI_out,NBF_out}; 
    end
    
    //Caso de Wrap-around
    2'b11: begin
        NBI_out = x[width_NBF_in +: width_NBI_out]; //Me paro luego de la coma y tomo los datos que requiere para rellenar NBI_OUT
        NBF_out = x[width_NBF_in-1 -: width_NBF_out]; //Me paro desde la coma y solo traigo los numeros que necesito    
        y = {sign_bit,NBI_out,NBF_out};

    end
      
endcase 
end
endmodule