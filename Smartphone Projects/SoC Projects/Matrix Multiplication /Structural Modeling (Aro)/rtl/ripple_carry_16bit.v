`timescale 1ns / 1ps

`include "Definitions.vh"

module ripple_carry_16bit
#(
    parameter BIT_WIDTH = `BIT_WIDTH
)
(
    input [BIT_WIDTH-1:0] a,
    input [BIT_WIDTH-1:0] b,
    input operation, // 0 for addition, 1 for subtraction
    output [BIT_WIDTH-1:0] sum,
    output c_out,
    output overflow
);

    wire [BIT_WIDTH-1:0] b_processed;
    wire [BIT_WIDTH-1:0] carry;
    
    // Process b for subtraction (two's complement)
    sub_controller 
    #(
        .BIT_WIDTH(BIT_WIDTH)
    )
    sub_ctrl(
        .b1(b),
        .c_in(operation),
        .b2(b_processed)
    );
    
    // Generate 16 full adders
    genvar i;
    generate
        for (i = 0; i < BIT_WIDTH; i = i + 1) begin : FA_ARRAY
            if (i == 0) begin
                // First full adder
                project_1 FA (
                    .a(a[i]),
                    .b(b_processed[i]),
                    .c_in(operation), // For subtraction, start with carry=1
                    .s(sum[i]),
                    .c_out(carry[i])
                );
            end else begin
                // Remaining full adders
                project_1 FA (
                    .a(a[i]),
                    .b(b_processed[i]),
                    .c_in(carry[i-1]),
                    .s(sum[i]),
                    .c_out(carry[i])
                );
            end
        end
    endgenerate
    
    assign c_out = carry[BIT_WIDTH-1];
    
    // Overflow detection for signed arithmetic
    assign overflow = (operation == 0) ? 
                     // Addition: overflow if signs same but result different
                     ((a[BIT_WIDTH-1] == b[BIT_WIDTH-1]) && (sum[BIT_WIDTH-1] != a[BIT_WIDTH-1])) :
                     // Subtraction: overflow if signs different but result same as subtrahend
                     ((a[BIT_WIDTH-1] != b[BIT_WIDTH-1]) && (sum[BIT_WIDTH-1] != a[BIT_WIDTH-1]));

endmodule