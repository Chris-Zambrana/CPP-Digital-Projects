`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module top_qspi_controller 
#(
    parameter INSTR_BITS       = `BITS_INSTR,
    parameter ADDR_BITS        = `BITS_ADDR,
    parameter ALT_BITS         = `BITS_ALT,    
    parameter DATA_BITS        = `BITS_DATA,   
  
    parameter SHIFT_REG_BITS   = `REG_WIDTH_DEFAULT,
    parameter IO_WIDTH         = `IO_WIDTH_DEFAULT,
    parameter CONFIG_BITS      = `BITS_CONFIG,
    parameter MAX_DUMMY_CYCLES = `DUMMY_CYCLES_WIDTH,
    parameter DIVIDER_WIDTH    = `MAX_DIVIDER_WIDTH,
    parameter NSLAVE           = `TOTAL_SLAVES
)
(
    input  wire                      clk,
    input  wire                      reset,                           
    input  wire                      start,
    input  wire                       cpol,
    input  wire                       cpha,
    input  wire                       data_ready,
    input  wire                      tx_valid,
    input  wire                      config_addr,
    input  wire                      config_write,                               
    input  wire [SHIFT_REG_BITS-1:0] config_data,
    input  wire [DATA_BITS-1:0]      tx_data,
    input  wire [DIVIDER_WIDTH-1:0]   dvsr,
    input  wire [$clog2(NSLAVE)-1:0] cs_num,        // Selected slave index (used to decode CS)
    
    output wire                      busy,
    output wire                      done,
    output wire                      sclk,
    output wire                      tx_ready,
    output wire                      data_valid,
    output wire [DATA_BITS-1:0]      rx_data,
    output wire [NSLAVE-1:0]        cs_decode,
    
    inout [IO_WIDTH-1:0]        io
);

    wire cs_n;
    
    qspi_controller 
    #(
       .INSTR_BITS(INSTR_BITS),      
       .ADDR_BITS(ADDR_BITS),        
       .ALT_BITS(ALT_BITS),        
       .DATA_BITS(DATA_BITS),                       
       .SHIFT_REG_BITS(SHIFT_REG_BITS),  
       .IO_WIDTH(IO_WIDTH),        
       .CONFIG_BITS(CONFIG_BITS),     
       .MAX_DUMMY_CYCLES(MAX_DUMMY_CYCLES),
       .DIVIDER_WIDTH(DIVIDER_WIDTH)   
    ) master
    (
        .clk(clk),         
        .reset(reset),       
        .start(start),       
        .cpol(cpol),        
        .cpha(cpha),        
        .data_ready(data_ready),  
        .tx_valid(tx_valid),    
        .config_addr(config_addr), 
        .config_write(config_write),
        .config_data(config_data), 
        .tx_data(tx_data),     
        .dvsr(dvsr),        
               
        .busy(busy),        
        .done(done),        
        .cs(cs_n),          
        .sclk(sclk),        
        .tx_ready(tx_ready),    
        .data_valid(data_valid),  
        .rx_data(rx_data),     
                    
        .io(io)           
    );
    
    assign cs_decode = {NSLAVE{cs_n}} | ~(1 << cs_num);
    
endmodule