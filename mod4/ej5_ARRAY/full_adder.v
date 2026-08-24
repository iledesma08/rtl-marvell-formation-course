`timescale 1ns/1ps


module full_adder (
 input logic a,
 input logic b,
 input logic cin,
 output logic S , cout
);


always_comb begin 
    
    S = a ^ b ^ cin;
    cout = (a&b) | (cin &(a^b)); //^ es XOR
end
    
endmodule