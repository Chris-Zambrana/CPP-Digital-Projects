`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module shift_width_calc
(
    input wire       clk,
    input wire       reset, 
    input wire [1:0] mode,
    
    output reg [1:0] shift_width
);
    
    always @(*) begin
        case (mode)
            `MODE_ZERO:   shift_width = 0;
            `MODE_SINGLE: shift_width = 1;
            `MODE_DUAL:   shift_width = 2;
            `MODE_QUAD:   shift_width = 4;
            default:      shift_width = 0;
        endcase
    end
    
endmodule
