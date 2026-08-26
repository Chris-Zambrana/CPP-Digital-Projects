module reg_file #(
    parameter DEPTH = 32,
    parameter WIDTH = 32
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        we,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [WIDTH-1:0] din,
    output logic [WIDTH-1:0] dout
);
    
endmodule