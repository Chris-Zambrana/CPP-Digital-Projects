`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/09/2026 09:10:38 PM
// Design Name: 
// Module Name: cpu_bridge
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


module cpu_bridge
    #(parameter BRG_BASE=32'hc000_0000)   // default base address
   (
        // uBlaze MCS I/O bus
        input  logic io_addr_strobe,   // not used
        input  logic io_read_strobe, 
        input  logic io_write_strobe, 
        input  logic [3:0] io_byte_enable, 
        input  logic [31:0] io_address, 
        input  logic [31:0] io_write_data, 
        output logic [31:0] io_read_data, 
        output logic io_ready, 
        // bus
        output logic cs, 
        output logic wr,
        output logic rd,
        output logic [20:0]addr,
        output logic [31:0] wr_data,
        input  logic [31:0] rd_data
    );
     
   // declaration
   logic mcs_bridge_en;
   logic [29:0] word_addr;

   // body
   // address translation and decoding
   //  2 LSBs are "00" due to word alignment
   assign word_addr = io_address[31:2];
   assign mcs_bridge_en = (io_address[31:24] == BRG_BASE[31:24]);
   assign cs = (mcs_bridge_en && io_address[23] == 0);
   assign addr = word_addr[20:0];
   //  control line conversion 
   assign wr = io_write_strobe;
   assign rd = io_read_strobe;
   assign io_ready = 1;   // not used ; transaction done in 1 clock
   // data line conversion
   assign wr_data = io_write_data;
   assign io_read_data = rd_data;  
endmodule
