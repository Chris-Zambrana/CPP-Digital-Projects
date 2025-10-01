`timescale 1ns / 1ps

`include "Definitions.vh"

module structural_matrix_mult_tb();

    localparam NBITS = `BIT_WIDTH;
    localparam RESULT_WIDTH = `RESULT_WIDTH;
    
    // Input matrices
    reg signed [NBITS-1:0] A_11, A_12, A_13, A_21, A_22, A_23, A_31, A_32, A_33;
    reg signed [NBITS-1:0] B_11, B_21, B_31;
    
    // Output results
    wire signed [RESULT_WIDTH-1:0] C_11, C_21, C_31;
    
    // Expected results (computed by behavioral model)
    reg signed [RESULT_WIDTH-1:0] expected_C_11, expected_C_21, expected_C_31;
    
    // Instantiate the structural matrix multiplier
    structural_matrix_multiplication #(
        .NBITS(NBITS),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) dut (
        .A_11(A_11), .A_12(A_12), .A_13(A_13),
        .A_21(A_21), .A_22(A_22), .A_23(A_23),
        .A_31(A_31), .A_32(A_32), .A_33(A_33),
        .B_11(B_11), .B_21(B_21), .B_31(B_31),
        .C_11(C_11), .C_21(C_21), .C_31(C_31)
    );
    
    // Task to compute expected results
    task compute_expected;
        begin
            expected_C_11 = A_11*B_11 + A_12*B_21 + A_13*B_31;
            expected_C_21 = A_21*B_11 + A_22*B_21 + A_23*B_31;
            expected_C_31 = A_31*B_11 + A_32*B_21 + A_33*B_31;
        end
    endtask
    
    // Task to display results
    task display_results;
        input integer test_num;
        begin
            $display("\n=== Test %0d Results ===", test_num);
            $display("Matrix A:");
            $display("  [%0d, %0d, %0d]", A_11, A_12, A_13);
            $display("  [%0d, %0d, %0d]", A_21, A_22, A_23);
            $display("  [%0d, %0d, %0d]", A_31, A_32, A_33);
            $display("Matrix B:");
            $display("  [%0d]", B_11);
            $display("  [%0d]", B_21);
            $display("  [%0d]", B_31);
            $display("Result C (Actual):");
            $display("  [%0d]", C_11);
            $display("  [%0d]", C_21);
            $display("  [%0d]", C_31);
            $display("Expected C:");
            $display("  [%0d]", expected_C_11);
            $display("  [%0d]", expected_C_21);
            $display("  [%0d]", expected_C_31);
            $display("Match: C_11=%s, C_21=%s, C_31=%s", 
                    (C_11==expected_C_11)?"PASS":"FAIL",
                    (C_21==expected_C_21)?"PASS":"FAIL", 
                    (C_31==expected_C_31)?"PASS":"FAIL");
        end
    endtask
    
    initial begin
        $display("=== Structural Matrix Multiplication Testbench ===");
        
        // Test 1: Simple positive values
        A_11 = 1; A_12 = 2; A_13 = 3;
        A_21 = 4; A_22 = 5; A_23 = 6;
        A_31 = 7; A_32 = 8; A_33 = 9;
        B_11 = 1; B_21 = 0; B_31 = -1;
        compute_expected();
        #200; // Allow time for computation
        display_results(1);
        
        // Test 2: Mixed positive and negative values
        A_11 = -12345; A_12 = 2468; A_13 = -31000;
        A_21 = 15874; A_22 = -8765; A_23 = 9999;
        A_31 = -32768; A_32 = 32767; A_33 = 5432;
        B_11 = -11111; B_21 = 22222; B_31 = -13579;
        compute_expected();
        #200;
        display_results(2);
        
        // Test 3: Large values similar to original testbench
        A_11 = 30500; A_12 = -25000; A_13 = 1234;
        A_21 = -16384; A_22 = 3276; A_23 = 999;
        A_31 = 2048; A_32 = -3072; A_33 = 16383;
        B_11 = 10000; B_21 = -20000; B_31 = 30000;
        compute_expected();
        #200;
        display_results(3);
        
        // Test 4: Edge cases with zeros
        A_11 = 0; A_12 = 1000; A_13 = -2000;
        A_21 = 5000; A_22 = 0; A_23 = -3000;
        A_31 = -1000; A_32 = 4000; A_33 = 0;
        B_11 = 100; B_21 = -200; B_31 = 300;
        compute_expected();
        #200;
        display_results(4);
        
        // Test 5: Identity-like multiplication
        A_11 = 1000; A_12 = 0; A_13 = 0;
        A_21 = 0; A_22 = 1000; A_23 = 0;
        A_31 = 0; A_32 = 0; A_33 = 1000;
        B_11 = 500; B_21 = -750; B_31 = 250;
        compute_expected();
        #200;
        display_results(5);
        
        // Test 6: Maximum negative values
        A_11 = -32768; A_12 = -32768; A_13 = -32768;
        A_21 = 32767; A_22 = 32767; A_23 = 32767;
        A_31 = -1; A_32 = 1; A_33 = -1;
        B_11 = 1; B_21 = -1; B_31 = 1;
        compute_expected();
        #200;
        display_results(6);
        
        $display("\n=== Matrix Multiplication Test Complete ===");
        $finish;
    end

endmodule