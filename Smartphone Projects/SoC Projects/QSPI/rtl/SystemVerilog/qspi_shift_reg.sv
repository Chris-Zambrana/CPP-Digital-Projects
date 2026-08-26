`timescale 1ns / 1ps
// qspi_shift_logic.v
// -----------------------------------------------------------------------------
// Bidirectional Shift logicister for QSPI Controller
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_shift_reg #(
    parameter DATA_BITS = `DATA_BITS
)
(
    input  logic clk,
    input  logic reset,

    // register to shift register signals
    input  logic soft_reset,
    input  logic lsb_first,

    // controller to shift register signals
    input  logic [3:0] phase,
    input  logic [2:0] current_bus_width,
    input  logic shift_tx_load,
    input  logic [DATA_BITS-1:0] shift_tx_byte,
    input  logic shift_rx_en,

    // SCK generator to shift register signals
    input  logic drive_tick,
    input  logic sample_tick,

    // IO control to shift register signals
    input  logic [3:0] io_rx,

    // shift register to controller signals
    output logic shift_tx_byte_done,
    output logic shift_rx_byte_ready,
    output logic [DATA_BITS-1:0] shift_rx_byte,

    // shift register to IO control signals
    output logic  [3:0] io_tx
);

typedef enum {
    IDLE,             
    TX_SHIFT,    
    RX_SHIFT        
} state_type;

state_type state_reg, state_next;
logic [DATA_BITS-1:0] tx_reg, tx_next;
logic [3:0] io_tx_reg, io_rx_reg;
logic [$clog2(DATA_BITS):0] bit_cnt_reg, bit_cnt_next;
logic tx_byte_done_reg, tx_byte_done_next, rx_byte_ready_reg, rx_byte_ready_next;
logic initial_transaction_start;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        tx_reg <= 0;
        io_tx_reg <= 0;
        io_rx_reg <= 0;
        bit_cnt_reg <= 0;
        state_reg <= IDLE;
    end else if (soft_reset) begin
        tx_reg <= 0;
        io_tx_reg <= 0;
        io_rx_reg <= 0;
        bit_cnt_reg <= 0;
        state_reg <= IDLE;
    end else begin
        bit_cnt_reg <= bit_cnt_next;
        state_reg <= state_next;
        tx_byte_done_reg <= tx_byte_done_next;
        rx_byte_ready_reg <= rx_byte_ready_next;
        io_tx_reg <= io_tx_next;
        io_rx_reg <= io_rx_next; // clear the receive register at the start of a transaction
        tx_reg <= tx_next;
    end
end

