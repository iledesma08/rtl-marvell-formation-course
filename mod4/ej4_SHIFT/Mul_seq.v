//El ejercicio 4 pide hace un multiplicador con shift - adder para ello
//necesito un adder de 8 bits, un acumulador de 16 bits (suma de los dos tamaños)
//un shifter hacia la derecha.
//ES UNSIGNED

`timescale 1ns/1ps


module Mul_seq #(parameter Width_Op1 = 8, Width_Op2 = 8, Width_Result = Width_Op1 + Width_Op2 ) 
(

    input logic clock,
    input logic Reset,
    input logic start,
    input logic shift_en,
    input logic end_cy,
    input logic [Width_Op1-1:0] A,
    input logic [Width_Op2-1:0] B,
    output logic [Width_Result-1:0] resultado //Este es el resultado final 
);

//Creo la señal acumulador    
logic [Width_Result-1:0] acumulador;

logic [Width_Op1:0] suma_ext; 


always_comb begin //el error es por usar el Width en el selector de bits
    if (acumulador[0]) //si el bit 0 es 1 hago la suma
        suma_ext = {1'b0, acumulador[Width_Result-1:8]} + {1'b0, A}; //Le concateno un bit extra por el carry
    else //sino no la hago
        suma_ext = {1'b0, acumulador[Width_Result-1:8]};
end




always_ff @( posedge clock or posedge Reset ) begin 

    if (Reset) begin
        resultado <= '0; //resultado a 0 
    end else begin
      //No puedo hacer dentro del Always_ff una asignación a lo mismo en diferente sentencia
      //Necesito hacer el shifteo cada clk con una sola linea

      if (start) begin //con el flag start me carga los bits B 
        acumulador <= B;
      end 
      else if (shift_en) begin //Con el flag Shift_en me hace el corrimiento

      acumulador <= {suma_ext,acumulador[7:1]}; //Lo que hago es agarrar los bits menos significativos
      //del acumulador (excepto el 0 que es el que se me iría) y le concateno el resultado de la suma.
      //Tengo que tener en cuenta que la suma es de 9 bits por el carry. 
      end 
       else if(end_cy) begin //con el último ciclo coloco resultado
        resultado <= acumulador;
      end

    end
    
end



endmodule