`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/11/2025 05:13:44 PM
// Design Name: 
// Module Name: full_add_testbench
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


module full_add_testbench();

reg [3:0] a, b;
reg c_in;
wire [3:0] s;
wire c_out;

Riple_carry_adder dut(.a(a), .b(b), .c_in(c_in), .s(s), .c_out(c_out));

initial begin
    a=2;
    b=3;
    c_in=1;
    
#10 a=0;
    b=0;
    c_in=0;
    
#10 a=5;
    b=7;
    c_in=0;
#10
    
$finish;
end
endmodule