always_comb begin
    io_tx_next = io_tx_reg;
    io_rx_next = io_rx_reg;
    tx_next = tx_reg;

    if(initial_transaction_start) begin
        io_rx_next = 0; // clear the receive register at the start of a transaction
        case (current_bus_width)
            3'b001:  io_tx_next <= lsb_first ? {3'b000, shift_tx_byte[0]} : {3'b000, shift_tx_byte[DATA_BITS-1]};
            3'b010:  io_tx_next <= lsb_first ? {2'b00, shift_tx_byte[1:0]} : {2'b00, shift_tx_byte[DATA_BITS-1:DATA_BITS-2]};
            3'b100:  io_tx_next <= lsb_first ? shift_tx_byte[3:0] : shift_tx_byte[DATA_BITS-1:DATA_BITS-4];
            default: io_tx_next <= 0;
        endcase

        tx_next = lsb_first ? (shift_tx_byte >> current_bus_width) : (shift_tx_byte << current_bus_width);

    end else if (next_phase_start) begin
        io_rx_next = 0; // clear the receive register at the start of a transaction
        tx_next = shift_tx_byte; // load the shift register with the new byte to transmit
    end else if (drive_tick) begin
        case (current_bus_width)
            3'b001:  io_tx_next = lsb_first ? {3'b000, tx_reg[0]} : {3'b000, tx_reg[DATA_BITS-1]};
            3'b010:  io_tx_next = lsb_first ? {2'b00, tx_reg[1:0]} : {2'b00, tx_reg[DATA_BITS-1:DATA_BITS-2]};
            3'b100:  io_tx_next = lsb_first ? tx_reg[3:0] : tx_reg[DATA_BITS-1:DATA_BITS-4];
            default: io_tx_next = 0;
        endcase

        tx_next = lsb_first ? (tx_reg >> current_bus_width) : (tx_reg << current_bus_width);

    end else if(sample_tick) begin
        case (current_bus_width)
            3'b001:  io_rx_next <= lsb_first ? ({io_rx[1],rx_reg[(DATA_BITS-1):1]}) : ({rx_reg[(DATA_BITS-2):0], io_rx[1]});
            3'b010:  io_rx_next <= lsb_first ? ({io_rx[1:0],rx_reg[(DATA_BITS-1):2]}) : ({rx_reg[(DATA_BITS-3):0], io_rx[1:0]});
            3'b100:  io_rx_next <= lsb_first ? ({io_rx,rx_reg[(DATA_BITS-1):4]}) : ({rx_reg[(DATA_BITS-5):0], io_rx});
            default: io_rx_next <= 0;
        endcase
    end
end

always_comb begin 
    bit_cnt_next = bit_cnt_reg;
    state_next = state_reg;
    tx_byte_done_next = tx_byte_done_reg;
    rx_byte_ready_next = rx_byte_ready_reg;

    case (state_reg)
        IDLE: begin
            bit_cnt_next = 0;
            
            if(shift_tx_load) begin       
                state_next = TX_SHIFT; // transition to transmit state
            end else if(shift_rx_en) begin
                state_next = RX_SHIFT; // transition to receive state
            end

        end
        TX_SHIFT: begin
            // shift logic for data phase, including handling of shift_tx_load 
            // when first entering phase we are still in last phase's last sampling half cycle, but the drive_tick conditional will not be met until the next half cycle, so we can use the same logic as the instruction phase
            if(drive_tick) begin
                // shift out bits based on current_bus_width
                tx_byte_done_next = 0; // reset byte done flag
                bit_cnt_next = bit_cnt_reg + current_bus_width; // increment bit counter
            end else if(sample_tick) begin
                // determine number of bits already shifted out and transition to next phase if a byte has been fully transmitted
                if(bit_cnt_reg >= DATA_BITS) begin
                    tx_byte_done_next = 1; // byte transmission done
                    bit_cnt_next = 0; // reset bit counter for next byte
                    state_next = IDLE; // transition back to IDLE after transmission
                end 
            end
        end
        RX_SHIFT: begin
            // shift logic for data phase, including handling of shift_rx_en
            // when first entering phase we are still in last phase's last sampling half cycle, but the drive_tick conditional will not be met until the next half cycle, so we can use the same logic as the instruction phase\
            if(drive_tick) begin
                rx_byte_ready_next = 0; // reset byte ready flag
                bit_cnt_next = bit_cnt_reg + current_bus_width; // increment bit counter
            end else if(sample_tick) begin
                // shift out bits based on current_bus_width

                // determine number of bits already shifted out and transition to next phase if a byte has been fully transmitted
                if(bit_cnt_reg >= DATA_BITS) begin
                    rx_byte_ready_next = 1; // byte transmission done
                    bit_cnt_next = 0; // reset bit counter for next byte
                    state_next = IDLE; // transition back to IDLE after transmission
                end 
            end 

        end
        default: begin
            // default case (should not happen)
            bit_cnt_next = 0; // reset bit counter
            rx_byte_ready_next = 0; // reset byte ready flag
            tx_byte_done_next = 0; // reset byte done flag
            state_next = IDLE; // transition back to IDLE
        end
    endcase
    
end

assign next_phase_start = (shift_tx_load || shift_rx_en) && (state_reg == IDLE); // transaction starts when either load or receive is asserted in IDLE state and drive_tick is high
assign initial_transaction_start = (shift_tx_load || shift_rx_en) && (state_reg == IDLE) && drive_tick; // transaction starts when either load or receive is asserted in IDLE state and drive_tick is high
assign shift_tx_byte_done = tx_byte_done_reg;
assign shift_rx_byte_ready = rx_byte_ready_reg;
assign shift_rx_byte = io_rx_reg;
assign io_tx = io_tx_reg;

endmodule

