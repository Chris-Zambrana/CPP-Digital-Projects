`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// qspi_if.sv  -  Minimal QSPI bus interface
//------------------------------------------------------------------------------
`include "qspi_definitions.vh"   // pull in global defaults

interface qspi_interface #(
  parameter int IO_WIDTH = `IO_WIDTH_DEFAULT  // use global default unless overridden
) ();
  logic             sclk;
  logic             cs_n;
  tri   [IO_WIDTH-1:0] io;

  // Roles
  modport master  (output sclk, output cs_n, inout io);
  modport slave   (input  sclk, input cs_n, inout io);
endinterface