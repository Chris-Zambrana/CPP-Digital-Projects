`timescale 1ns / 1ps

`include "Definitions.vh"

module sub_controller
#(
    parameter BIT_WIDTH = `BIT_WIDTH
)
(
    input [BIT_WIDTH-1:0] b1,
    input c_in,
    output reg [BIT_WIDTH-1:0] b2
);
    
    always@(*) begin
        if (c_in) begin
            b2 = ~b1 + 1;
        end else begin
            b2 = b1;
        end
    end 
    
endmodule
