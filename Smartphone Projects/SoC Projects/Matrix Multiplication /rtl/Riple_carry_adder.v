`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/10/2025 07:50:17 AM
// Design Name: 
// Module Name: Riple_carry_adder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Riple_carry_adder(
input [3:0] a, b,
input c_in,
output [3:0] s,
output c_out
);
wire [2:0] c;

project_1 FA0 (
.a(a[0]),
.b(b[0]),
.c_in(c_in),
.s(s[0]),
.c_out(c[0])
);

project_1 FA1 (
.a(a[1]),
.b(b[1]),
.c_in(c[0]),
.s(s[1]),
.c_out(c[1])
);

project_1 FA2 (
.a(a[2]),
.b(b[2]),
.c_in(c[1]),
.s(s[2]),
.c_out(c[2])
);
project_1 FA3 (
.a(a[3]),
.b(b[3]),
.c_in(c[2]),
.s(s[3]),
.c_out(c_out)
);
endmodule
