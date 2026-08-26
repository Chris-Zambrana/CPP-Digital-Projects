`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module fifo #(
    parameter FIFO_DEPTH = `QSPI_FIFO_DEPTH,
    parameter FIFO_WIDTH = `QSPI_FIFO_WIDTH
) (
    input  wire clk,
    input  wire reset,

    // register/controller to FIFO signals
    input  wire soft_reset,
    input  wire wr,
    input  wire rd,
    input  wire [FIFO_WIDTH-1:0] wr_data,

    // FIFO to register/controller signals
    output wire [FIFO_WIDTH-1:0] rd_data,
    output wire full,
    output wire empty
);
    
endmodule