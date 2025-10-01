`timescale 1ns / 1ps

`include "Definitions.vh"


module full_add_testbench();

localparam integer BIT_WIDTH = `BIT_WIDTH;     
localparam integer RESULT_WIDTH = `RESULT_WIDTH;

reg [BIT_WIDTH-1:0] a, b1;
reg c_in;
wire [BIT_WIDTH-1:0] s;
wire c_out;

Riple_carry_adder dut(.a(a), .b1(b1), .c_in(c_in), .s(s), .c_out(c_out));

initial begin
    a=2;
    b1=2;
    c_in = 1;
    
#10 a=4;
    b1=1;
    c_in = 1;
    
#10 a=5;
    b1=7;
    c_in = 1;

#10
    
$finish;
end
endmodule