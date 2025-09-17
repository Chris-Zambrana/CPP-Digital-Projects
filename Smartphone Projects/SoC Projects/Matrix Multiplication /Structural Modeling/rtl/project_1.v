`timescale 1ns / 1ps

`include "Definitions.vh"


module project_1(
    input a , b, c_in,
    output s , c_out
    );
    wire cl,s1,s2;
   Half_adder HA0 (
   .a(a),
   .b(b),
   .c(c1),
   .s(s1)
   );
   
   Half_adder HA1 (
   
   .a(c_in),
   .b(s1),
   .c(c2),
   .s(s)
   );
   
   assign c_out = c1 | c2;

endmodule

   
