`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Chris Zambrana
// 
// Create Date: 05/23/2026 10:04:15 PM
// Design Name: QSPI Master Controller
// Module Name: top_qspi_core
// Project Name: QSPI Core Master Controller
// Target Devices: Spansion S25FL128S on FPGA
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
`include "qspi_definitions.vh"

module top_qspi_core #(
        parameter SYSTEM_DATA_BITS = 32,
        parameter CSR_DEPTH = `CSR_DEPTH, 
        parameter DIVIDER_BITS = `DIVIDER_BITS,
        parameter MAX_ADDR_BITS = `MAX_ADDR_BITS,
        parameter CONST_DATA_LEN = `CONST_DATA_LEN,
        parameter DUMMY_COUNT = `DUMMY_COUNT,
        parameter MODE_CYCLE_COUNT = `MODE_CYCLE_COUNT,
        parameter MODE_BITS = `MODE_BITS,
        parameter QSPI_SLAVE_COUNT = 4,
        parameter CSR_WIDTH = `CSR_WIDTH,
        parameter DATA_BITS = `DATA_BITS,
        parameter QSPI_FIFO_DEPTH = `QSPI_FIFO_DEPTH,
        parameter QSPI_FIFO_WIDTH = `QSPI_FIFO_WIDTH
    )
    (
        input  logic        clk,
        input  logic        reset,

        // slot interface
        input  logic        cs,
        input  logic        read,
        input  logic        write,
        input  logic [$clog2(CSR_DEPTH)-1:0]  addr,
        input  logic [SYSTEM_DATA_BITS-1:0] wr_data,
        output logic [SYSTEM_DATA_BITS-1:0] rd_data,

        // qspi external interface
        output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,
        inout  tri  [3:0]  qspi_io
    );

    logic fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty;
    logic fifo_tx_wr, fifo_tx_rd, fifo_rx_wr, fifo_rx_rd;
    logic [DATA_BITS-1:0] fifo_tx_wbyte, fifo_tx_rbyte, fifo_rx_wbyte, fifo_rx_rbyte;

    logic ready, done, error, start, soft_reset, cpol, cpha, lsb_first;
    logic has_addr, has_mode, has_dummy, has_tx_data, has_rx_data;

    logic [DIVIDER_BITS-1:0] clk_div;
    logic [7:0] opcode;
    logic [2:0] addr_bit_width, cmd_io_width, addr_io_width, mode_io_width, data_io_width;
    logic [MAX_ADDR_BITS-1:0] flash_addr;
    logic [CONST_DATA_LEN-1:0] tx_len, rx_len;
    logic [DUMMY_COUNT-1:0] dummy_cycles;
    logic [MODE_CYCLE_COUNT-1:0] mode_cycles;
    logic [MODE_BITS-1:0] mode_bits;
    logic [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num;

    logic shift_tx_byte_done, shift_rx_byte_ready, shift_rx_en, shift_tx_load;
    logic [DATA_BITS-1:0] shift_tx_byte, shift_rx_byte;
    logic [3:0] phase;
    logic [2:0] current_bus_width;

    logic drive_tick, sample_tick, sclk_en, qspi_sclk;

    logic [3:0] io_tx, io_rx;

    

    qspi_csr_map #( 
        .CSR_DEPTH (CSR_DEPTH),
        .DIVIDER_BITS (DIVIDER_BITS),
        .MAX_ADDR_BITS (MAX_ADDR_BITS),
        .CONST_DATA_LEN (CONST_DATA_LEN),
        .DUMMY_COUNT (DUMMY_COUNT),
        .MODE_CYCLE_COUNT (MODE_CYCLE_COUNT),
        .MODE_BITS (MODE_BITS),
        .QSPI_SLAVE_COUNT (QSPI_SLAVE_COUNT),
        .CSR_WIDTH (CSR_WIDTH),
        .DATA_BITS (DATA_BITS)
    )
    csr_map (
        .clk (clk),
        .reset (reset),

        // slot interface
        .cs (cs),
        .read (read),
        .write (write),
        .addr (addr),
        .wr_data (wr_data),
        .rd_data (rd_data),

        // controller to register signals
        .ready (ready),
        .done (done),
        .error (error),
        .fifo_tx_full (fifo_tx_full),
        .fifo_rx_empty (fifo_rx_empty),
        .fifo_rx_rbyte (fifo_rx_rbyte),

        // register to controller signals
        .start (start),
        .soft_reset (soft_reset),
        .cpol (cpol),
        .cpha (cpha),
        .lsb_first (lsb_first),
        .clk_div (clk_div),
        .opcode (opcode),
        .has_addr (has_addr),
        .has_mode (has_mode),
        .has_dummy (has_dummy),
        .has_tx_data (has_tx_data),
        .has_rx_data (has_rx_data),
        .addr_bit_width (addr_bit_width),
        .cmd_io_width (cmd_io_width),
        .addr_io_width (addr_io_width),
        .mode_io_width (mode_io_width),
        .data_io_width (data_io_width),
        .flash_addr (flash_addr),
        .tx_len (tx_len),
        .rx_len (rx_len),
        .dummy_cycles (dummy_cycles),
        .mode_cycles (mode_cycles),
        .mode_bits (mode_bits),
        .cs_num (cs_num),
        .fifo_tx_wr (fifo_tx_wr),
        .fifo_tx_wbyte (fifo_tx_wbyte),
        .fifo_rx_rd (fifo_rx_rd)
    );

    qspi_controller
    #(
        .MAX_ADDR_BITS (MAX_ADDR_BITS),
        .QSPI_SLAVE_COUNT (QSPI_SLAVE_COUNT),
        .CONST_DATA_LEN (CONST_DATA_LEN),
        .DUMMY_COUNT (DUMMY_COUNT),
        .MODE_CYCLE_COUNT (MODE_CYCLE_COUNT),
        .MODE_BITS (MODE_BITS),
        .DATA_BITS (DATA_BITS)
    )
    master_controller (
        .clk (clk),
        .reset (reset),
        .start (start),
        .soft_reset (soft_reset),
        .opcode (opcode),
        .has_addr (has_addr),
        .has_mode (has_mode),
        .has_dummy (has_dummy),
        .has_tx_data (has_tx_data),
        .has_rx_data (has_rx_data),
        .addr_bit_width (addr_bit_width),
        .cmd_io_width (cmd_io_width),
        .addr_io_width (addr_io_width),
        .mode_io_width (mode_io_width),
        .data_io_width (data_io_width),
        .flash_addr (flash_addr),
        .cs_num (cs_num),
        .tx_len (tx_len),
        .rx_len (rx_len),
        .dummy_cycles (dummy_cycles),
        .mode_cycles (mode_cycles),
        .mode_bits (mode_bits),
        .shift_tx_byte_done (shift_tx_byte_done),
        .shift_rx_byte_ready (shift_rx_byte_ready),
        .shift_rx_byte (shift_rx_byte),
        .fifo_tx_empty (fifo_tx_empty),
        .fifo_tx_rbyte (fifo_tx_rbyte),
        .fifo_rx_full (fifo_rx_full),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick),
        .ready (ready),
        .done (done),
        .error (error),
        .qspi_cs (qspi_cs),
        .sclk_en (sclk_en),
        .phase (phase),
        .current_bus_width (current_bus_width),
        .shift_tx_load (shift_tx_load),
        .shift_tx_byte (shift_tx_byte),
        .shift_rx_en (shift_rx_en),
        .fifo_tx_rd (fifo_tx_rd),
        .fifo_rx_wr (fifo_rx_wr),
        .fifo_rx_wbyte (fifo_rx_wbyte)
    );
    
    qspi_shift_reg #(.DATA_BITS (DATA_BITS)) shift_reg (
        .clk (clk),
        .reset (reset),
        .soft_reset (soft_reset),
        .lsb_first (lsb_first),
        .phase (phase),
        .current_bus_width (current_bus_width),
        .shift_tx_load (shift_tx_load),
        .shift_tx_byte (shift_tx_byte),
        .shift_rx_en (shift_rx_en),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick),
        .io_rx (io_rx),
        .shift_tx_byte_done (shift_tx_byte_done),
        .shift_rx_byte_ready (shift_rx_byte_ready),
        .shift_rx_byte (shift_rx_byte),
        .io_tx (io_tx)
    );

    qspi_sclk_gen 
    #(
        .DIVIDER_BITS (DIVIDER_BITS)
    )
    clk_gen (
        .clk (clk),
        .reset (reset),
        .soft_reset (soft_reset),
        .clk_div (clk_div),
        .cpol (cpol),
        .cpha (cpha),
        .sclk_en (sclk_en),
        .qspi_sclk (qspi_sclk),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick)
    );
    
    qspi_io_ctrl io_ctrl (
        .phase (phase),
        .current_bus_width (current_bus_width),
        .io_tx (io_tx),
        .io_rx (io_rx),
        .qspi_io (qspi_io)
    );
    
    fifo 
    #(
        .FIFO_DEPTH (QSPI_FIFO_DEPTH),
        .FIFO_WIDTH (QSPI_FIFO_WIDTH)
    )
    rx_fifo (
        .clk (clk),
        .reset (reset),
        .soft_reset (soft_reset),
        .wr (fifo_rx_wr),
        .rd (fifo_rx_rd),
        .wr_data (fifo_rx_wbyte),
        .rd_data (fifo_rx_rbyte),
        .full (fifo_rx_full),
        .empty (fifo_rx_empty)
    );
    
    fifo 
    #(
        .FIFO_DEPTH (QSPI_FIFO_DEPTH),
        .FIFO_WIDTH (QSPI_FIFO_WIDTH)
    )
    tx_fifo (
        .clk (clk),
        .reset (reset),
        .soft_reset (soft_reset),
        .wr (fifo_tx_wr),
        .rd (fifo_tx_rd),
        .wr_data (fifo_tx_wbyte),
        .rd_data (fifo_tx_rbyte),
        .full (fifo_tx_full),
        .empty (fifo_tx_empty)
    );
    
    qspi_startupe2_sclk sclk_setup (
        .qspi_sclk (qspi_sclk)
    );

endmodule


