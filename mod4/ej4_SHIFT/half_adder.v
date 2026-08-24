`timescale 1ns/1ps


module half_adder (
 input logic a,
 input logic b,
 output logic S , cout
);


always_comb begin 
    
    S = a ^ b;
    cout = a&b;
end
    
endmodule