`timescale 1ns / 1ps


module shift_width_calc
(
    input wire       clk,
    input wire       reset, 
    input wire [2:0] mode,
    
    output reg [2:0] shift_width
);
    
    always @(*) begin
        case (mode)
            `MODE_SINGLE: shift_width = 3'd1;
            `MODE_DUAL:   shift_width = 3'd2;
            `MODE_QUAD:   shift_width = 3'd4;
            default:      shift_width = 3'd1;
        endcase
    end
    
endmodule
