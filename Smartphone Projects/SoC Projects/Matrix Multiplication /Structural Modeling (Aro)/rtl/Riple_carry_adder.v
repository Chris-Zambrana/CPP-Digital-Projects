`timescale 1ns / 1ps

`include "Definitions.vh"

module Riple_carry_adder
#(
    parameter BIT_WIDTH = `BIT_WIDTH,          
    parameter RESULT_WIDTH = `RESULT_WIDTH     
)
(
input [BIT_WIDTH-1:0] a, b1,
input c_in,
output [BIT_WIDTH-1:0] s,
output c_out
);

wire [BIT_WIDTH-2:0] c;
wire [BIT_WIDTH-1:0] b2;


sub_controller 
#(
     .BIT_WIDTH(BIT_WIDTH)
)
sub(
    .b1(b1),
    .c_in(c_in),
    .b2(b2)
);

project_1 FA0 (
.a(a[0]),
.b(b2[0]),
.c_in(0),
.s(s[0]),
.c_out(c[0])
);

project_1 FA1 (
.a(a[1]),
.b(b2[1]),
.c_in(c[0]),
.s(s[1]),
.c_out(c[1])
);

project_1 FA2 (
.a(a[2]),
.b(b2[2]),
.c_in(c[1]),
.s(s[2]),
.c_out(c[2])
);

project_1 FA3 (
.a(a[3]),
.b(b2[3]),
.c_in(c[2]),
.s(s[3]),
.c_out(c_out)
);

endmodule
