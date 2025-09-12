`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/10/2025 07:05:24 AM
// Design Name: 
// Module Name: project_1
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

   
