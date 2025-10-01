`timescale 1ns / 1ps

`include "Definitions.vh"

module structural_matrix_multiplication
#(
    parameter NBITS = `BIT_WIDTH,
    parameter RESULT_WIDTH = `RESULT_WIDTH
)
(
    input wire signed [NBITS-1:0] A_11, A_12, A_13,
    input wire signed [NBITS-1:0] A_21, A_22, A_23,
    input wire signed [NBITS-1:0] A_31, A_32, A_33,
    input wire signed [NBITS-1:0] B_11, B_21, B_31,
    
    output wire signed [RESULT_WIDTH-1:0] C_11, C_21, C_31
);

    // Intermediate multiplication results
    wire signed [RESULT_WIDTH-1:0] mult_11_11, mult_12_21, mult_13_31;
    wire signed [RESULT_WIDTH-1:0] mult_21_11, mult_22_21, mult_23_31;
    wire signed [RESULT_WIDTH-1:0] mult_31_11, mult_32_21, mult_33_31;
    
    // Intermediate addition results
    wire signed [RESULT_WIDTH-1:0] sum_c11_stage1, sum_c21_stage1, sum_c31_stage1;
    wire overflow_dummy;
    
    // ===== Row 1 Calculations: C_11 = A_11*B_11 + A_12*B_21 + A_13*B_31 =====
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c11_1 (.multiplicand(A_11), .multiplier(B_11), .product(mult_11_11));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c11_2 (.multiplicand(A_12), .multiplier(B_21), .product(mult_12_21));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c11_3 (.multiplicand(A_13), .multiplier(B_31), .product(mult_13_31));
    
    // Add first two products
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c11_stage1 (.a(mult_11_11), .b(mult_12_21), .operation(1'b0), 
                    .result(sum_c11_stage1), .overflow(overflow_dummy));
    
    // Add third product
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c11_stage2 (.a(sum_c11_stage1), .b(mult_13_31), .operation(1'b0), 
                    .result(C_11), .overflow(overflow_dummy));
    
    // ===== Row 2 Calculations: C_21 = A_21*B_11 + A_22*B_21 + A_23*B_31 =====
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c21_1 (.multiplicand(A_21), .multiplier(B_11), .product(mult_21_11));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c21_2 (.multiplicand(A_22), .multiplier(B_21), .product(mult_22_21));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c21_3 (.multiplicand(A_23), .multiplier(B_31), .product(mult_23_31));
    
    // Add first two products
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c21_stage1 (.a(mult_21_11), .b(mult_22_21), .operation(1'b0), 
                    .result(sum_c21_stage1), .overflow(overflow_dummy));
    
    // Add third product
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c21_stage2 (.a(sum_c21_stage1), .b(mult_23_31), .operation(1'b0), 
                    .result(C_21), .overflow(overflow_dummy));
    
    // ===== Row 3 Calculations: C_31 = A_31*B_11 + A_32*B_21 + A_33*B_31 =====
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c31_1 (.multiplicand(A_31), .multiplier(B_11), .product(mult_31_11));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c31_2 (.multiplicand(A_32), .multiplier(B_21), .product(mult_32_21));
    
    signed_multiplier #(.BIT_WIDTH(NBITS), .RESULT_WIDTH(RESULT_WIDTH)) 
    mult_c31_3 (.multiplicand(A_33), .multiplier(B_31), .product(mult_33_31));
    
    // Add first two products
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c31_stage1 (.a(mult_31_11), .b(mult_32_21), .operation(1'b0), 
                    .result(sum_c31_stage1), .overflow(overflow_dummy));
    
    // Add third product
    signed_adder_subtractor #(.BIT_WIDTH(RESULT_WIDTH)) 
    add_c31_stage2 (.a(sum_c31_stage1), .b(mult_33_31), .operation(1'b0), 
                    .result(C_31), .overflow(overflow_dummy));

endmodule