`timescale 1ns / 1ps

`include "Definitions.vh"

module signed_multiplier_tb();

    localparam BIT_WIDTH = `BIT_WIDTH;
    localparam RESULT_WIDTH = `RESULT_WIDTH;
    
    reg signed [BIT_WIDTH-1:0] multiplicand, multiplier;
    wire signed [RESULT_WIDTH-1:0] product;
    
    // Expected results
    reg signed [RESULT_WIDTH-1:0] expected;
    
    signed_multiplier #(
        .BIT_WIDTH(BIT_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) dut (
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product)
    );
    
    initial begin
        $display("=== Signed Multiplier Testbench ===");
        $display("Time\tmultiplicand\tmultiplier\tproduct\t\t\texpected\t\tmatch");
        $display("----\t------------\t----------\t-------\t\t\t--------\t\t-----");
        
        // Test 1: Positive * Positive
        multiplicand = 16'h0100; multiplier = 16'h0200; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 2: Positive * Negative
        multiplicand = 16'h0100; multiplier = -16'h0200; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 3: Negative * Positive
        multiplicand = -16'h0100; multiplier = 16'h0200; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 4: Negative * Negative
        multiplicand = -16'h0100; multiplier = -16'h0200; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 5: Small numbers
        multiplicand = 16'd15; multiplier = 16'd25; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 6: One operand zero
        multiplicand = 16'h0000; multiplier = 16'h1234; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 7: Both operands one
        multiplicand = 16'h0001; multiplier = 16'h0001; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 8: Maximum positive values
        multiplicand = 16'h7FFF; multiplier = 16'h0002; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        // Test 9: Matrix multiplication typical values
        multiplicand = -16'd12345; multiplier = 16'd2468; expected = multiplicand * multiplier;
        #100;
        $display("%0t\t%h\t\t%h\t\t%h\t%h\t%s", 
                 $time, multiplicand, multiplier, product, expected, 
                 (product == expected) ? "PASS" : "FAIL");
        
        $display("\n=== Test Complete ===");
        $finish;
    end

endmodule