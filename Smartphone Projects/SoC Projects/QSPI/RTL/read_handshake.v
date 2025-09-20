`timescale 1ns / 1ps

module read_handshake 
#(
    parameter DATA_BITS = 32
)
(
    input  wire              clk,
    input  wire              reset,
    input  wire              enable,        // High when read data is ready
    input  wire              data_ready,    // From firmware
    input  wire [DATA_BITS-1:0] data_in,    // From shift register
    output reg  [DATA_BITS-1:0] rx_data,    // To firmware
    output reg               data_valid     // Goes high when data is available
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_data    <= {DATA_BITS{1'b0}};
            data_valid <= 1'b0;
        end else begin
            if (enable && !data_valid) begin
                rx_data    <= data_in;
                data_valid <= 1'b1;
            end else if (data_valid && data_ready) begin
                data_valid <= 1'b0; // handshake complete
            end
        end
    end

endmodule