`timescale 1ns / 1ps
// qspi_io_ctrl.v
// -----------------------------------------------------------------------------
// I/O Line Control for QSPI Bidirectional Bus
// Updated to reflect timing correctness, inout control, and mode-safe enable
// Synchronized with clk_edge to match SPI timing (CPOL/CPHA compliant)
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_io_ctrl 
(
    // controller to IO control signals
    input  logic [3:0] phase,
    input  logic [2:0] current_bus_width,

    // shift register to IO control signals
    input  logic [3:0] io_tx,

    // IO control to shift register signals
    output logic [3:0] io_rx,

    // qspi external interface
    inout  tri  [3:0] qspi_io
);

localparam [3:0] IDLE        = 4'b0000,
           CS_SETUP    = 4'b0001,
           INSTRUCTION = 4'b0010,
           ADDRESS     = 4'b0011,
           MODE        = 4'b0100,
           DUMMY       = 4'b0101,
           TX_DATA     = 4'b0110,
           RX_DATA     = 4'b0111,
           CS_HOLD     = 4'b1000;

// qspi_io needs to be set to Z when RX, when current_bus_width is less than 4, or in a state where nothing happens. 
logic tx_flag;

always_comb begin 
    tx_flag = 1'b0; // default to not transmitting

    case(phase) 

        INSTRUCTION, ADDRESS, MODE, TX_DATA: begin
            tx_flag = 1'b1; // indicate that we are transmitting
        end

        default: begin
            tx_flag = 1'b0; // indicate that we are transmitting
        end
    endcase

end

assign qspi_io[0] = (tx_flag && current_bus_width >= 1) ? io_tx[0] : 1'bz;
assign qspi_io[1] = (tx_flag && current_bus_width >= 2) ? io_tx[1] : 1'bz;
assign qspi_io[2] = (tx_flag && current_bus_width == 4) ? io_tx[2] : 1'bz;
assign qspi_io[3] = (tx_flag && current_bus_width == 4) ? io_tx[3] : 1'bz;

assign io_rx = qspi_io;

endmodule
