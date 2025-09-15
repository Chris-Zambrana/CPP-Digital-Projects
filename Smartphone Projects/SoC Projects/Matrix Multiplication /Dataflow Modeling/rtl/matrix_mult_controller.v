`timescale 1ns / 1ps

`default_nettype none
`include "mm_definitions.vh"

module matrix_mult_controller
#(
    parameter NBITS = `FACTOR_WIDTH_DEFAULT,
    parameter RESULT_WIDTH = `PRODUCT_WIDTH_DEFAULT
)
(
    input wire signed [NBITS-1:0] A_11,
    input wire signed [NBITS-1:0] A_12,
    input wire signed [NBITS-1:0] A_13,
    input wire signed [NBITS-1:0] A_21,
    input wire signed [NBITS-1:0] A_22,
    input wire signed [NBITS-1:0] A_23,
    input wire signed [NBITS-1:0] A_31,
    input wire signed [NBITS-1:0] A_32,
    input wire signed [NBITS-1:0] A_33,
    input wire signed [NBITS-1:0] B_11,
    input wire signed [NBITS-1:0] B_21,
    input wire signed [NBITS-1:0] B_31,
    
    output wire signed [RESULT_WIDTH-1:0] C_11, 
    output wire signed [RESULT_WIDTH-1:0] C_21,
    output wire signed [RESULT_WIDTH-1:0] C_31
    );
    
//    wire signed [RESULT_WIDTH-1:0] c_11_val1, c_11_val2, c_11_val3;
//    wire signed [RESULT_WIDTH-1:0] c_21_val1, c_21_val2, c_21_val3;
//    wire signed [RESULT_WIDTH-1:0] c_31_val1, c_31_val2, c_31_val3;
//    wire signed [RESULT_WIDTH-1:0] c_11_sum1, c_21_sum1, c_31_sum1;
    
    assign C_11 = (A_11*B_11)+(A_12*B_21)+(A_13*B_31);
    assign C_21 = (A_21*B_11)+(A_22*B_21)+(A_23*B_31);
    assign C_31 = (A_31*B_11)+(A_32*B_21)+(A_33*B_31);
    
    /* Uncomment the following once you filled in all module parameters and module name. I will mark things that need to be replaced with names of your files with ""
    
    
    "multiplication_module" c_11_mult1(
        ."num 1"(A_11),
        ."num 2"(B_11),
        ."result"(c_11_val1),
    );
    
    "multiplication_module" c_11_mult2(
        ."num 1"(A_12),
        ."num 2"(B_21),
        ."result"(c_11_val2),
    );
    
    "multiplication_module" c_11_mult3(
        ."num 1"(A_13),
        ."num 2"(B_31),
        ."result"(c_11_val3),
    );
    
    "full adder module" c_11_add1(
        ."num 1"(c_11_val1),
        ."num 2"(c_11_val2),
        ."carry_in"(0),
        ."result"(c_11_sum1),
        ."carry_out"(
    );
    
    
    
    
    */
endmodule
