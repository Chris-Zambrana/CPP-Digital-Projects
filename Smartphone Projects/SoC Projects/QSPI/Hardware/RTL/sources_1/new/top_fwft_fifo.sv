`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module top_fwft_fifo
    #(
        parameter FIFO_DEPTH = `QSPI_FIFO_DEPTH,
        parameter FIFO_WIDTH = `QSPI_FIFO_WIDTH
    )
    (
        input   logic clk,
        input   logic reset,
 
        input   logic wr,
        input   logic rd,
        input   logic [FIFO_WIDTH-1:0] wr_data,

        output  logic [FIFO_WIDTH-1:0] rd_data,
        output  logic full,
        output  logic empty
    );

    logic wr_en;
    logic [$clog2(FIFO_DEPTH)-1:0] wr_addr, rd_addr;

    fwft_fifo_ctrl 
    #(
        .FIFO_DEPTH (FIFO_DEPTH )
    )
    u_fwft_fifo_ctrl(
        .clk        (clk        ),
        .reset      (reset      ),
        .wr         (wr         ),
        .rd         (rd         ),
        .rd_addr    (rd_addr    ),
        .wr_addr    (wr_addr    ),
        .full  (full  ),
        .empty (empty )
    );

    fwft_fifo_reg_file 
    #(
        .FIFO_DEPTH (FIFO_DEPTH ),
        .FIFO_WIDTH (FIFO_WIDTH )
    )
    u_fwft_fifo_reg_file(
        .clk     (clk     ),
        .wr_en   (wr_en   ),
        .wr_data (wr_data ),
        .rd_addr (rd_addr ),
        .wr_addr (wr_addr ),
        .rd_data (rd_data )
    );

    assign wr_en = wr && !full; // write enable is asserted when wr is high and FIFO is not full, or when a full write-read event occurs

endmodule
