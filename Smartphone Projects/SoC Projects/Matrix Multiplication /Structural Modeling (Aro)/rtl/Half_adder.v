`timescale 1ns / 1ps

`include "Definitions.vh"


module Half_adder(

input a,b,
output c, s
);
   assign s = b ^ a;
   assign c = a & b;
endmodule
