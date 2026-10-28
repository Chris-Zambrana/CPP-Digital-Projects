`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/09/2026 09:02:09 PM
// Design Name: 
// Module Name: top_qspi_sys_test
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

module top_qspi_sys_test
#(
    parameter BRG_BASE = 32'hc000_0000,
    parameter QSPI_SLAVE_COUNT = `QSPI_SLAVE_COUNT
)
(
    input logic clk,
    input logic reset_n,

    input logic rx,
    output logic tx,

    output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,
    inout  tri  [3:0]  qspi_io
);

    logic reset_sys = ~reset_n;

    // MCS IO bus
    logic io_addr_strobe;
    logic io_read_strobe;
    logic io_write_strobe;
    logic [3:0] io_byte_enable;
    logic [31:0] io_address;
    logic [31:0] io_write_data;
    logic [31:0] io_read_data;
    logic io_ready;

    // bridge bus
    logic cs;          
    logic wr;            
    logic rd;
    logic [20:0] addr;
    logic [31:0] wr_data;
    logic [31:0] rd_data;

    cpu cpu_unit (
        .Clk(clk),                     // input wire Clk
        .Reset(reset_sys),                  // input wire Reset
        .IO_addr_strobe(io_addr_strobe),    // output wire IO_addr_strobe
        .IO_address(io_address),            // output wire [31 : 0] IO_address
        .IO_byte_enable(io_byte_enable),    // output wire [3 : 0] IO_byte_enable
        .IO_read_data(io_read_data),        // input wire [31 : 0] IO_read_data
        .IO_read_strobe(io_read_strobe),    // output wire IO_read_strobe
        .IO_ready(io_ready),                // input wire IO_ready
        .IO_write_data(io_write_data),      // output wire [31 : 0] IO_write_data
        .IO_write_strobe(io_write_strobe)   // output wire IO_write_strobe
   );

   // instantiate bridge
   cpu_bridge #(.BRG_BASE(BRG_BASE)) bridge_unit (.*);

   qspi_mmio_sys #(.QSPI_SLAVE_COUNT(QSPI_SLAVE_COUNT)) mmio_unit (
    .clk(clk),
    .reset(reset_sys),
    .mmio_cs(cs),
    .mmio_wr(wr),
    .mmio_rd(rd),
    .mmio_addr(addr), 
    .mmio_wr_data(wr_data),
    .mmio_rd_data(rd_data),
    .rx(rx),
    .tx(tx),
    .qspi_cs(qspi_cs),
    .qspi_io(qspi_io)         
  );   
    


endmodule
