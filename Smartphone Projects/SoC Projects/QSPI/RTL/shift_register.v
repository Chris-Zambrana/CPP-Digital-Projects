`timescale 1ns / 1ps
// qspi_shift_reg.v
// -----------------------------------------------------------------------------
// Bidirectional Shift Register for QSPI Controller
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module shift_reg
 #(
    parameter SHIFT_REG_BITS    = `REG_WIDTH_DEFAULT,
    parameter IO_WIDTH = `IO_WIDTH_DEFAULT
)(
    input  wire                    clk,
    input  wire                    reset,
    input  wire                    lsb_first,
    input  wire                    load,
    input  wire                    drive_strobe,
    input  wire                    sample_strobe,
    input  wire [SHIFT_REG_BITS-1:0]        data_in,
    input  wire [IO_WIDTH-1:0]     io_in,
    input  wire [$clog2(SHIFT_REG_BITS):0] bit_length,
    input wire [2:0]               shift_width,
    
    output reg  [SHIFT_REG_BITS-1:0]        data_out,
    output reg  [IO_WIDTH-1:0]     io_out,
    output wire                    done
);

    reg [SHIFT_REG_BITS-1:0] shift_reg;
    reg [$clog2(SHIFT_REG_BITS):0] bit_count;
    reg [2:0] r_shift_width;
    reg [IO_WIDTH-1:0] masked_io_in;


    assign done = (bit_count == 0);
       
    // Masked input from io_in based on r_shift_width
    always @(*) 
    begin
        case (r_shift_width)
            3'd1: masked_io_in = {{(IO_WIDTH-1){1'b0}}, io_in[0]};
            3'd2: masked_io_in = {{(IO_WIDTH-2){1'b0}}, io_in[1:0]};
            3'd4: masked_io_in = io_in[IO_WIDTH-1:0];
            default: masked_io_in = {{(IO_WIDTH-1){1'b0}}, io_in[0]};
        endcase
    end

    // --- Shift and Load Logic ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg <= {SHIFT_REG_BITS{1'b0}};
            bit_count <= 0;
            r_shift_width <= 1;
        end 
        
        else if (load) begin
            shift_reg <= data_in;
            bit_count <= bit_length;
            r_shift_width <= shift_width;
        end 
        
        else if (bit_count > 0) begin
            if (drive_strobe) begin
                shift_reg <= lsb_first ? shift_reg >> r_shift_width : shift_reg << r_shift_width;
            end 
            
            else if (sample_strobe) begin // DIR_READ
                if (lsb_first) begin
                    shift_reg <= (shift_reg >> r_shift_width) |
                         ({{SHIFT_REG_BITS-IO_WIDTH{1'b0}}, masked_io_in} << (SHIFT_REG_BITS - r_shift_width));
                end 
                else begin
                    shift_reg <= (shift_reg << r_shift_width) | masked_io_in;
                end
            end
        if (drive_strobe || sample_strobe) begin
            if (bit_count >= r_shift_width) begin
                bit_count <= bit_count - r_shift_width;
            end
            else begin
                bit_count <= 0;
            end
        end    
        end
    end

    // --- Output Bit Slice for IO Bus ---
    integer i;
    always @(*) begin
        io_out = {IO_WIDTH{1'b0}};
        if (lsb_first) begin
                io_out = shift_reg[IO_WIDTH-1:0];
        end else begin
            for (i = 0; i < IO_WIDTH; i = i + 1) begin
                if (i < r_shift_width)
                    io_out[i] = shift_reg[SHIFT_REG_BITS - 1 - i];
            end
        end
    end
    
    // --- Capture Output Word at End of Read ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_out <= 0;
        end else begin
            data_out <= shift_reg;
        end
    end

endmodule

