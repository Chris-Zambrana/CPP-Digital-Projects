`timescale 1ns / 1ps
// qspi_io_ctrl.v
// -----------------------------------------------------------------------------
// I/O Line Control for QSPI Bidirectional Bus
// Updated to reflect timing correctness, inout control, and mode-safe enable
// Synchronized with clk_edge to match SPI timing (CPOL/CPHA compliant)
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module io_ctrl 
#(
    parameter IO_WIDTH = `IO_WIDTH_DEFAULT
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    drive_edge,   // drive update timing from qspi_clkgen
    input  wire [1:0]              mode,       // 00=SINGLE, 01=DUAL, 10=QUAD
    input  wire                    dir,        // 0=write (output), 1=read (input)
    input  wire [IO_WIDTH-1:0]     data_out,   // Data to drive onto bus (from shift_reg)
    inout  wire [IO_WIDTH-1:0]     io,         // Bidirectional QSPI lines
    output wire [IO_WIDTH-1:0]     data_in     // Captured from bus
);
    reg  [IO_WIDTH-1:0]     io_out;      // Values driven onto IO lines (registered)
    reg  [IO_WIDTH-1:0]     io_oe;       // Output enable lines (registered)
    
    wire dir_write = (dir == `DIR_WRITE);
    
    // Build a width mask from mode (assumes IO_WIDTH >= 4)
    wire [IO_WIDTH-1:0] mode_mask =
        (mode == `MODE_SINGLE) ? {{(IO_WIDTH-1){1'b0}}, 1'b1} :
        (mode == `MODE_DUAL)   ? {{(IO_WIDTH-2){1'b0}}, 2'b11} :
        (mode == `MODE_QUAD)   ? 4'b1111 :
                                 {IO_WIDTH{1'b0}};

    // Register output drive and enable on clk_edge (SCLK timing alignment)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            io_oe  <= {IO_WIDTH{1'b0}};
            io_out <= {IO_WIDTH{1'b0}};
        end else if (drive_edge) begin
            io_out <= data_out & mode_mask;
            io_oe  <= ({IO_WIDTH{dir_write}} & mode_mask);
        end
    end

    // Tri-state control logic (per IO line)
    genvar i;
    generate
        for (i = 0; i < IO_WIDTH; i = i + 1) begin
            assign io[i] = io_oe[i] ? io_out[i] : 1'bz;
        end
    endgenerate

    assign data_in = io;

endmodule
