
`ifndef QSPI_DEFINITIONS_VH
`define QSPI_DEFINITIONS_VH

// SPI Timing Modes (CPOL, CPHA)
`define CPOL_0 1'b0  // Clock idle low
`define CPOL_1 1'b1  // Clock idle high
`define CPHA_0 1'b0  // Sample on first edge
`define CPHA_1 1'b1  // Sample on second edge

// I/O Bus Width Modes
`define MODE_SINGLE 2'b00  // IO0 only
`define MODE_DUAL   2'b01  // IO0 and IO1
`define MODE_QUAD   2'b10  // IO0 through IO3

// Transfer Direction
`define DIR_WRITE 1'b0
`define DIR_READ  1'b1

// Protocol Phases
`define PHASE_IDLE     3'b000
`define PHASE_INSTR    3'b001
`define PHASE_ADDRESS  3'b010
`define PHASE_ALT      3'b011  // NEW: Alternate/Mode bits phase
`define PHASE_DUMMY    3'b100
`define PHASE_DATA     3'b101

// Default Configurable Parameters (can be overridden in top-level module)
`define BITS_INSTR    8
`define BITS_ADDR     10
`define BITS_ALT      8
`define BITS_DATA     16
`define BITS_CONFIG   64
`define IO_WIDTH_DEFAULT      4     // Default I/O bus width (Quad mode)
`define REG_WIDTH_DEFAULT   16
`define DUMMY_CYCLES_WIDTH 6
`define MAX_DIVIDER_WIDTH      16
`define TOTAL_SLAVES           4
`define DVSR                   4
`define MAX_MEMORY_BYTES    1024
//`define QSPI_DATA_DEPTH_DEFAULT    256   // Optional data buffer depth (unused for now)

`endif
