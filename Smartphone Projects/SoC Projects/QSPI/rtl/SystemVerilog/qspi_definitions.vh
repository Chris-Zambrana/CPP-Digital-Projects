
`ifndef QSPI_DEFINITIONS_VH
`define QSPI_DEFINITIONS_VH

`define CSR_DEPTH 32
`define DIVIDER_BITS 16
`define MAX_ADDR_BITS 32
`define CONST_DATA_LEN 16
`define DUMMY_COUNT 8
`define MODE_CYCLE_COUNT 4
`define MODE_BITS 8
`define CS_COUNT 4
`define CSR_WIDTH 32
`define DATA_BITS 8
`define QSPI_FIFO_DEPTH 32
`define QSPI_FIFO_WIDTH `DATA_BITS

// SPI Timing Modes (CPOL, CPHA)
`define CPOL_0 1'b0  // Clock idle low
`define CPOL_1 1'b1  // Clock idle high
`define CPHA_0 1'b0  // Sample on first edge
`define CPHA_1 1'b1  // Sample on second edge

// I/O Bus Width Modes
`define MODE_ZERO   2'b00
`define MODE_SINGLE 2'b01  // IO0 only
`define MODE_DUAL   2'b10  // IO0 and IO1
`define MODE_QUAD   2'b11  // IO0 through IO3


`endif
