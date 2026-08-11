// Enunciado: Aplicar booth radix-2
// Primero realizar la conversión de complemento a 2 
// Aplicar el algoritmo
// Verificar


// Queda analizar caso de overflow

// Módulo funcional para hacer el algoritmo de Booth_radix-2 
// Requiere de colocar bien los anchos.

`timescale 1ns/1ps


module booth_radix_2 #(
    parameter  width_A = 4,
    width_B=4,
    width_P= width_A + width_B //como maximo necesita tomar ese valor
)
(
    input logic signed [width_A-1:0]a,
    input logic signed [width_B-1:0]b,
    output logic signed [width_P-1:0]p
);

//defino señales para la logica

logic signed [width_A:0] a_signado; //Para calcular su C2 por si es necesario para el algoritmo
logic signed [width_B:0] b_signado; //Para calcular su C2 por si es necesario. Sin -1 en ambas para manejar el caso extremo
logic signed [width_A:0] b_radix_2; // es par agregarle el cero adelante
logic [1:0]alg; // Es para almacenar el recorrido de B y hacer el case.
logic signed [width_P-1:0] acum; //para hacer la acumulación de p.

//defino parametros para el for
int i;


always_comb  begin 
    b_radix_2 = {b,1'b0}; //concatenado el cero adelante 
    a_signado = (~a);
    a_signado = a_signado + 1; //hago el complemento a 2, lo hago asi para manejar el caso extremo
    b_signado = (~b) + 1; //hago el complemento a 2
    acum = '0;
    
    for (i = 1; i <= width_B; i = i + 1) begin       
        alg = b_radix_2[i -: 2];
        case (alg)
            
            //en el caso que sea 00
            2'b01: begin
                acum=acum + (a<<(i-1)) ;
            end


             2'b10: begin
                acum=acum + (a_signado<<(i-1)) ;
            end
            
            default:
            acum = acum; 
        endcase
    end

     p = acum;
    
end

endmodule