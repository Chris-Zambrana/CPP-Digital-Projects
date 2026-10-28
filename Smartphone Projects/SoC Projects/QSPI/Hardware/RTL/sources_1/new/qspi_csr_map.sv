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
    parameter QSPI_CSR_DEPTH = `QSPI_CSR_DEPTH,
    parameter QSPI_CSR_WIDTH = `QSPI_CSR_WIDTH,
    parameter QSPI_DIVIDER_WIDTH = `QSPI_DIVIDER_WIDTH,
    parameter QSPI_MAX_ADDR_WIDTH = `QSPI_MAX_ADDR_WIDTH,
    parameter QSPI_DATA_LEN_WIDTH = `QSPI_DATA_LEN_WIDTH,
    parameter QSPI_DUMMY_COUNT_WIDTH = `QSPI_DUMMY_COUNT_WIDTH,
    parameter QSPI_MODE_WIDTH = `QSPI_MODE_WIDTH,
    parameter QSPI_DATA_WIDTH = `QSPI_DATA_WIDTH,
    parameter QSPI_SLAVE_COUNT = `QSPI_SLAVE_COUNT,
    parameter QSPI_CS_SEL_WIDTH = (QSPI_SLAVE_COUNT > 1) ? $clog2(QSPI_SLAVE_COUNT) : 1
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

    // controller to register signals
    input logic ready,
    input logic fifo_tx_full,
    input logic fifo_rx_empty,
    input logic [QSPI_DATA_WIDTH-1:0] fifo_rx_rbyte,

    // register to controller signals
    output logic start,
    output logic cpol,
    output logic cpha,
    output logic lsb_first,
    output logic ddr_en,
    output logic [QSPI_DIVIDER_WIDTH-1:0] clk_div,
    output logic has_opcode,
    output logic has_addr,
    output logic has_mode,
    output logic has_dummy,
    output logic has_tx_data,
    output logic has_rx_data,
    output logic [2:0] cmd_io_width,
    output logic [2:0] addr_io_width,
    output logic [2:0] mode_io_width,
    output logic [2:0] data_io_width,
    output logic [1:0] addr_bit_width,
    output logic [7:0] opcode,
    output logic [QSPI_MODE_WIDTH-1:0] mode_bits,
    output logic [QSPI_DUMMY_COUNT_WIDTH-1:0] dummy_cycles,
    output logic [QSPI_MAX_ADDR_WIDTH-1:0] flash_addr,
    output logic [QSPI_DATA_LEN_WIDTH-1:0] tx_len,
    output logic [QSPI_DATA_LEN_WIDTH-1:0] rx_len,
    output logic [QSPI_CS_SEL_WIDTH-1:0] cs_num,

    // register to FIFO signals
    output logic fifo_tx_wr,
    output logic [QSPI_DATA_WIDTH-1:0] fifo_tx_wbyte,
    output logic fifo_rx_rd
);

localparam [$clog2(QSPI_CSR_DEPTH)-1:0] 
    PULSE_REG = 0,
    CONTROL_REG = 1,
    STATUS_REG = 2,
    DIVIDER_REG = 3,
    CMD_CONF_REG = 4,
    CMD_DATA_REG = 5,
    FADDR_REG = 6,
    TX_LEN_REG = 7,
    RX_LEN_REG = 8,
    TX_DATA_REG = 9,
    RX_DATA_REG = 10,
    CS_REG = 11;

logic [QSPI_CSR_WIDTH-1:0] csr_2d_array [0:QSPI_CSR_DEPTH-1];
logic wr_pulse_en, wr_control_en, wr_divider_en, wr_cmd_conf_en, wr_faddr_en, wr_tx_len_en, wr_rx_len_en, 
        wr_cmd_data_en, wr_cs_en, rd_status_en;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        // reset all CSR registers to 0
        for (int i = 0; i < QSPI_CSR_DEPTH; i++) begin
            csr_2d_array[i] <= '0;
        end
    end else begin
        if (wr_control_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_divider_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_cmd_conf_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_faddr_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_tx_len_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_rx_len_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_cmd_data_en) begin
            csr_2d_array[addr] <= wr_data;
        end else if (wr_cs_en) begin
            csr_2d_array[addr] <= wr_data;
        end
    end
end

assign wr_pulse_en = cs && write && (addr == PULSE_REG);
assign wr_control_en = cs && write && (addr == CONTROL_REG);
assign wr_divider_en = cs && write && (addr == DIVIDER_REG);
assign wr_cmd_conf_en = cs && write && (addr == CMD_CONF_REG);
assign wr_cmd_data_en = cs && write && (addr == CMD_DATA_REG);
assign wr_faddr_en = cs && write && (addr == FADDR_REG);
assign wr_tx_len_en = cs && write && (addr == TX_LEN_REG);
assign wr_rx_len_en = cs && write && (addr == RX_LEN_REG);
assign wr_cs_en = cs && write && (addr == CS_REG);

assign start = wr_pulse_en && wr_data[0] && ready;

assign cpol = csr_2d_array[CONTROL_REG][0];
assign cpha = csr_2d_array[CONTROL_REG][1];
assign lsb_first = csr_2d_array[CONTROL_REG][2];
assign ddr_en = csr_2d_array[CONTROL_REG][3];

assign clk_div = csr_2d_array[DIVIDER_REG][QSPI_DIVIDER_WIDTH-1:0];

assign has_opcode = csr_2d_array[CMD_CONF_REG][0];
assign has_addr = csr_2d_array[CMD_CONF_REG][1];
assign has_mode = csr_2d_array[CMD_CONF_REG][2];
assign has_dummy = csr_2d_array[CMD_CONF_REG][3];
assign has_tx_data = csr_2d_array[CMD_CONF_REG][4];
assign has_rx_data = csr_2d_array[CMD_CONF_REG][5];
assign cmd_io_width = csr_2d_array[CMD_CONF_REG][8:6];
assign addr_io_width = csr_2d_array[CMD_CONF_REG][11:9];
assign mode_io_width = csr_2d_array[CMD_CONF_REG][14:12];
assign data_io_width = csr_2d_array[CMD_CONF_REG][17:15];
assign addr_bit_width = csr_2d_array[CMD_CONF_REG][19:18];

assign opcode = csr_2d_array[CMD_DATA_REG][7:0];
assign mode_bits = csr_2d_array[CMD_DATA_REG][8+QSPI_MODE_WIDTH-1:8];
assign dummy_cycles = csr_2d_array[CMD_DATA_REG][8+QSPI_MODE_WIDTH+QSPI_DUMMY_COUNT_WIDTH-1:8+QSPI_MODE_WIDTH];

assign flash_addr = csr_2d_array[FADDR_REG][QSPI_MAX_ADDR_WIDTH-1:0];

assign tx_len = csr_2d_array[TX_LEN_REG][QSPI_DATA_LEN_WIDTH-1:0];

assign rx_len = csr_2d_array[RX_LEN_REG][QSPI_DATA_LEN_WIDTH-1:0];

assign cs_num = csr_2d_array[CS_REG][QSPI_CS_SEL_WIDTH-1:0];



assign fifo_tx_wr = cs && write && (addr == TX_DATA_REG) && !fifo_tx_full;
assign fifo_tx_wbyte = wr_data[QSPI_DATA_WIDTH-1:0];

assign rd_status_en = cs && read && (addr == STATUS_REG);
assign fifo_rx_rd = cs && read && (addr == RX_DATA_REG) && !fifo_rx_empty;
assign rd_data = (fifo_rx_rd) ? {{(QSPI_CSR_WIDTH-QSPI_DATA_WIDTH){1'b0}}, fifo_rx_rbyte} : (rd_status_en) ? {'0, fifo_rx_empty, fifo_tx_full, ready} : '0;

endmodule
