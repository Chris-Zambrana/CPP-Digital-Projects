`timescale 1ns / 1ps

`include "Definitions.vh"

module signed_adder_subtractor
#(
    parameter BIT_WIDTH = `BIT_WIDTH
)
(
    input signed [BIT_WIDTH-1:0] a,
    input signed [BIT_WIDTH-1:0] b,
    input operation, // 0 for addition, 1 for subtraction
    output signed [BIT_WIDTH-1:0] result,
    output overflow
);

    wire [BIT_WIDTH-1:0] b_complement;
    wire [BIT_WIDTH-1:0] b_processed;
    wire [BIT_WIDTH:0] extended_result; // Extra bit for overflow detection


    // Main functionality:
    
    // Two's complement for subtraction
    assign b_complement = ~b + 1;
    
    // Select between b and its complement based on operation, if its 1 then add, otherwise use b
    assign b_processed = operation ? b_complement : b;
    
    // Perform addition with extended width
    assign extended_result = a + b_processed;
    
    // Result is the lower bits
    assign result = extended_result[BIT_WIDTH-1:0];
    
    // Overflow detection for signed arithmetic
    // Overflow occurs when:
    // 1. Adding two positive numbers gives negative result
    // 2. Adding two negative numbers gives positive result
    // 3. Subtracting negative from positive gives negative
    // 4. Subtracting positive from negative gives positive
    assign overflow = (operation == 0) ? 
                     // Addition overflow
                     ((a[BIT_WIDTH-1] == b[BIT_WIDTH-1]) && (result[BIT_WIDTH-1] != a[BIT_WIDTH-1])) :
                     // Subtraction overflow  
                     ((a[BIT_WIDTH-1] != b[BIT_WIDTH-1]) && (result[BIT_WIDTH-1] != a[BIT_WIDTH-1]));

endmodule

