`timescale 1ns / 1ps

// ============================================================================
// Module: miso_tri_bus
// Description:
//   Simulates a tri-state shared MISO line where only one slave is allowed
//   to drive the bus at a time. Based on the active-low chip-select decoding
//   signal from the master (`cs_decode`), this module forwards the corresponding
//   slave's MISO output (`miso_reg[i]`) onto a shared output line (`miso`).
//
//   If no slave is selected, the line is set to high-impedance (Z), which is
//   realistic for SPI open-drain bus sharing, or can be set to 0 for synthesis.
//
// Parameters:
//   NSLAVE - Number of SPI slave devices in the system
// ============================================================================
module miso_tri_bus 
  #(parameter NSLAVE = 4)
(
  input  [NSLAVE-1:0] miso_reg,        // Input bus from simulated slaves
  input  [NSLAVE-1:0] cs_decode,       // Active-low chip select vector from master
  output reg miso                      // Shared MISO line to master
);

  // Based on the one-hot active-low `cs_decode` value, this selects which slave's
  // MISO output (`miso_reg[i]`) is routed to the master MISO line. Only one slave
  // should ever have a `0` on its chip-select line during a transaction.
  //
  // If no chip select is active (i.e., cs_decode == 4'b1111), the output defaults
  // to high-impedance (`1'bz`), which mimics the behavior of a shared bus.
  //
  // The `casez` structure allows partial pattern matching and is efficient in simulation.
  
  always@(*) begin
    casez (cs_decode)
      4'b1110: miso = miso_reg[0];   // Slave 0 selected (CS0 active-low)
      4'b1101: miso = miso_reg[1];   // Slave 1 selected
      4'b1011: miso = miso_reg[2];   // Slave 2 selected
      4'b0111: miso = miso_reg[3];   // Slave 3 selected
      default: miso = 1'bz;          // No slave selected ? tri-state MISO
    endcase
  end

endmodule
