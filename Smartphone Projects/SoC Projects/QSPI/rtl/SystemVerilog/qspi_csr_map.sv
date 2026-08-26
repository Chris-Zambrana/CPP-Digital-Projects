`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/23/2026 10:03:58 PM
// Design Name: 
// Module Name: qspi_csr_map
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
`include "qspi_definitions.vh"

module qspi_csr_map
#(
    parameter CSR_DEPTH = `CSR_DEPTH,
    parameter DIVIDER_BITS = `DIVIDER_BITS,
    parameter MAX_ADDR_BITS = `MAX_ADDR_BITS,
    parameter CONST_DATA_LEN = `CONST_DATA_LEN,
    parameter DUMMY_COUNT = `DUMMY_COUNT,
    parameter MODE_CYCLE_COUNT = `MODE_CYCLE_COUNT,
    parameter MODE_BITS = `MODE_BITS,
    parameter QSPI_SLAVE_COUNT = 4,
    parameter CSR_WIDTH = `CSR_WIDTH,
    parameter DATA_BITS = `DATA_BITS
)
(
    input  logic        clk,
    input  logic        reset,

    // slot interface
    input  logic        cs,
    input  logic        read,
    input  logic        write,
    input  logic [$clog2(CSR_DEPTH)-1:0]  addr,
    input  logic [CSR_WIDTH-1:0] wr_data,
    output logic [CSR_WIDTH-1:0] rd_data,

    // controller to register signals
    input logic ready,
    input logic done,
    input logic error,
    input logic fifo_tx_full,
    input logic fifo_rx_empty,
    input logic [DATA_BITS-1:0] fifo_rx_rbyte,

    // register to controller signals
    output logic start,
    output logic soft_reset,
    output logic cpol,
    output logic cpha,
    output logic lsb_first,
    output logic [DIVIDER_BITS-1:0] clk_div,
    output logic [7:0] opcode,
    output logic has_addr,
    output logic has_mode,
    output logic has_dummy,
    output logic has_tx_data,
    output logic has_rx_data,
    output logic [2:0] addr_bit_width,
    output logic [2:0] cmd_io_width,
    output logic [2:0] addr_io_width,
    output logic [2:0] mode_io_width,
    output logic [2:0] data_io_width,
    output logic [MAX_ADDR_BITS-1:0] flash_addr,
    output logic [CONST_DATA_LEN-1:0] tx_len,
    output logic [CONST_DATA_LEN-1:0] rx_len,
    output logic [DUMMY_COUNT-1:0] dummy_cycles,
    output logic [MODE_CYCLE_COUNT-1:0] mode_cycles,
    output logic [MODE_BITS-1:0] mode_bits,
    output logic [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num,
    output logic fifo_tx_wr,
    output logic [DATA_BITS-1:0] fifo_tx_wbyte,
    output logic fifo_rx_rd
);

localparam [$clog2(CSR_DEPTH)-1:0] 
    PULSE_REG = 0,
    CONTROL_REG = 1,
    STATUS_REG = 2,
    DIVIDER_REG = 3,
    CMD_REG = 4,
    FADDR_REG = 5,
    TX_LEN_REG = 6,
    RX_LEN_REG = 7,
    DUMMY_REG = 8,
    TX_DATA_REG = 9,
    RX_DATA_REG = 10,
    CS_REG = 11;

logic [CSR_WIDTH-1:0] csr_2d_array [0:CSR_DEPTH-1];
logic wr_pulse_en, wr_control_en, wr_divider_en, wr_cmd_en, wr_faddr_en, wr_tx_len_en, wr_rx_len_en, 
        wr_dummy_en, wr_cs_en, rd_status_en;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset all CSR registers to 0
        for (int i = 0; i < CSR_DEPTH; i++) begin
            csr_2d_array[i] <= '0;
        end
    end else begin
        if (wr_control_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_divider_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_cmd_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_faddr_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_tx_len_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_rx_len_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_dummy_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_cs_en) begin
            csr_2d_array[addr] <= wr_data;
        end
    end
end
assign wr_pulse_en = cs && write && (addr == PULSE_REG);
assign wr_control_en = cs && write && (addr == CONTROL_REG);
assign wr_divider_en = cs && write && (addr == DIVIDER_REG);
assign wr_cmd_en = cs && write && (addr == CMD_REG);
assign wr_faddr_en = cs && write && (addr == FADDR_REG);
assign wr_tx_len_en = cs && write && (addr == TX_LEN_REG);
assign wr_rx_len_en = cs && write && (addr == RX_LEN_REG);
assign wr_dummy_en = cs && write && (addr == DUMMY_REG);
assign wr_cs_en = cs && write && (addr == CS_REG);

assign start = wr_pulse_en && wr_data[0] && !wr_data[1] && ready;
assign soft_reset = wr_pulse_en && wr_data[1];
assign cpol = csr_2d_array[CONTROL_REG][0];
assign cpha = csr_2d_array[CONTROL_REG][1];
assign lsb_first = csr_2d_array[CONTROL_REG][2];
assign clk_div = csr_2d_array[DIVIDER_REG][DIVIDER_BITS-1:0];
assign opcode = csr_2d_array[CMD_REG][7:0];
assign has_addr = csr_2d_array[CMD_REG][8];
assign has_mode = csr_2d_array[CMD_REG][9];
assign has_dummy = csr_2d_array[CMD_REG][10];
assign has_tx_data = csr_2d_array[CMD_REG][11];
assign has_rx_data = csr_2d_array[CMD_REG][12];
assign addr_bit_width = csr_2d_array[CMD_REG][15:13];
assign cmd_io_width = csr_2d_array[CMD_REG][18:16];
assign addr_io_width = csr_2d_array[CMD_REG][21:19];
assign mode_io_width = csr_2d_array[CMD_REG][24:22];
assign data_io_width = csr_2d_array[CMD_REG][27:25];
assign flash_addr = csr_2d_array[FADDR_REG][MAX_ADDR_BITS-1:0];
assign tx_len = csr_2d_array[TX_LEN_REG][CONST_DATA_LEN-1:0];
assign rx_len = csr_2d_array[RX_LEN_REG][CONST_DATA_LEN-1:0];
assign dummy_cycles = csr_2d_array[DUMMY_REG][DUMMY_COUNT-1:0];
assign mode_cycles = csr_2d_array[DUMMY_REG][MODE_CYCLE_COUNT+DUMMY_COUNT-1:DUMMY_COUNT];
assign mode_bits = csr_2d_array[DUMMY_REG][MODE_BITS+MODE_CYCLE_COUNT+DUMMY_COUNT-1:MODE_CYCLE_COUNT+DUMMY_COUNT];
assign cs_num = csr_2d_array[CS_REG][$clog2(QSPI_SLAVE_COUNT)-1:0];

assign fifo_tx_wr = cs && write && (addr == TX_DATA_REG) && !fifo_tx_full;
assign fifo_tx_wbyte = wr_data[DATA_BITS-1:0];

assign rd_status_en = cs && read && (addr == STATUS_REG);
assign fifo_rx_rd = cs && read && (addr == RX_DATA_REG) && !fifo_rx_empty;
assign rd_data = (fifo_rx_rd) ? {{(CSR_WIDTH-DATA_BITS){1'b0}}, fifo_rx_rbyte} : (rd_status_en) ? {'0, fifo_rx_empty, fifo_tx_full, error, done, ready} : '0;

endmodule
