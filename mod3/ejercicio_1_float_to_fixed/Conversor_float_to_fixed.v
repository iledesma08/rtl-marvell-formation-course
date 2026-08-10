//Enunciado:
// Realizar un conversor float to fixed y evaluarlo con el número x=9,625
// Lo hago generalizado para el caso de 32 y 64 bits



`timescale 1ns/1ps

module Conversor_float_to_fixed #(parameter Width_NB = 8, Width_NF=3,Width_float=32, width_NBI=Width_NB-Width_NF-1)(
    input logic [Width_float-1:0] numero_float, //defino unicamente la entrada de float
    output logic [Width_NB-1:0] numero_fixed // y la salida de fixed
);

    //DEFINO SEÑALES PARA DESCOMPONER FLOAT
    logic sign_bit;
    logic signed [10:0] exp_64;   // 11 bits, exponente de 64 bits
    logic signed [7:0]  exp_32;   // 8 bits, exponente de 32 bits
    logic [51:0] mantisa_64;      // 52 bits reales
    logic [22:0] mantisa_32;      // 23 bits reales
    logic  [31:0] numero_32; // Para conformar los numeros en formato 32
    logic [63:0] numero_64; // para conformar los numero en formato 64
    
    //DEFINO SEÑALES PARA HACER EL PASO INTERMEDIO
    logic [8:0] entero_32;
    logic [22:0] fraccional_32;
    logic [11:0] entero_64;
    logic [52:0] fraccional_64;

    //DEFINO SEÑALES PARA EL FIXED
    logic [width_NBI-1:0] ni; 
    logic [Width_NF-1:0] nf;
    logic overflow; //PARA SABER SI HAY OVERFLOW O NO



    //COMIENZO DEFINICION DE LA LOGICA

    always_comb begin //Compila pero con problemas con los part select +: y -:
        sign_bit = numero_float >> (Width_float-1); //corro el MSB hasta que quede LSB y asi determino el signo

        if (Width_float === 32) begin
            exp_32 = numero_float[30:23] - 127; // le pido que tome esos bits en lugar de tener que hacer mascara.
            mantisa_32 = numero_float[22:0]; //Obtengo los bits de la mantisa
            if (exp_32 > 0) begin
            numero_32 = {1'b1, mantisa_32} << (exp_32); //Aca estoy conformando un numero de 24 bits donde la coma esta entre el bit 23 y 22
            end else begin
            numero_32 = {1'b1, mantisa_32} >> (-exp_32); // por si el exponente es negativo
            end
            //la coma queda entre el bit 23 y 22 porque lo que yo hago es shiftearlo hacia la izquierda o derecha
             entero_32 = numero_32[31:23];
             fraccional_32 = numero_32[22:0];

            // lo asigno a Fixed
            overflow = |entero_32[8 : width_NBI]; //se fija si desde el bit mas significativo de la parte entera
            //hasta con limite en la cantidad de NBI hay un 1 por tanto indica overflow

            if (overflow) begin
            ni = {width_NBI{1'b1}};
            nf = {Width_NF{1'b1}}; 
            //Si hay overflow saturo
            end else begin
            ni = entero_32[0 +: width_NBI]; //va de 0 para arriba 
            nf = fraccional_32[22   -: Width_NF]; //va de 22 para abajo
            //si no hay overflow coloco bits
            end

            numero_fixed = {sign_bit,ni,nf};

        end else begin
            exp_64 = numero_float[62:52] - 1023; // para el caso de que sea de 64 bits la representación.
            mantisa_64 = numero_float[51:0];  // Obtengo los bits de la mantisa      
            if (exp_64 > 0) begin
            numero_64 = {1'b1, mantisa_64} << (exp_64);
            end else
            numero_64 = {1'b1, mantisa_64} >> (-exp_64);
        
            //la coma queda entre el bit 53 y 52 porque lo que yo hago es shiftearlo hacia la izquierda o derecha
             entero_64 = numero_64[63:52];
             fraccional_64 = numero_64[51:0];

            overflow = |entero_64[11 : width_NBI];

            if (overflow) begin
                ni = {width_NBI{1'b1}};
                nf = {Width_NF{1'b1}};
            end else begin
                ni = entero_64[0 +: width_NBI];
                nf = fraccional_64[51 -: Width_NF];
            end

            numero_fixed = {sign_bit,ni,nf};

        end

        end
 
endmodule