`timescale 1ns / 1ps

// Module: top_spi_master
// -----------------------------------------------------------------------
// Description:
//   Top-level SPI master wrapper that connects a parameterized SPI controller
//   to multiple slave devices through chip select decoding. It handles
//   transaction control signals, passes configuration and data to the
//   spi_controller submodule, and expands a single CS output into a
//   decoded one-hot chip-select vector for NSLAVE devices.
//
// Parameters:
//   NBITS  - Number of bits per SPI transfer 
//   NSLAVE - Number of slave devices to control
// -----------------------------------------------------------------------
module top_spi_master
  #(parameter NBITS = 8, NSLAVE = 4)
  (
    input clk,                                // System clock
    input reset,                              // Active-low synchronous reset
    input start,                              // Trigger signal to start SPI transaction
    input [NBITS-1:0] tx_data,                // Data to transmit
    input [15:0] dvsr,                        // Clock divider
    input miso,                               // Serial input from slave
    input cpol,                               // SPI clock polarity
    input cpha,                               // SPI clock phase
    input lsb_first,                          // 0 = MSB is sent first (tx_data is shifted left), 1 = LSB is sent first (tx_data is shifted right)
    input [$clog2(NSLAVE)-1:0] cs_num,        // Selected slave index (used to decode CS)

    output [NBITS-1:0] rx_data,               // Received data from SPI transaction
    output ready,                             // High when SPI controller is idle and ready for activation
    output spi_done_tick,                     // One-cycle pulse at end of SPI transaction
    output sclk,                              // SPI serial clock (to slave)
    output mosi,                              // SPI master output (to slave)
    output [NSLAVE-1:0] cs_decode             // One-hot active-low chip select vector
  );
  
  wire cs_n; // Internal CS signal from the SPI controller.

  // SPI Controller Instantiation
  // -----------------------------------------------------------------------
  // Connects internal SPI logic that performs the actual shift-register-based
  // transmission and reception. Parameter NBITS is passed for flexibility.
  // -----------------------------------------------------------------------
  spi_controller #(.NBITS(NBITS)) u_spi (
    .clk(clk),
    .reset(reset),
    .start(start),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .dvsr(dvsr),
    .ready(ready),
    .spi_done_tick(spi_done_tick),
    .sclk(sclk),
    .mosi(mosi),
    .miso(miso),
    .cpol(cpol),
    .cpha(cpha),
    .cs(cs_n),               // Internal single-bit CS line
    .lsb_first(lsb_first)
  );

  // Chip Select Decoder
  // -----------------------------------------------------------------------
  // Converts the internal cs_n signal into a one-hot active-low output vector
  // where only the selected slave (indexed by cs_num) is enabled.
  //
  // Logic:
  //   - {NSLAVE{cs_n}} creates a vector of replicated cs_n values.
  //   - ~(1 << cs_num) generates a one-hot pattern with a single 0.
  //   - OR'ing them masks all but the selected slave line.
  //
  // Active Transaction Example: (NSLAVE=4, cs_n=0, cs_num=2):
  //     cs_decode = 4'b0000 | ~(1 << 2) = 4'b1011
  //
  // IDLE Example: (NSLAVE=4, cs_n=1, cs_num=2):
  //     cs_decode = 4'b1111 | ~(1 << 2) = 4'b1111
  // -----------------------------------------------------------------------
  assign cs_decode = {NSLAVE{cs_n}} | ~(1 << cs_num);

endmodule