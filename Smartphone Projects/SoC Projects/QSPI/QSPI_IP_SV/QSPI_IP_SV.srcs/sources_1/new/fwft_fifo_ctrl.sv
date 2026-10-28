`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module fwft_fifo_ctrl
    #(
        parameter FIFO_DEPTH = `QSPI_FIFO_DEPTH
    )
    (
        input logic clk,
        input logic reset,

        input logic wr,
        input logic rd,

        output logic [$clog2(FIFO_DEPTH)-1:0] rd_addr,
        output logic [$clog2(FIFO_DEPTH)-1:0] wr_addr,
        output logic full,
        output logic empty
    );

    logic [$clog2(FIFO_DEPTH)-1:0] rd_ptr_reg, wr_ptr_reg, rd_ptr_next, wr_ptr_next, rd_ptr_succ, wr_ptr_succ;
    logic full_reg, empty_reg, full_next, empty_next;

    always_ff @(posedge clk or posedge reset) begin
        if(reset) begin
            rd_ptr_reg <= 0;
            wr_ptr_reg <= 0;
            full_reg <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            rd_ptr_reg <= rd_ptr_next;
            wr_ptr_reg <= wr_ptr_next;
            full_reg <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        wr_ptr_succ = wr_ptr_reg + 1;
        rd_ptr_succ = rd_ptr_reg + 1;
        wr_ptr_next = wr_ptr_reg;
        rd_ptr_next = rd_ptr_reg;
        full_next = full_reg;
        empty_next = empty_reg;

        unique case ({wr, rd})
            2'b01: begin
                if(!empty_reg) begin
                    rd_ptr_next = rd_ptr_succ;
                    full_next = 1'b0;

                    if(rd_ptr_succ == wr_ptr_reg) begin
                        empty_next = 1'b1;
                    end
                end
            end

            2'b10: begin
                if(!full_reg) begin
                    wr_ptr_next = wr_ptr_succ;
                    empty_next = 1'b0;

                    if(wr_ptr_succ == rd_ptr_reg) begin
                        full_next = 1'b1;
                    end
                end
            end

            2'b11: begin
                if(empty_reg) begin
                    wr_ptr_next = wr_ptr_succ;
                    //rd_ptr_next = rd_ptr_reg; // no change to read pointer
                    empty_next = 1'b0;
                    full_next = 1'b0;
                end
                else if(full_reg)
                begin
                    rd_ptr_next = rd_ptr_succ;
                    //wr_ptr_next = wr_ptr_reg; // no change to write pointer
                    full_next = 1'b0;
                    empty_next = 1'b0;
                end
                else
                begin
                    wr_ptr_next = wr_ptr_succ;
                    rd_ptr_next = rd_ptr_succ;
                end 
            end

            default: begin
            end
        endcase

    end


    assign rd_addr = rd_ptr_reg;
    assign wr_addr = wr_ptr_reg;
    assign full = full_reg;
    assign empty = empty_reg;

endmodule

