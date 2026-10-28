`include "chu_io_map.svh"

module qspi_mmio_sys
#(
    parameter QSPI_SLAVE_COUNT = `QSPI_SLAVE_COUNT
)	
(
   input logic clk,
   input  logic reset,
   // FPro bus 
   input  logic mmio_cs,
   input  logic mmio_wr,
   input  logic mmio_rd,
   input  logic [20:0] mmio_addr, // 11 LSB used; 2^6 slots; 2^5 reg each 
   input  logic [31:0] mmio_wr_data,
   output logic [31:0] mmio_rd_data,
   // uart
   input logic rx,
   output logic tx,          

   output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,
   inout  tri  [3:0]  qspi_io
);

   // declaration
   logic [63:0] mem_rd_array;
   logic [63:0] mem_wr_array;
   logic [63:0] cs_array;
   logic [4:0] reg_addr_array [63:0];
   logic [31:0] rd_data_array [63:0]; 
   logic [31:0] wr_data_array [63:0];

   // body
   // instantiate mmio controller 
   mmio_controller ctrl_unit
   (
        .clk(clk),
        .reset(reset),
        .mmio_cs(mmio_cs),
        .mmio_wr(mmio_wr),
        .mmio_rd(mmio_rd),
        .mmio_addr(mmio_addr), 
        .mmio_wr_data(mmio_wr_data),
        .mmio_rd_data(mmio_rd_data),
        // slot interface
        .slot_cs_array(cs_array),
        .slot_mem_rd_array(mem_rd_array),
        .slot_mem_wr_array(mem_wr_array),
        .slot_reg_addr_array(reg_addr_array),
        .slot_rd_data_array(rd_data_array), 
        .slot_wr_data_array(wr_data_array)
    );
  
   // slot 0: system timer 
   chu_timer timer_slot0 
   (
        .clk(clk),
        .reset(reset),
        .cs(cs_array[`S0_SYS_TIMER]),
        .read(mem_rd_array[`S0_SYS_TIMER]),
        .write(mem_wr_array[`S0_SYS_TIMER]),
        .addr(reg_addr_array[`S0_SYS_TIMER]),
        .rd_data(rd_data_array[`S0_SYS_TIMER]),
        .wr_data(wr_data_array[`S0_SYS_TIMER])
    );

   // slot 1: UART 
   chu_uart uart_slot1 
   (
        .clk(clk),
        .reset(reset),
        .cs(cs_array[`S1_UART1]),
        .read(mem_rd_array[`S1_UART1]),
        .write(mem_wr_array[`S1_UART1]),
        .addr(reg_addr_array[`S1_UART1]),
        .rd_data(rd_data_array[`S1_UART1]),
        .wr_data(wr_data_array[`S1_UART1]), 
        .tx(tx),
        .rx(rx)
    );
   //assign rd_data_array[1] = 32'h00000000;

   // slot 2: gpo 
   top_qspi_core #(.QSPI_SLAVE_COUNT(QSPI_SLAVE_COUNT)) qspi_slot2 
   (
        .clk(clk),
        .reset(reset),
        .cs(cs_array[`S2_QSPI]),
        .read(mem_rd_array[`S2_QSPI]),
        .write(mem_wr_array[`S2_QSPI]),
        .addr(reg_addr_array[`S2_QSPI]),
        .rd_data(rd_data_array[`S2_QSPI]),
        .wr_data(wr_data_array[`S2_QSPI]),
        .qspi_cs(qspi_cs),
        .qspi_io(qspi_io)
    );
    
   // assign 0's to all unused slot rd_data signals
   generate
      genvar i;
      for (i=3; i<64; i=i+1) begin:  unused_slot_gen
         assign rd_data_array[i] = 32'hffffffff;
      end
   endgenerate

endmodule