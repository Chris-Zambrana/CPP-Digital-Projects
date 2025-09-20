`timescale 1ns / 1ps

// QSPI Command Configuration Register Bank Module for 32-bit Systems
// -----------------------------------------------------------------------------

module command_config 
#(
    parameter CONFIG_BITS    = `BITS_CONFIG,
    parameter INSTR_BITS     = `BITS_INSTR,
    parameter ADDR_BITS      = `BITS_ADDR,
    parameter ALT_BITS       = `BITS_ALT,
    parameter MAX_DUMMY_CYCLES = `DUMMY_CYCLES_WIDTH,
    parameter SHIFT_REG_BITS = `REG_WIDTH_DEFAULT
)
(
    input  wire        clk,
    input  wire        reset,
    input  wire [SHIFT_REG_BITS-1:0] config_data,
    input  wire        config_addr,
    input  wire        config_write,

    output wire [INSTR_BITS-1:0] opcode,
    output wire [1:0]            instr_mode,
    output wire [ADDR_BITS-1:0]  address,
    output wire [1:0]            addr_mode,
    output wire [1:0]            alt_mode,
    output wire [ALT_BITS-1:0]   alt_data,     
    output wire [MAX_DUMMY_CYCLES-1:0]            dummy_cycles,
    output wire [1:0]            dummy_mode,
    output wire [1:0]            data_mode,
    output wire                  lsb_first,
    output wire                  dir
);

    reg [CONFIG_BITS-1:0] cmd_config;

    // Bitfield parameter definitions
    localparam OPCODE_LSB       = 0;
    localparam OPCODE_MSB       = OPCODE_LSB + INSTR_BITS - 1;
    
    localparam INSTR_MODE_LSB   = OPCODE_MSB + 1;
    localparam INSTR_MODE_MSB   = INSTR_MODE_LSB + 1;
    
    localparam ADDR_LSB         = INSTR_MODE_MSB + 1;
    localparam ADDR_MSB         = ADDR_LSB + ADDR_BITS - 1;
    
    localparam ADDR_MODE_LSB    = ADDR_MSB + 1;
    localparam ADDR_MODE_MSB    = ADDR_MODE_LSB + 1;
    
    localparam ALT_LSB          = ADDR_MODE_MSB + 1;
    localparam ALT_MSB          = ALT_LSB + ALT_BITS - 1;
    
    localparam ALT_MODE_LSB     = ALT_MSB + 1;
    localparam ALT_MODE_MSB     = ALT_MODE_LSB + 1;
    
    localparam DUMMY_LSB        = ALT_MODE_MSB + 1;
    localparam DUMMY_MSB        = DUMMY_LSB + MAX_DUMMY_CYCLES - 1;

    localparam DUMMY_MODE_LSB   = DUMMY_MSB + 1;
    localparam DUMMY_MODE_MSB   = DUMMY_MODE_LSB + 1;

    localparam DATA_MODE_LSB    = DUMMY_MODE_MSB + 1;
    localparam DATA_MODE_MSB    = DATA_MODE_LSB + 1;

    localparam LSB_FIRST_BIT    = DATA_MODE_MSB + 1;
    
    localparam DIR_BIT          = LSB_FIRST_BIT + 1;

    // Write logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cmd_config <= {CONFIG_BITS{1'b0}};
        end else if (config_write) begin
            case (config_addr)
                2'd0: cmd_config[31:0]   <= config_data;
                2'd1: cmd_config[63:32]  <= config_data;
            endcase
        end
    end

    // Field extraction using localparams
    assign opcode       = cmd_config[OPCODE_MSB:OPCODE_LSB];
    assign instr_mode   = cmd_config[INSTR_MODE_MSB:INSTR_MODE_LSB];
    assign address      = cmd_config[ADDR_MSB:ADDR_LSB];
    assign addr_mode    = cmd_config[ADDR_MODE_MSB:ADDR_MODE_LSB];
    assign alt_data     = cmd_config[ALT_MSB:ALT_LSB];
    assign alt_mode     = cmd_config[ALT_MODE_MSB:ALT_MODE_LSB];
    assign dummy_cycles = cmd_config[DUMMY_MSB:DUMMY_LSB];
    assign dummy_mode   = cmd_config[DUMMY_MODE_MSB:DUMMY_MODE_LSB];
    assign data_mode    = cmd_config[DATA_MODE_MSB:DATA_MODE_LSB];
    assign lsb_first    = cmd_config[LSB_FIRST_BIT];
    assign dir          = cmd_config[DIR_BIT];

endmodule
