`timescale 1ns / 1ps


`include "qspi_definitions.vh"

module fwft_fifo_reg_file
    #(
        parameter FIFO_DEPTH = `QSPI_FIFO_DEPTH,
        parameter FIFO_WIDTH = `QSPI_FIFO_WIDTH
    )
    (
        input logic clk,

        // No reset signal is used for the FIFO memory itself because resetting the pointers is sufficient to indicate that the FIFO is empty. The memory contents do not need to be cleared.

        input logic wr_en,
        input logic [FIFO_WIDTH-1:0] wr_data,

        input logic [$clog2(FIFO_DEPTH)-1:0] rd_addr,
        input logic [$clog2(FIFO_DEPTH)-1:0] wr_addr,

        output logic [FIFO_WIDTH-1:0] rd_data
    );

    logic [FIFO_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

    always_ff @(posedge clk) begin
        if(wr_en) begin
            fifo_mem[wr_addr] <= wr_data;
        end
    end

    assign rd_data = fifo_mem[rd_addr];

endmodule
