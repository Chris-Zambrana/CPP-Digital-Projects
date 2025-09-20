`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Write Handshake Module
// -----------------------------------------------------------------------------
module write_handshake 
#(
    parameter DATA_BITS = 32
)
(
    input  wire              clk,
    input  wire              reset,
    input  wire              enable,        // High during PHASE_DATA + DIR_WRITE
    input  wire              tx_valid,      // From firmware/DMA
    input  wire [DATA_BITS-1:0] tx_data,    // From firmware/DMA
    output reg  [DATA_BITS-1:0] data_out,   // Output to shift register
    output reg               load_data,     // Pulsed when data is transferred
    output reg               tx_ready       // Controller requests new data
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_out  <= {DATA_BITS{1'b0}};
            load_data <= 1'b0;
            tx_ready  <= 1'b0;
        end else begin
            load_data <= 1'b0; // default
            if (enable) begin
                tx_ready <= 1'b1;
                if (tx_valid) begin
                    data_out  <= tx_data;
                    load_data <= 1'b1;
                end
            end else begin
                tx_ready <= 1'b0;
            end
        end
    end

endmodule