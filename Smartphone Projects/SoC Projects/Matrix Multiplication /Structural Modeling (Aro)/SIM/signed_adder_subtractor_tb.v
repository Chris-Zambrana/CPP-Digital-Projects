`timescale 1ns / 1ps

`include "Definitions.vh"

module signed_adder_subtractor_tb();

    localparam BIT_WIDTH = `BIT_WIDTH;
    
    reg signed [BIT_WIDTH-1:0] a, b;
    reg operation;
    wire signed [BIT_WIDTH-1:0] result;
    wire overflow;
    
    // Expected results
    reg signed [BIT_WIDTH-1:0] expected;
    
    signed_adder_subtractor #(
        .BIT_WIDTH(BIT_WIDTH)
    ) dut (
        .a(a),
        .b(b),
        .operation(operation),
        .result(result),
        .overflow(overflow)
    );
    
    initial begin
        $display("=== Signed Adder/Subtractor Testbench ===");
        $display("Time   a                b                op  result           expected         overflow  match");
        $display("-----  ----------------  ----------------  --  ----------------  ----------------  --------  -----");
        
        // Test Addition
        operation = 0; // Addition
        
        // Test 1: Positive + Positive
        a = 16'b0001001000110100; b = 16'b0101011001111000; expected = a + b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 2: Positive + Negative
        a = 16'b0001000000000000; b = -16'b0000100000000000; expected = a + b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 3: Negative + Negative
        a = -16'b0001000000000000; b = -16'b0010000000000000; expected = a + b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 4: Overflow case (positive)
        a = 16'b0111111111111111; b = 16'b0000000000000001; expected = a + b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 overflow ? "PASS(OF)" : "FAIL");
        
        // Test Subtraction
        operation = 1; // Subtraction
        
        // Test 5: Positive - Positive
        a = 16'b0101011001111000; b = 16'b0001001000110100; expected = a - b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 6: Positive - Negative
        a = 16'b0001000000000000; b = -16'b0001000000000000; expected = a - b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 7: Negative - Positive
        a = -16'b0001000000000000; b = 16'b0001000000000000; expected = a - b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        // Test 8: Zero cases
        a = 16'b0000000000000000; b = 16'b0001001000110100; expected = a - b;
        #10;
        $display("%5t  %16b  %16b  %2d  %16b  %16b  %1b        %s", 
                 $time, a, b, operation, result, expected, overflow, 
                 (result == expected) ? "PASS" : "FAIL");
        
        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule