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
import qspi_types_pkg::*;

`include "qspi_definitions.vh"

module top_qspi_core #(
        parameter QSPI_CSR_DEPTH = `QSPI_CSR_DEPTH, 
        parameter QSPI_CSR_WIDTH = `QSPI_CSR_WIDTH,

        parameter QSPI_DIVIDER_WIDTH = `QSPI_DIVIDER_WIDTH,
        parameter QSPI_MAX_ADDR_WIDTH = `QSPI_MAX_ADDR_WIDTH,
        parameter QSPI_DATA_LEN_WIDTH = `QSPI_DATA_LEN_WIDTH,
        parameter QSPI_DUMMY_COUNT_WIDTH = `QSPI_DUMMY_COUNT_WIDTH,
        parameter QSPI_MODE_WIDTH = `QSPI_MODE_WIDTH,
        parameter QSPI_DATA_WIDTH = `QSPI_DATA_WIDTH,
        parameter QSPI_SLAVE_COUNT = `QSPI_SLAVE_COUNT,
        parameter QSPI_CS_SEL_WIDTH = (QSPI_SLAVE_COUNT > 1) ? $clog2(QSPI_SLAVE_COUNT) : 1,

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
        input  logic [4:0]  addr,
        input  logic [31:0] wr_data,
        output logic [31:0] rd_data,

        // qspi external interface
        output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,
        inout  tri  [3:0]  qspi_io
    );

    logic fifo_tx_full, fifo_tx_empty, fifo_rx_full, fifo_rx_empty;
    logic fifo_tx_wr, fifo_tx_rd, fifo_rx_wr, fifo_rx_rd;
    logic [QSPI_DATA_WIDTH-1:0] fifo_tx_wbyte, fifo_tx_rbyte, fifo_rx_wbyte, fifo_rx_rbyte;

    logic ready, start, cpol, cpha, lsb_first, ddr_en;
    logic has_opcode, has_addr, has_mode, has_dummy, has_tx_data, has_rx_data;

    logic [QSPI_DIVIDER_WIDTH-1:0] clk_div;
    logic [7:0] opcode;
    logic [2:0] cmd_io_width, addr_io_width, mode_io_width, data_io_width;
    logic [1:0] addr_bit_width;
    logic [QSPI_MAX_ADDR_WIDTH-1:0] flash_addr;
    logic [QSPI_DATA_LEN_WIDTH-1:0] tx_len, rx_len;
    logic [QSPI_DUMMY_COUNT_WIDTH-1:0] dummy_cycles;
    logic [QSPI_MODE_WIDTH-1:0] mode_bits;
    logic [QSPI_CS_SEL_WIDTH-1:0] cs_num;

    logic shift_tx_byte_done, shift_rx_byte_ready, shift_rx_en, shift_tx_load;
    logic io_force_release;
    logic [QSPI_DATA_WIDTH-1:0] shift_tx_byte, shift_rx_byte;
    state_type phase;
    logic [2:0] bus_width, io_ctrl_width;

    logic drive_tick, sample_tick, edge_tick;
    logic qspi_sclk, sclk_en, sclk_idle;
    logic eos;

    logic [3:0] io_tx, io_rx;
    rate_type rate;
    

    qspi_csr_map #( 
        .QSPI_CSR_DEPTH (QSPI_CSR_DEPTH),
        .QSPI_DIVIDER_WIDTH (QSPI_DIVIDER_WIDTH),
        .QSPI_MAX_ADDR_WIDTH (QSPI_MAX_ADDR_WIDTH),
        .QSPI_DATA_LEN_WIDTH (QSPI_DATA_LEN_WIDTH),
        .QSPI_DUMMY_COUNT_WIDTH (QSPI_DUMMY_COUNT_WIDTH),
        .QSPI_MODE_WIDTH (QSPI_MODE_WIDTH),
        .QSPI_SLAVE_COUNT (QSPI_SLAVE_COUNT),
        .QSPI_CSR_WIDTH (QSPI_CSR_WIDTH),
        .QSPI_DATA_WIDTH (QSPI_DATA_WIDTH)
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
        .fifo_tx_full (fifo_tx_full),
        .fifo_rx_empty (fifo_rx_empty),
        .fifo_rx_rbyte (fifo_rx_rbyte),

        // register to controller signals
        .start (start),
        .cpol (cpol),
        .cpha (cpha),
        .lsb_first (lsb_first),
        .ddr_en (ddr_en),
        .clk_div (clk_div),
        .has_opcode (has_opcode),
        .has_addr (has_addr),
        .has_mode (has_mode),
        .has_dummy (has_dummy),
        .has_tx_data (has_tx_data),
        .has_rx_data (has_rx_data),
        .cmd_io_width (cmd_io_width),
        .addr_io_width (addr_io_width),
        .mode_io_width (mode_io_width),
        .data_io_width (data_io_width),
        .addr_bit_width (addr_bit_width),
        .opcode (opcode),
        .mode_bits (mode_bits),
        .dummy_cycles (dummy_cycles),
        .flash_addr (flash_addr),
        .tx_len (tx_len),
        .rx_len (rx_len),
        .cs_num (cs_num),

        // register to FIFO signals
        .fifo_tx_wr (fifo_tx_wr),
        .fifo_tx_wbyte (fifo_tx_wbyte),
        .fifo_rx_rd (fifo_rx_rd)
    );

    qspi_controller
    #(
        .QSPI_MAX_ADDR_WIDTH (QSPI_MAX_ADDR_WIDTH),
        .QSPI_SLAVE_COUNT (QSPI_SLAVE_COUNT),
        .QSPI_DATA_LEN_WIDTH (QSPI_DATA_LEN_WIDTH),
        .QSPI_DUMMY_COUNT_WIDTH (QSPI_DUMMY_COUNT_WIDTH),
        .QSPI_MODE_WIDTH (QSPI_MODE_WIDTH),
        .QSPI_DATA_WIDTH (QSPI_DATA_WIDTH)
    )
    master_controller (
        .clk (clk),
        .reset (reset),
        .start (start),
        .ddr_en (ddr_en),
        .has_opcode (has_opcode),
        .has_addr (has_addr),
        .has_mode (has_mode),
        .has_dummy (has_dummy),
        .has_tx_data (has_tx_data),
        .has_rx_data (has_rx_data),
        .cmd_io_width (cmd_io_width),
        .addr_io_width (addr_io_width),
        .mode_io_width (mode_io_width),
        .data_io_width (data_io_width),
        .addr_bit_width (addr_bit_width),
        .opcode (opcode),
        .mode_bits (mode_bits),
        .dummy_cycles (dummy_cycles),
        .flash_addr (flash_addr),
        .tx_len (tx_len),
        .rx_len (rx_len),
        .cs_num (cs_num),
        .shift_tx_byte_done (shift_tx_byte_done),
        .shift_rx_byte_ready (shift_rx_byte_ready),
        .shift_rx_byte (shift_rx_byte),
        .fifo_tx_empty (fifo_tx_empty),
        .fifo_tx_rbyte (fifo_tx_rbyte),
        .fifo_rx_full (fifo_rx_full),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick),
        .sclk_idle (sclk_idle),
        .ready (ready),
        .qspi_cs (qspi_cs),
        .sclk_en (sclk_en),
        .phase (phase),
        .bus_width (bus_width),
        .io_ctrl_width (io_ctrl_width),
        .io_force_release (io_force_release),
        .shift_tx_load (shift_tx_load),
        .shift_tx_byte (shift_tx_byte),
        .shift_rx_en (shift_rx_en),
        .rate (rate),
        .fifo_tx_rd (fifo_tx_rd),
        .fifo_rx_wr (fifo_rx_wr),
        .fifo_rx_wbyte (fifo_rx_wbyte)
    );
    
    qspi_shift_reg #(.QSPI_DATA_WIDTH (QSPI_DATA_WIDTH)) shift_reg (
        .clk (clk),
        .reset (reset),
        .lsb_first (lsb_first),
        .bus_width (bus_width),
        .shift_tx_load (shift_tx_load),
        .shift_tx_byte (shift_tx_byte),
        .shift_rx_en (shift_rx_en),
        .rate (rate),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick),
        .edge_tick (edge_tick),
        .io_rx (io_rx),
        .shift_tx_byte_done (shift_tx_byte_done),
        .shift_rx_byte_ready (shift_rx_byte_ready),
        .shift_rx_byte (shift_rx_byte),
        .io_tx (io_tx)
    );

    qspi_sclk_gen 
    #(
        .QSPI_DIVIDER_WIDTH (QSPI_DIVIDER_WIDTH)
    )
    clk_gen (
        .clk (clk),
        .reset (reset),
        .clk_div (clk_div),
        .cpol (cpol),
        .cpha (cpha),
        .sclk_en (sclk_en),
        .eos (eos),
        .qspi_sclk (qspi_sclk),
        .drive_tick (drive_tick),
        .sample_tick (sample_tick),
        .edge_tick (edge_tick),
        .sclk_idle (sclk_idle)
    );
    
    qspi_io_ctrl io_ctrl (
        .phase (phase),
        .bus_width (io_ctrl_width),
        .force_release (io_force_release),
        .io_tx (io_tx),
        .io_rx (io_rx),
        .qspi_io (qspi_io)
    );
    
    top_fwft_fifo 
    #(
        .FIFO_DEPTH (QSPI_FIFO_DEPTH ),
        .FIFO_WIDTH (QSPI_FIFO_WIDTH )
    )
    tx_fifo(
        .clk        (clk        ),
        .reset      (reset      ),
        .wr         (fifo_tx_wr         ),
        .rd         (fifo_tx_rd         ),
        .wr_data    (fifo_tx_wbyte    ),
        .rd_data    (fifo_tx_rbyte    ),
        .full       (fifo_tx_full       ),
        .empty      (fifo_tx_empty      )
    );
    
    top_fwft_fifo 
    #(
        .FIFO_DEPTH (QSPI_FIFO_DEPTH ),
        .FIFO_WIDTH (QSPI_FIFO_WIDTH )
    )
    rx_fifo(
        .clk        (clk        ),
        .reset      (reset      ),
        .wr         (fifo_rx_wr         ),
        .rd         (fifo_rx_rd         ),
        .wr_data    (fifo_rx_wbyte    ),
        .rd_data    (fifo_rx_rbyte    ),
        .full       (fifo_rx_full       ),
        .empty      (fifo_rx_empty      )
    );
    
    qspi_startupe2_sclk sclk_setup (
        .qspi_sclk (qspi_sclk),
        .eos (eos)
    );

endmodule


