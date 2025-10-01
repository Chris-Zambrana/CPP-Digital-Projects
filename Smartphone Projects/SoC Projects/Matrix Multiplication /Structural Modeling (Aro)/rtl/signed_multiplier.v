`timescale 1ns / 1ps

`include "Definitions.vh"

module signed_multiplier
#(
    parameter BIT_WIDTH = `BIT_WIDTH,
    parameter RESULT_WIDTH = `RESULT_WIDTH
)
(
    input signed [BIT_WIDTH-1:0] multiplicand,
    input signed [BIT_WIDTH-1:0] multiplier,
    output signed [RESULT_WIDTH-1:0] product
);

    // Internal signals
    wire [BIT_WIDTH-1:0] abs_multiplicand, abs_multiplier;
    wire [RESULT_WIDTH-1:0] abs_product;
    wire sign_multiplicand, sign_multiplier, sign_result;
    
    // Extract signs
    assign sign_multiplicand = multiplicand[BIT_WIDTH-1];
    assign sign_multiplier = multiplier[BIT_WIDTH-1];
    assign sign_result = sign_multiplicand ^ sign_multiplier;
    
    // Get absolute values
    assign abs_multiplicand = sign_multiplicand ? -multiplicand : multiplicand;
    assign abs_multiplier = sign_multiplier ? -multiplier : multiplier;
    
    // Instantiate unsigned multiplier
    unsigned_multiplier #(
        .BIT_WIDTH(BIT_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) umult (
        .multiplicand(abs_multiplicand),
        .multiplier(abs_multiplier),
        .product(abs_product)
    );
    
    // Apply sign to result
    assign product = sign_result ? -abs_product : abs_product;

endmodule

// Unsigned multiplier using shift-and-add algorithm
module unsigned_multiplier
#(
    parameter BIT_WIDTH = `BIT_WIDTH,
    parameter RESULT_WIDTH = `RESULT_WIDTH
)
(
    input [BIT_WIDTH-1:0] multiplicand,
    input [BIT_WIDTH-1:0] multiplier,
    output [RESULT_WIDTH-1:0] product
);

    // Partial products for each bit of multiplier
    wire [RESULT_WIDTH-1:0] partial_products [BIT_WIDTH-1:0];
    wire [RESULT_WIDTH-1:0] sum_stages [BIT_WIDTH-1:0];
    
    genvar i;
    generate
        for (i = 0; i < BIT_WIDTH; i = i + 1) begin : PARTIAL_PRODUCT_GEN
            // Generate partial product for bit i
            assign partial_products[i] = multiplier[i] ? (multiplicand << i) : 0;
        end
    endgenerate
    
    // First stage
    assign sum_stages[0] = partial_products[0];
    
    // Add all partial products using ripple carry adders
    generate
        for (i = 1; i < BIT_WIDTH; i = i + 1) begin : SUM_STAGES
            wire overflow_dummy;
            
            ripple_carry_32bit adder_stage (
                .a(sum_stages[i-1]),
                .b(partial_products[i]),
                .operation(1'b0), // Addition
                .sum(sum_stages[i]),
                .c_out(),
                .overflow(overflow_dummy)
            );
        end
    endgenerate
    
    assign product = sum_stages[BIT_WIDTH-1];

endmodule

// 32-bit ripple carry adder for multiplication
module ripple_carry_32bit
(
    input [31:0] a,
    input [31:0] b,
    input operation,
    output [31:0] sum,
    output c_out,
    output overflow
);

    wire [31:0] b_processed;
    wire [31:0] carry;
    
    // Process b for subtraction
    assign b_processed = operation ? ~b : b;
    
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : FA_ARRAY_32
            if (i == 0) begin
                full_adder_1bit FA (
                    .a(a[i]),
                    .b(b_processed[i]),
                    .c_in(operation),
                    .sum(sum[i]),
                    .c_out(carry[i])
                );
            end else begin
                full_adder_1bit FA (
                    .a(a[i]),
                    .b(b_processed[i]),
                    .c_in(carry[i-1]),
                    .sum(sum[i]),
                    .c_out(carry[i])
                );
            end
        end
    endgenerate
    
    assign c_out = carry[31];
    assign overflow = ((a[31] == b_processed[31]) && (sum[31] != a[31]));

endmodule

// Basic 1-bit full adder
module full_adder_1bit
(
    input a,
    input b,
    input c_in,
    output sum,
    output c_out
);
    
    assign sum = a ^ b ^ c_in;
    assign c_out = (a & b) | (c_in & (a ^ b));

endmodule