`timescale 1ns / 1ps

`include "Definitions"

module Riple_carry_adder
#(
parameter N = 16,
parameter Result_width = 2 * N
)
(
input [N-1 : 0] a,b,
input c_in,
output [N -1 : 0] s,
output c_out
);


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
.c_in(c[1]),
.s(s[1]),
.c_out(c[1])
);
   project_1 FA2 (
.a(a[2]),
.b(b[2]),
.c_in(c[2]),
.s(s[2]),
.c_out(c[2])
);
project_1 FA3 (
.a(a[3]),
.b(b[3]),
.c_in(c[3]),
.s(s[3]),
.c_out(c_out)
);

endmodule
output c_out ); 

assign s = a ^b ^cin; 

wire [N - 1:0] c ; 

xor project_1 FA0 (.a(a[0]),.b(b[0]),.c_in(c_in),.s(s[0]),.c_out(c_out)); project_1 FA1 (.a(a[1]),.b(b[1]),.c_in(c[1]),.s(s[1]),.c_out(c[1])); project_1 FA2 (.a(a[2]),.b(b[2]),.c_in(c[2]),.s(s[2]),.c_out(c[2])); project_1 FA3 (.a(a[3]),.b(b[3]),.c_in(c[3]),.s(s[3]),.c_out(c_out)); 

endmodule 

module add_sub(input [16:0]a, input [16:0]b, input c_in, output [16:0] s, output c_out); wire[15:0]c; 

fulladder FA0(a[0],b[0]^c_in),s[0],c[0]; fulladder FA1(a[1],b[1]^c_in),s[1],c[1]; fulladder FA2(a[2],b[2]^c_in),s[2],c[3]; fulladder FA3(a[3],b[3]^c_in),s[3],c[3]; fulladder FA4(a[4],b[4]^c_in),s[4],c[4]; fulladder FA 

5(a[0],b[0]^c_in),s[0],c[0]; fulladder FA6(a[0],b[0]^c_in),s[0],c[c_out]; 


 module twos_complement (
input [N:0] a_i,
output [N:0] twos_comp
);
assign twos_comp = ~a_i + 1'b1;

wire sub_; 
assign sub = input_a & input_b;
module sub_ (input wire a, b, output wire c);
  wire sub_;
  assign sub_ = a & b;
  assign c = sub_ | a;
endmodule
 
 
 module adder_subtractor(a,b,sel,dout,carry_barrow); 
 input [3:0] a ; 
 input [3:0] b ; 
 input wire sel ; 
 output [3:0] dout ; 
 output carry_barrow; 
  
wire [2:0]s; 
 wire [3:0]l; 
 assign l[0] = b[0] ^ sel; 
 assign l[1] = b[1] ^ sel; 
 assign l[2] = b[2] ^ sel; 
 assign l[3] = b[3] ^ sel; 
 full_adder f1(a[0],l[0],sel,dout[0],s[0]); 
 full_adder f2(a[1],l[1],s[0],dout[1],s[1]); 
 full_adder f3(a[2],l[2],s[1],dout[2],s[2]); 
 full_adder f4(a[3],l[3],s[2],dout[3],carry_barrow); 
 
endmodule 
 
module full_adder ( a ,b ,c ,dout ,carry ); 
 input a ; 
 input b ; 
 input c ; 
 output dout ; 
 output carry ; 
 
 assign dout = a ^ b ^ c;  
assign carry = (a&b) | (b&c) | (c&a); 
endmodule 