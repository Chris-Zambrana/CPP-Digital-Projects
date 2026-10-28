`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/11/2026 09:52:10 PM
// Design Name: 
// Module Name: tb_qspi_shift_register
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
import qspi_types_pkg::*;

module tb_qspi_shift_register;

    localparam int DATA_WIDTH = 8;
    localparam time CLK_PERIOD = 10ns;

    logic clk;
    logic reset;
    logic lsb_first;
    logic [2:0] bus_width;
    logic shift_tx_load;
    logic [DATA_WIDTH-1:0] shift_tx_byte;
    logic shift_rx_en;
    rate_type rate;
    logic drive_tick;
    logic sample_tick;
    logic edge_tick;
    logic [3:0] io_rx;

    logic shift_tx_byte_done;
    logic shift_rx_byte_ready;
    logic [DATA_WIDTH-1:0] shift_rx_byte;
    logic [3:0] io_tx;

    qspi_shift_reg #(
        .QSPI_DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk,
        .reset,
        .lsb_first,
        .bus_width,
        .shift_tx_load,
        .shift_tx_byte,
        .shift_rx_en,
        .rate,
        .drive_tick,
        .sample_tick,
        .edge_tick,
        .io_rx,
        .shift_tx_byte_done,
        .shift_rx_byte_ready,
        .shift_rx_byte,
        .io_tx
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic tick(
        input logic drive,
        input logic sample,
        input logic edge_event
    );
        drive_tick = drive;
        sample_tick = sample;
        edge_tick = edge_event;
        @(posedge clk);
        #1;
        drive_tick = 1'b0;
        sample_tick = 1'b0;
        edge_tick = 1'b0;
    endtask

    task automatic reset_dut;
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
    endtask

    task automatic expect_equal(
        input string name,
        input logic [DATA_WIDTH-1:0] actual,
        input logic [DATA_WIDTH-1:0] expected
    );
        if (actual !== expected) begin
            $fatal(1, "%s: expected 0x%0h, got 0x%0h", name, expected, actual);
        end
    endtask

    task automatic expect_bit(
        input string name,
        input logic actual,
        input logic expected
    );
        if (actual !== expected) begin
            $fatal(1, "%s: expected %0b, got %0b", name, expected, actual);
        end
    endtask

    task automatic start_tx(input logic [DATA_WIDTH-1:0] value);
        shift_tx_byte = value;
        shift_tx_load = 1'b1;
        @(posedge clk);
        #1;
        shift_tx_load = 1'b0;
    endtask

    task automatic start_rx;
        shift_rx_en = 1'b1;
        @(posedge clk);
        #1;
        shift_rx_en = 1'b0;
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        lsb_first = 1'b0;
        bus_width = 3'd1;
        shift_tx_load = 1'b0;
        shift_tx_byte = '0;
        shift_rx_en = 1'b0;
        rate = RATE_SDR;
        drive_tick = 1'b0;
        sample_tick = 1'b0;
        edge_tick = 1'b0;
        io_rx = '0;

        // SDR, single-bit, MSB-first transmit. The first drive tick presents
        // the MSB and eight drive/sample pairs complete the byte.
        reset_dut();
        bus_width = 3'd1;
        lsb_first = 1'b0;
        start_tx(8'hA5);
        expect_bit("SDR TX initial io_tx", io_tx[0], 1'b0);
        repeat (8) begin
            tick(1'b1, 1'b0, 1'b0);
            tick(1'b0, 1'b1, 1'b0);
        end
        expect_bit("SDR TX done", shift_tx_byte_done, 1'b1);
        expect_bit("SDR TX io_tx after completion", io_tx[0], 1'b1);
        tick(1'b0, 1'b0, 1'b0);
        expect_bit("SDR TX done pulse clears", shift_tx_byte_done, 1'b0);

        // SDR, quad-bit, LSB-first receive. Each sample contributes four
        // bits, so two samples complete the eight-bit byte.
        reset_dut();
        bus_width = 3'd4;
        lsb_first = 1'b1;
        start_rx();
        io_rx = 4'h1;
        tick(1'b1, 1'b0, 1'b0);
        tick(1'b0, 1'b1, 1'b0);
        io_rx = 4'h2;
        tick(1'b1, 1'b0, 1'b0);
        tick(1'b0, 1'b1, 1'b0);
        expect_bit("SDR RX ready", shift_rx_byte_ready, 1'b1);
        expect_equal("SDR RX data", shift_rx_byte, 8'h21);

        // DDR, single-bit, MSB-first transmit. One edge tick advances one
        // bit and the initial load preloads the first output bit.
        reset_dut();
        bus_width = 3'd1;
        lsb_first = 1'b0;
        rate = RATE_DDR;
        start_tx(8'h3C);
        expect_bit("DDR TX initial io_tx", io_tx[0], 1'b0);
        repeat (8) tick(1'b0, 1'b0, 1'b1);
        expect_bit("DDR TX done", shift_tx_byte_done, 1'b1);

        $display("tb_qspi_shift_register: PASS");
        $finish;
    end

endmodule
