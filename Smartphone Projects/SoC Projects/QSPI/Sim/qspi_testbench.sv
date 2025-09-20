`timescale 1ns / 1ps

`include "qspi_interface.sv"
`include "qspi_definitions.vh"

module qspi_testbench();

    localparam integer INSTR_BITS       = `BITS_INSTR;
    localparam integer ADDR_BITS        = `BITS_ADDR;
    localparam integer ALT_BITS         = `BITS_ALT;    
    localparam integer DATA_BITS        = `BITS_DATA;   
                
    localparam integer SHIFT_REG_BITS   = `REG_WIDTH_DEFAULT;
    localparam integer IO_WIDTH         = `IO_WIDTH_DEFAULT;
    localparam integer CONFIG_BITS      = `BITS_CONFIG;
    localparam integer MAX_DUMMY_CYCLES = `DUMMY_CYCLES_WIDTH;
    localparam integer DIVIDER_WIDTH    = `MAX_DIVIDER_WIDTH;
    localparam integer NSLAVE           = `TOTAL_SLAVES;
    
    logic                     clk;
    logic                     reset;                           
    logic                     start;
    logic                     cpol;
    logic                     cpha;
    logic                     data_ready;
    logic                     tx_valid;
    logic                     config_addr;
    logic                     config_write;                               
    logic [SHIFT_REG_BITS-1:0] config_data;
    logic [DATA_BITS-1:0]      tx_data;
    logic [DIVIDER_WIDTH-1:0]   dvsr;
    logic [$clog2(NSLAVE)-1:0] cs_num;        // Selected slave index (used to decode CS)
    
    logic                      busy;
    logic                      done;
    logic                      sclk;
    logic                      tx_ready;
    logic                      data_valid;
    logic [DATA_BITS-1:0]      rx_data;
    logic [NSLAVE-1:0]        cs_decode;
    
    tri [IO_WIDTH-1:0]        io;
    
    top_qspi_controller 
#(
    .INSTR_BITS(INSTR_BITS),      
    .ADDR_BITS(ADDR_BITS),        
    .ALT_BITS(ALT_BITS),          
    .DATA_BITS(DATA_BITS),         
    
    .SHIFT_REG_BITS(SHIFT_REG_BITS),   
    .IO_WIDTH(IO_WIDTH),         
    .CONFIG_BITS(CONFIG_BITS),      
    .MAX_DUMMY_CYCLES(MAX_DUMMY_CYCLES), 
    .DIVIDER_WIDTH(DIVIDER_WIDTH),    
    .NSLAVE(NSLAVE)           
)
master_controller(
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
    .cs_num(cs_num),        // Selected slave index (used to decode CS)
    
    .busy(busy),
    .done(done),
    .sclk(sclk),
    .tx_ready(tx_ready),
    .data_valid(data_valid),
    .rx_data(rx_data),
    .cs_decode(cs_decode),
    
    .io(io)
);



endmodule
