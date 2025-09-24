`timescale 1ns / 1ps
// qspi_controller.v
// -----------------------------------------------------------------------------
// QSPI Master Controller with Instruction, Address, Alternate, Dummy, and Data
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_controller 
#(
    parameter INSTR_BITS       = `BITS_INSTR,
    parameter ADDR_BITS        = `BITS_ADDR,
    parameter ALT_BITS         = `BITS_ALT,    
    parameter DATA_BITS        = `BITS_DATA,   
  
    parameter SHIFT_REG_BITS   = `REG_WIDTH_DEFAULT,
    parameter IO_WIDTH         = `IO_WIDTH_DEFAULT,
    parameter CONFIG_BITS      = `BITS_CONFIG,
    parameter MAX_DUMMY_CYCLES = `DUMMY_CYCLES_WIDTH,
    parameter DIVIDER_WIDTH    = `MAX_DIVIDER_WIDTH
)
(
    input  wire                      clk,
    input  wire                      reset,                           
    input  wire                      start,
    input wire                       cpol,
    input wire                       cpha,
    input wire                       data_ready,
    input  wire                      tx_valid,
    input  wire                      config_addr,
    input  wire                      config_write,                               
    input  wire [SHIFT_REG_BITS-1:0] config_data,
    input  wire [DATA_BITS-1:0]      tx_data,
    input wire [DIVIDER_WIDTH-1:0]   dvsr,

    
    output wire                      busy,
    output wire                      done,
    output wire                      cs,
    output wire                      sclk,
    output wire                      tx_ready,
    output wire                      data_valid,
    output wire [DATA_BITS-1:0]      rx_data,
    
    inout wire [IO_WIDTH-1:0]        io
);

    // -----------------------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------------------
    wire                      phase_done;
    wire                      sample_edge;
    wire                      drive_edge;
    wire [IO_WIDTH-1:0]       io_drv;
    wire [IO_WIDTH-1:0]       io_in;
    wire [SHIFT_REG_BITS-1:0] r_rx_data;
    wire [2:0]                current_phase;
    wire [1:0]                  shift_width;
    wire                        write_enable;
    wire [SHIFT_REG_BITS-1:0]         write_data;

    
    // Command Config 
    wire [INSTR_BITS-1:0]       opcode;                       
    wire [1:0]                  instr_mode;                   
    wire [ADDR_BITS-1:0]        address;                      
    wire [1:0]                  addr_mode;                    
    wire [1:0]                  alt_mode;                     
    wire [ALT_BITS-1:0]         alt_data;                     
    wire [MAX_DUMMY_CYCLES-1:0] dummy_cycles;
    wire [1:0]                  dummy_mode;                   
    wire [1:0]                  data_mode;                    
    wire                        lsb_first;                    
    wire                        dir;                           
    
    
    reg                              r_dir;
    reg                              enable_transaction;
    reg [$clog2(SHIFT_REG_BITS):0]   bit_length;  
    reg [SHIFT_REG_BITS-1:0]         shift_data;
    reg [1:0]                        phase_mode;
        
    command_config 
    #(
    .CONFIG_BITS(CONFIG_BITS),     // match your definitions
    .INSTR_BITS(INSTR_BITS),
    .ADDR_BITS(ADDR_BITS),
    .ALT_BITS(ALT_BITS),
    .MAX_DUMMY_CYCLES(MAX_DUMMY_CYCLES)
    ) config_block 
    (
        .clk(clk),
        .reset(reset),
        .config_data(config_data),
        .config_addr(config_addr),
        .config_write(config_write),
        .opcode(opcode),
        .instr_mode(instr_mode),
        .address(address),
        .addr_mode(addr_mode),
        .alt_mode(alt_mode),
        .alt_data(alt_data),
        .dummy_cycles(dummy_cycles),
        .dummy_mode(dummy_mode),
        .data_mode(data_mode),
        .lsb_first(lsb_first),
        .dir(dir)
    );

    
    shift_width_calc uut0
    (
        .clk(clk),
        .reset(reset),
        .phase_mode(phase_mode),
        .shift_width(shift_width)
    );
    // -----------------------------------------------------------------------------
    // FSM
    // -----------------------------------------------------------------------------
    fsm uut1 
    (
        .clk(clk),
        .reset(reset),
        .start(start),
        .done_tick(phase_done),
        .current_phase(current_phase),
        .busy(busy),
        .done(done)
    );

    // -----------------------------------------------------------------------------
    // SCLK Generator
    // -----------------------------------------------------------------------------
    clkgen uut2 
    (
        .clk(clk),
        .reset(reset),
        .enable(busy),
        .cpol(cpol),
        .cpha(cpha),
        .dvsr(dvsr),
        .sclk(sclk),
        .sample_edge(sample_edge),
        .drive_edge(drive_edge)
    );

    // -----------------------------------------------------------------------------
    // I/O Control
    // -----------------------------------------------------------------------------
    io_ctrl #(.IO_WIDTH(IO_WIDTH)) uut3
    (
        .clk(clk),
        .reset(reset),
        .phase_mode(phase_mode),
        .dir(r_dir),
        .data_out(io_drv),
        .io(io),
        .data_in(io_in)
    );

    // -----------------------------------------------------------------------------
    // Shift Register
    // -----------------------------------------------------------------------------
    shift_reg #(.SHIFT_REG_BITS(SHIFT_REG_BITS), .IO_WIDTH(IO_WIDTH)) uut4 
    (
        .clk(clk),
        .reset(reset),
        .lsb_first(lsb_first),
        .load(enable_transaction),
        .drive_strobe(drive_edge),
        .sample_strobe(sample_edge),
        .data_in(shift_data),
        .io_in(io_in),
        .bit_length(bit_length),
        .shift_width(shift_width),
        .data_out(r_rx_data),
        .io_out(io_drv),
        .done(phase_done)
    );
    
    // Write Handshake
    write_handshake #(.DATA_BITS(DATA_BITS)) tx_handshake (
        .clk(clk),
        .reset(reset),
        .enable(current_phase == `PHASE_DATA && dir == `DIR_WRITE),
        .tx_valid(tx_valid),
        .tx_data(tx_data),
        .data_out(write_data),
        .load_data(write_enable),
        .tx_ready(tx_ready)
    );

    // Read Handshake
    read_handshake #(.DATA_BITS(DATA_BITS)) rx_handshake (
        .clk(clk),
        .reset(reset),
        .enable(current_phase == `PHASE_DATA && dir == `DIR_READ && phase_done),
        .data_ready(data_ready),
        .data_in(r_rx_data),
        .rx_data(rx_data),
        .data_valid(data_valid)
    );

    // -----------------------------------------------------------------------------
    // Phase Control Logic
    // -----------------------------------------------------------------------------
    always @(*) begin
        enable_transaction = 0;
        phase_mode     = instr_mode;
        r_dir      = `DIR_WRITE;
        shift_data  = {SHIFT_REG_BITS{1'b0}};
        bit_length  = 0;

        case (current_phase)
            `PHASE_INSTR: begin
                phase_mode     = instr_mode;
                r_dir      = `DIR_WRITE;
                shift_data  = lsb_first ? {{(SHIFT_REG_BITS-INSTR_BITS){1'b0}}, opcode} : {opcode, {(SHIFT_REG_BITS-INSTR_BITS){1'b0}}};
                bit_length  = INSTR_BITS;
                enable_transaction = 1;
            end
            `PHASE_ADDRESS: begin
                phase_mode     = addr_mode;
                r_dir      = `DIR_WRITE;
                shift_data  = lsb_first ? {{(SHIFT_REG_BITS-ADDR_BITS){1'b0}}, address[ADDR_BITS-1:0]} : {address[ADDR_BITS-1:0], {(SHIFT_REG_BITS-ADDR_BITS){1'b0}}};
                bit_length  = ADDR_BITS;
                enable_transaction = 1;
            end
            `PHASE_ALT: begin
                phase_mode     = alt_mode;
                r_dir      = `DIR_WRITE;
                shift_data  = lsb_first ? {{(SHIFT_REG_BITS-ALT_BITS){1'b0}}, alt_data} : {alt_data, {(SHIFT_REG_BITS-ALT_BITS){1'b0}}};
                bit_length  = ALT_BITS;
                enable_transaction = 1;
            end
            `PHASE_DUMMY: begin
                phase_mode     = dummy_mode;
                r_dir      = `DIR_WRITE;
                shift_data  = {SHIFT_REG_BITS{1'b0}};
                case (shift_width) 
                    0: bit_length = 0;
                    1: bit_length = dummy_cycles;
                    2: bit_length = dummy_cycles << 1;
                    3: bit_length = dummy_cycles << 2;
                    default: bit_length = 0; // fallback
                endcase
                enable_transaction = 1;
            end
            `PHASE_DATA: begin
                phase_mode     = data_mode;
                r_dir      = dir;
                bit_length = DATA_BITS;
                if (dir == `DIR_WRITE) begin
                    shift_data  = write_data;  // output from handshake
                    enable_transaction = write_enable;     // trigger load only when handshake completes
                end else begin
                    shift_data  = {SHIFT_REG_BITS{1'b0}};
                    enable_transaction = 1;
                end
            end
            default: begin
                enable_transaction = 0;
                phase_mode     = instr_mode;
                r_dir      = `DIR_WRITE;
                bit_length  = 0;
            end
        endcase
    end

    assign cs = ~busy;

endmodule
