`timescale 1ns / 1ps
// qspi_shift_logic.v
// -----------------------------------------------------------------------------
// Bidirectional Shift logicister for QSPI Controller
// -----------------------------------------------------------------------------
import qspi_types_pkg::*;

`include "qspi_definitions.vh"

module qspi_shift_reg #(
    parameter QSPI_DATA_WIDTH = `QSPI_DATA_WIDTH
)
(
    input  logic clk,
    input  logic reset,

    // register to shift register signals
    input  logic lsb_first,

    // controller to shift register signals
    input  logic [2:0] bus_width,
    input  logic shift_tx_load,
    input  logic [QSPI_DATA_WIDTH-1:0] shift_tx_byte,
    input  logic shift_rx_en,
    input  rate_type rate,

    // SCK generator to shift register signals
    input  logic drive_tick,
    input  logic sample_tick,
    input  logic edge_tick,

    // IO control to shift register signals
    input  logic [3:0] io_rx,

    // shift register to controller signals
    output logic shift_tx_byte_done,
    output logic shift_rx_byte_ready,
    output logic [QSPI_DATA_WIDTH-1:0] shift_rx_byte,

    // shift register to IO control signals
    output logic  [3:0] io_tx
);

typedef enum logic [1:0] {
    SHIFT_IDLE,     
    SHIFT_DDR,
    SHIFT_SDR
} shift_state_type;

shift_state_type state_reg, state_next;
logic [QSPI_DATA_WIDTH-1:0] tx_reg, tx_next, rx_reg, rx_next;
logic [3:0] io_tx_reg, io_tx_next;
logic [$clog2(QSPI_DATA_WIDTH):0] bit_cnt_reg, bit_cnt_next;
logic [2:0] shift_width_reg, shift_width_next, active_width;
logic tx_byte_done_reg, tx_byte_done_next, rx_byte_ready_reg, rx_byte_ready_next;
logic rx_next_start, tx_next_start;
logic tx_flag_reg, tx_flag_next, rx_flag_reg, rx_flag_next;
logic ddr_tx_first_edge_reg, ddr_tx_first_edge_next;

rate_type active_rate;
rate_type rate_type_reg, rate_type_next;

function automatic logic [3:0] get_io_tx; 
    input logic [QSPI_DATA_WIDTH-1:0] tx_data;
    input logic [2:0] bus_width;
    input logic lsb_first;

    begin
        case (bus_width)
            3'd1:  get_io_tx = lsb_first ? {3'b000, tx_data[0]} : {3'b000, tx_data[QSPI_DATA_WIDTH-1]};
            3'd2:  get_io_tx = lsb_first ? {2'b00, tx_data[1:0]} : {2'b00, tx_data[QSPI_DATA_WIDTH-1:QSPI_DATA_WIDTH-2]};
            3'd4:  get_io_tx = lsb_first ? tx_data[3:0] : tx_data[QSPI_DATA_WIDTH-1:QSPI_DATA_WIDTH-4];
            default: get_io_tx = 0;
        endcase
    end
endfunction

function automatic logic [QSPI_DATA_WIDTH-1:0] get_io_rx; 
    input logic [QSPI_DATA_WIDTH-1:0] rx_data;
    input logic [3:0] io_rx;
    input logic [2:0] bus_width;
    input logic lsb_first;

    begin
        case (bus_width)
            3'd1:  get_io_rx = lsb_first ? ({io_rx[1],rx_data[(QSPI_DATA_WIDTH-1):1]}) : ({rx_data[(QSPI_DATA_WIDTH-2):0], io_rx[1]});
            3'd2:  get_io_rx = lsb_first ? ({io_rx[1:0],rx_data[(QSPI_DATA_WIDTH-1):2]}) : ({rx_data[(QSPI_DATA_WIDTH-3):0], io_rx[1:0]});
            3'd4:  get_io_rx = lsb_first ? ({io_rx,rx_data[(QSPI_DATA_WIDTH-1):4]}) : ({rx_data[(QSPI_DATA_WIDTH-5):0], io_rx});
            default: get_io_rx = 0;
        endcase
    end
endfunction

function automatic logic [QSPI_DATA_WIDTH-1:0] shift_tx; 
    input logic [QSPI_DATA_WIDTH-1:0] tx_data;
    input logic [2:0] bus_width;
    input logic lsb_first;

    begin
        shift_tx = lsb_first ? (tx_data >> bus_width) : (tx_data << bus_width);
    end
endfunction

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        tx_reg <= 0;
        io_tx_reg <= 0;
        rx_reg <= 0;
        bit_cnt_reg <= 0;
        tx_byte_done_reg <= 0;
        rx_byte_ready_reg <= 0;
        tx_flag_reg <= 1'b0; // indicate that we are not transmitting
        rx_flag_reg <= 1'b0; // indicate that we are not receiving
        ddr_tx_first_edge_reg <= 1'b0;
        state_reg <= SHIFT_IDLE;
        shift_width_reg <= 0;
        rate_type_reg <= RATE_SDR; // default to SDR on reset
    end else begin
        bit_cnt_reg <= bit_cnt_next;
        state_reg <= state_next;
        tx_byte_done_reg <= tx_byte_done_next;
        rx_byte_ready_reg <= rx_byte_ready_next;
        io_tx_reg <= io_tx_next;
        rx_reg <= rx_next;
        tx_reg <= tx_next;
        shift_width_reg <= shift_width_next;
        tx_flag_reg <= tx_flag_next;
        rx_flag_reg <= rx_flag_next;
        ddr_tx_first_edge_reg <= ddr_tx_first_edge_next;
        rate_type_reg <= rate_type_next;
    end
end

always_comb begin : shift_logic
    io_tx_next = io_tx_reg;
    rx_next = rx_reg;
    tx_next = tx_reg;
    shift_width_next = shift_width_reg;
    rate_type_next = rate_type_reg;
    ddr_tx_first_edge_next = ddr_tx_first_edge_reg;
    active_rate = rate_type_reg;

    if(tx_next_start || rx_next_start) begin
        active_rate = rate;
    end

    if(tx_next_start) begin
        // The first DDR address group follows the SDR instruction. It is
        // already loaded before the falling edge that ends the instruction;
        // hold it through that edge so the flash samples it on the next rise.
        ddr_tx_first_edge_next = (active_rate == RATE_DDR &&
                                  rate_type_reg != RATE_DDR);
        if(active_rate == RATE_DDR) begin
            io_tx_next = get_io_tx(shift_tx_byte, active_width, lsb_first); // load the shift register with the new byte to transmit
            tx_next = shift_tx(shift_tx_byte, active_width, lsb_first); // shift the tx register for the next drive tick
        end else begin 
            tx_next = shift_tx_byte; // load the shift register with the new byte to transmit
        end 
        shift_width_next = bus_width; // set the shift width for the first drive tick
        rate_type_next = rate; // set the DDR enable for the first drive tick
    end else if(rx_next_start) begin
        rx_next = 0; // clear the receive register at the start of a transaction
        shift_width_next = bus_width; // set the shift width for the first drive tick
        rate_type_next = rate; // set the DDR enable for the first drive tick
    end else if(state_reg == SHIFT_DDR && edge_tick && ddr_tx_first_edge_reg) begin
        // This is the instruction-to-DDR boundary edge, not a data sample.
        // Keep the preloaded first DDR output group stable across it.
        ddr_tx_first_edge_next = 1'b0;
    end else if(state_reg == SHIFT_DDR && edge_tick) begin
            io_tx_next = get_io_tx(tx_reg, active_width, lsb_first); // load the shift register with the new byte to transmit
            rx_next = get_io_rx(rx_reg, io_rx, active_width, lsb_first); // shift the rx register for the next sample tick
            tx_next = shift_tx(tx_reg, active_width, lsb_first); // shift the
    end else begin
        if (state_reg == SHIFT_SDR && drive_tick) begin
            io_tx_next = get_io_tx(tx_reg, active_width, lsb_first); // load the shift register with the new byte to transmit
            tx_next = shift_tx(tx_reg, active_width, lsb_first); // shift the
        end else if (state_reg == SHIFT_SDR && sample_tick) begin
            rx_next = get_io_rx(rx_reg, io_rx, active_width, lsb_first); // shift the rx register for the next sample tick
        end
    end
end

always_comb begin : FSM
    bit_cnt_next = bit_cnt_reg;
    state_next = state_reg;
    tx_byte_done_next = 1'b0;
    rx_byte_ready_next = 1'b0;
    tx_flag_next = tx_flag_reg; // default to transmitting
    rx_flag_next = rx_flag_reg; // default to not transmitting

    case (state_reg)
        SHIFT_IDLE: begin
            bit_cnt_next = 0; // reset bit counter
            tx_flag_next = 1'b0; // indicate that we are not transmitting
            rx_flag_next = 1'b0; // indicate that we are not receiving

            if(shift_tx_load) begin       
                if(active_rate == RATE_DDR) begin
                    state_next = SHIFT_DDR;
                    bit_cnt_next = bit_cnt_reg + active_width; // increment bit counter
                end else begin
                    state_next = SHIFT_SDR;
                end
                tx_flag_next = 1'b1; // indicate that we are transmitting
            end else if(shift_rx_en) begin
                if(active_rate == RATE_DDR) begin
                    state_next = SHIFT_DDR;
                    bit_cnt_next = bit_cnt_reg + active_width; // increment bit counter
                end else begin
                    state_next = SHIFT_SDR;
                end
                rx_flag_next = 1'b1; // indicate that we are not transmitting
            end
        end

        SHIFT_DDR: begin
            // shift logic for data phase, including handling of shift_tx_load 
            // when first entering phase we are still in last phase's last sampling half cycle, but the drive_tick conditional will not be met until the next half cycle, so we can use the same logic as the instruction phase
            if(edge_tick) begin
                // The first edge after a DDR TX start only launches the
                // preloaded group; do not count it as a sampled transfer.
                if (ddr_tx_first_edge_reg) begin
                    bit_cnt_next = bit_cnt_reg;
                end else if(bit_cnt_reg >= QSPI_DATA_WIDTH) begin
                    if(tx_flag_reg) begin
                        tx_byte_done_next = 1'b1; // byte transmission done
                        tx_flag_next = 1'b0; // indicate that we are not transmitting
                    end else if(rx_flag_reg) begin
                        rx_byte_ready_next = 1'b1; // byte reception done
                        rx_flag_next = 1'b0; // indicate that we are not receiving
                    end
                    bit_cnt_next = 0; // reset bit counter for next byte
                    state_next = SHIFT_IDLE; // transition back to SHIFT_IDLE after transmission
                end else begin
                    bit_cnt_next = bit_cnt_reg + active_width; // increment bit counter
                end
            end
        end

        SHIFT_SDR: begin
            // shift logic for data phase, including handling of shift_rx_en
            // when first entering phase we are still in last phase's last sampling half cycle, but the drive_tick conditional will not be met until the next half cycle, so we can use the same logic as the instruction phase\
            if(drive_tick) begin
                bit_cnt_next = bit_cnt_reg + active_width; // increment bit counter
            end else if(sample_tick) begin
                // determine number of bits already shifted out and transition to next phase if a byte has been fully transmitted
                if(bit_cnt_reg >= QSPI_DATA_WIDTH) begin
                    if(tx_flag_reg) begin
                        tx_byte_done_next = 1'b1; // byte transmission done
                        tx_flag_next = 1'b0; // indicate that we are not transmitting
                    end else if(rx_flag_reg) begin
                        rx_byte_ready_next = 1'b1; // byte reception done
                        rx_flag_next = 1'b0; // indicate that we are not receiving
                    end
                    bit_cnt_next = 0; // reset bit counter for next byte
                    state_next = SHIFT_IDLE; // transition back to SHIFT_IDLE after transmission
                end 
            end 

        end
        default: begin
            // default case (should not happen)
            bit_cnt_next = 0; // reset bit counter
            rx_byte_ready_next = 1'b0; // reset byte ready flag
            tx_byte_done_next = 1'b0; // reset byte done flag
            tx_flag_next = 1'b0; // indicate that we are not transmitting
            rx_flag_next = 1'b0; // indicate that we are not receiving
            state_next = SHIFT_IDLE; // transition back to SHIFT_IDLE
        end
    endcase
    
end


assign active_width = ((state_reg == SHIFT_IDLE) && (shift_tx_load || shift_rx_en)) ? bus_width : shift_width_reg;
assign tx_next_start = shift_tx_load && (state_reg == SHIFT_IDLE); // transaction starts when either load or receive is asserted in SHIFT_IDLE state and drive_tick is high
assign rx_next_start = shift_rx_en && (state_reg == SHIFT_IDLE); // transaction starts when either load or receive is asserted in SHIFT_IDLE state and drive_tick is high

assign shift_tx_byte_done = tx_byte_done_reg;
assign shift_rx_byte_ready = rx_byte_ready_reg;
assign shift_rx_byte = rx_reg;
assign io_tx = io_tx_reg;

endmodule

