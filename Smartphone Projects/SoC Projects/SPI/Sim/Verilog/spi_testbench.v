`timescale 1ns / 1ps

// ============================================================================
// Module: spi_testbench
// Description:
//   Testbench for simulating the top-level SPI master system. This module
//   initializes all SPI configurations (mode, bit order, divider), drives
//   transactions with a simulated slave, and validates behavior for multiple
//   SPI modes and slave select lines.
//
// Notes:
//   - Covers all four SPI modes (Mode 0–3) in both MSB-first and LSB-first
//   - Simulates 4 slave devices, each with loopback logic
//   - Validates functionality across bit orders and CPOL/CPHA combinations
// ============================================================================

module spi_testbench;

  parameter NBITS = 8;               // Width of SPI transactions
  parameter NSLAVE = 4;              // Number of SPI slaves
  parameter CLK_PER = 10;            // Clock period in ns
  parameter DVSR = 4;                // Divider for SPI SCLK

  reg clk;
  reg reset;
  reg start;
  reg [NBITS-1:0] tx_data;
  reg [15:0] dvsr;
  reg cpol, cpha, lsb_first;
  reg [$clog2(NSLAVE)-1:0] cs_num;
  wire [NBITS-1:0] rx_data;
  wire ready;
  wire spi_done_tick;
  wire sclk;
  wire mosi;
  wire [NSLAVE-1:0] cs_decode;
  reg [NSLAVE-1:0] miso_reg;         // register that holds MISO values from all slaves being simulated
  wire miso;

  // Tri-State MISO Bus Mux
  // ==========================================================================
  // This module simulates a wired-OR MISO bus. Only the selected slave is
  // allowed to drive MISO; all others are tri-stated.
  // ==========================================================================
  miso_tri_bus #(.NSLAVE(NSLAVE)) tri_bus(
    miso_reg,
    cs_decode,
    miso
    );

  top_spi_master #(.NBITS(NBITS), .NSLAVE(NSLAVE)) dut1 (
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
    .cs_decode(cs_decode),
    .lsb_first(lsb_first),
    .cs_num(cs_num)
  );
  
  reg [NBITS-1:0] slave_shift_reg [NSLAVE-1:0]; // simulated slave shift registers

// Slave Behavior on Positive Clock Edge
// ==========================================================================
// This generate-for loop creates `NSLAVE` independent always blocks, each one
// simulating the behavior of a unique SPI slave device. These blocks run in
// parallel (in simulation) and respond to the shared SPI clock (`sclk`) and
// shared `mosi` line.
//
// Only the slave whose chip-select (`cs_decode[i]`) is asserted (i.e., 0)
// will actively shift data or drive MISO. All other slaves remain idle or
// in high-Z (via the MISO tri-state mux).
//
// This particular always block handles the **positive edge** of SCLK,
// which is used for either data input (sampling) or output (driving) based
// on the SPI mode (defined by `cpol` and `cpha`).
//
// In SPI:
// - Mode 0 (CPOL=0, CPHA=0) and Mode 3 (CPOL=1, CPHA=1) typically use posedge for sampling
// - The block checks if CPHA aligns with CPOL to determine whether to shift or drive
// ==========================================================================
genvar i;
generate
  for (i = 0; i < NSLAVE; i = i + 1) begin
    always @(posedge sclk or negedge reset) begin
      if (!reset) begin
        // Reset shift register and MISO output for this slave
        slave_shift_reg[i] <= 8'h00;
        miso_reg[i] <= 1'b0;
      end else if (cs_decode[i] == 1'b0) begin
        // Only the selected slave (active-low CS) will participate in SPI transaction
        if ((!cpha & !cpol) | (cpha & cpol))
          // This condition maps to SPI Mode 0 or 3 (sampling on this edge)
          // Shift the received MOSI bit into the appropriate bit end
          slave_shift_reg[i] <= lsb_first ?
            {mosi, slave_shift_reg[i][NBITS-1:1]} :
            {slave_shift_reg[i][NBITS-2:0], mosi};
        else
          // Otherwise, this edge is used to output the next MISO bit
          miso_reg[i] <= lsb_first ?
            slave_shift_reg[i][0] :
            slave_shift_reg[i][NBITS-1];
      end
    end
  end
endgenerate


// Slave Behavior on Negative Clock Edge
// ==========================================================================
// This generate block is complementary to the positive edge block.
// It also instantiates one always block per simulated slave.
//
// It handles SPI modes where data is sampled or driven on the **falling edge**:
// - Mode 1 (CPOL=0, CPHA=1)
// - Mode 2 (CPOL=1, CPHA=0)
//
// The logic remains the same: only the slave selected via `cs_decode[i] == 0`
// will perform SPI operations. Other slaves remain idle.
//
// Depending on CPHA and CPOL, the slave either:
// - Receives data on MOSI by shifting it in
// - Drives the next MISO bit onto the shared MISO line (via tri-state mux)
// ==========================================================================
generate
  for (i = 0; i < NSLAVE; i = i + 1) begin 
    always @(negedge sclk or negedge reset) begin
      if (!reset) begin
        slave_shift_reg[i] <= 8'h00;
        miso_reg[i] <= 1'b0;
      end else if (cs_decode[i] == 1'b0) begin
        // Only the selected slave is active
        if ((cpha & !cpol) | (!cpha & cpol))
          // SPI Mode 1 or 2 (sampling happens here)
          slave_shift_reg[i] <= lsb_first ?
            {mosi, slave_shift_reg[i][NBITS-1:1]} :
            {slave_shift_reg[i][NBITS-2:0], mosi};
        else
          // Otherwise, drive the MISO bit out
          miso_reg[i] <= lsb_first ?
            slave_shift_reg[i][0] :
            slave_shift_reg[i][NBITS-1];
      end
    end
  end
endgenerate


  always #(CLK_PER/2) clk = ~clk; // clock generation

  // SPI Transaction Task
  // ==========================================================================
  // Encapsulates the logic for setting up a transaction:
  //  - Waits for the SPI controller to become ready
  //  - Configures control signals and slave response
  //  - Triggers the transaction and waits for completion
  // ==========================================================================
  
  task run_tx(
    input [NBITS-1:0] master_tx_data,
    input [NBITS-1:0] slave_tx_data,
    input mode_cpol,
    input mode_cpha,
    input mode_lsb,
    input [$clog2(NSLAVE)-1:0] slave_num
  );
    begin
      wait(ready);
      cpol = mode_cpol;
      cpha = mode_cpha;
      lsb_first = mode_lsb;
      cs_num = slave_num;
      dvsr = DVSR;
      tx_data = master_tx_data;

      // Load simulated slave shift register with response value
      slave_shift_reg[slave_num] = slave_tx_data;
      miso_reg[slave_num] = mode_lsb ? slave_tx_data[0] : slave_tx_data[NBITS-1]; 

      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;

      // Wait until controller signals completion
      wait(spi_done_tick);
    end
  endtask

  // Test Sequence
  // ==========================================================================
  initial begin
    reset = 0;
    start = 0;
    clk = 0;
    tx_data = 0;
    dvsr = 0;
    cpol = 0;
    cpha = 0;
    lsb_first = 0;
    cs_num = 0;
    repeat(2) @(posedge clk);
    reset = 1;
    // Mode 0–3 MSB-first
    run_tx(8'hA5, 8'h7B, 0, 0, 0, 0); // Mode 0 MSB-first
    #500
    run_tx(8'h3C, 8'hE9, 0, 1, 0, 1); // Mode 1 MSB-first
    #500
    run_tx(8'hF9, 8'hDB, 1, 0, 0, 2); // Mode 2 MSB-first
    #500
    run_tx(8'h21, 8'h48, 1, 1, 0, 3); // Mode 3 MSB-first
    #500

    // Mode 0–3 LSB-first
    run_tx(8'h7B, 8'hA5, 0, 0, 1, 0); // Mode 0 LSB-first
    #500
    run_tx(8'hE9, 8'h3C, 0, 1, 1, 1); // Mode 1 LSB-first
    #500
    run_tx(8'hDB, 8'hF9, 1, 0, 1, 2); // Mode 2 LSB-first
    #500
    run_tx(8'h48, 8'h21, 1, 1, 1, 3); // Mode 3 LSB-first

    $finish;
  end

endmodule
