`timescale 1ns / 1ps
// qspi_controller.v
// -----------------------------------------------------------------------------
// QSPI Master Controller with Instruction, Address, Alternate, Dummy, and Data
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_controller 
#(
    parameter MAX_ADDR_BITS = `MAX_ADDR_BITS,
    parameter QSPI_SLAVE_COUNT = 4,
    parameter CONST_DATA_LEN = `CONST_DATA_LEN,
    parameter DUMMY_COUNT = `DUMMY_COUNT,
    parameter MODE_CYCLE_COUNT = `MODE_CYCLE_COUNT,
    parameter MODE_BITS = `MODE_BITS,    
    parameter DATA_BITS = `DATA_BITS,
    parameter MAX_PHASES = 16
) 
(
    // system level signals
    input  logic        clk,
    input  logic        reset,

    // register to controller signals
    input logic start,
    input logic soft_reset,
    input logic [7:0] opcode,
    input logic has_addr,
    input logic has_mode,
    input logic has_dummy,
    input logic has_tx_data,
    input logic has_rx_data,
    input logic [1:0] addr_bit_width,
    input logic [1:0] cmd_io_width,
    input logic [1:0] addr_io_width,
    input logic [1:0] mode_io_width,
    input logic [1:0] data_io_width,
    input logic [MAX_ADDR_BITS-1:0] flash_addr,
    input logic [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num,
    input logic [CONST_DATA_LEN-1:0] tx_len,
    input logic [CONST_DATA_LEN-1:0] rx_len,
    input logic [DUMMY_COUNT-1:0] dummy_cycles,
    input logic [MODE_CYCLE_COUNT-1:0] mode_cycles,
    input logic [MODE_BITS-1:0] mode_bits,

    // shift register to controller signals
    input logic shift_tx_byte_done,
    input logic shift_rx_byte_ready,
    input logic [DATA_BITS-1:0] shift_rx_byte,

    // fifo to controller signals
    input logic fifo_tx_empty,
    input logic [DATA_BITS-1:0] fifo_tx_rbyte,
    input logic fifo_rx_full,

    // sclk gen to controller signals
    input logic drive_tick,
    input logic sample_tick,
    input logic sclk_idle,

    // controller to register signals
    output logic ready,
    output logic done,
    output logic error,

    // controller to top-level flash interface signals
    output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,

    // controller to clock generator signals
    output logic sclk_en,

    // controller to shift register signals
    output logic [3:0] phase,
    output logic [2:0] current_bus_width,
    output logic shift_tx_load,
    output logic [DATA_BITS-1:0] shift_tx_byte,
    output logic shift_rx_en,

    // controller to fifo signals
    output logic fifo_tx_rd,
    output logic fifo_rx_wr,
    output logic [DATA_BITS-1:0] fifo_rx_wbyte

);  


typedef enum logic [3:0] {
    IDLE        = 4'b0000,
    CS_SETUP    = 4'b0001,
    INSTRUCTION = 4'b0010,
    ADDRESS     = 4'b0011,
    MODE        = 4'b0100,
    DUMMY       = 4'b0101,
    TX_DATA     = 4'b0110,
    RX_DATA     = 4'b0111,
    CS_HOLD     = 4'b1000
} state_type;

state_type state_reg, state_next;
state_type phase_order_reg [MAX_PHASES]; 
state_type phase_order_calc [MAX_PHASES];
logic [31:0] data_order_reg [MAX_PHASES];
logic [31:0] data_order_calc [MAX_PHASES];
logic [2:0] io_width_reg [MAX_PHASES];
logic [2:0] io_width_calc [MAX_PHASES];

logic [$clog2(MAX_PHASES)-1:0] phase_idx_reg, phase_idx_next;
logic [$clog2(MAX_PHASES+1)-1:0] phase_count_reg, phase_count_total, build_idx;
logic ready_o, done_o, error_o;
logic sclk_en_o;
logic start_accept;
logic [2:0] current_bus_width_o, io_width_next, io_width_reg;
logic shift_tx_load_o, shift_rx_en_o;
logic [DATA_BITS-1:0] shift_tx_byte_o, tx_next, tx_reg;
logic fifo_tx_rd_o, fifo_rx_wr_o;
logic [DATA_BITS-1:0] fifo_rx_wbyte_o;
logic [7:0] tx_byte_cnt, tx_byte_cnt_next, rx_byte_cnt, rx_byte_cnt_next;
logic [3:0] addr_byte_cnt, addr_byte_cnt_calc;

logic [$clog2(QSPI_SLAVE_COUNT)-1:0] cs_num_reg;
logic [CONST_DATA_LEN-1:0] tx_len_reg, rx_len_reg;
logic [DUMMY_COUNT-1:0] dummy_cycles_reg, dummy_cycles_cnt, dummy_cycles_cnt_next;
logic [MODE_CYCLE_COUNT-1:0] mode_cycles_reg;


always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        state_reg <= IDLE;

        cs_num_reg <= 0; // latch chip select number
        tx_len_reg <= 0; // latch tx length
        rx_len_reg <= 0; // latch rx length
        dummy_cycles_reg <= 0; // latch dummy cycles
        mode_cycles_reg <= 0; // latch mode cycles
        addr_byte_cnt <= 0; // latch address byte count
        
        phase_count_reg <= 0; // latch phase count
        phase_idx_reg <= 0; // latch phase index

        for (int i = 0; i <= MAX_PHASES-1; i++) begin
            phase_order_reg[i] <= IDLE;
            data_order_reg[i] <= 0;
            io_width_reg[i] <= 0;
        end

    end else if (soft_reset) begin
        state_reg <= IDLE;

        cs_num_reg <= 0; // latch chip select number
        tx_len_reg <= 0; // latch tx length
        rx_len_reg <= 0; // latch rx length
        dummy_cycles_reg <= 0; // latch dummy cycles
        mode_cycles_reg <= 0; // latch mode cycles
        addr_byte_cnt <= 0; // latch address byte count

        phase_count_reg <= 0; // latch phase count
        phase_idx_reg <= 0; // latch phase index

        for (int i = 0; i <= MAX_PHASES-1; i++) begin
            phase_order_reg[i] <= IDLE;
            data_order_reg[i] <= 0;
            io_width_reg[i] <= 0;
        end


    end else begin
        state_reg <= state_next;

        if(start_accept) begin
            // latch all command parameters from registers to internal registers
                cs_num_reg <= cs_num; // latch chip select number
                tx_len_reg <= tx_len; // latch tx length
                rx_len_reg <= rx_len; // latch rx length
                dummy_cycles_reg <= dummy_cycles; // latch dummy cycles
                mode_cycles_reg <= mode_cycles; // latch mode cycles
                addr_byte_cnt <= addr_byte_cnt_calc; // latch address byte count

                for (int i = 0; i <= MAX_PHASES-1; i++) begin
                    phase_order_reg[i] <= phase_order_calc[i];
                    data_order_reg[i] <= data_order_calc[i];
                    io_width_reg[i] <= io_width_calc[i];
                end
                phase_count_reg <= phase_count_total; // latch phase count
                phase_idx_reg <= 0; // reset phase index for new command

                tx_reg <= data_order_calc[0][DATA_BITS-1:0]; // load opcode into shift register
                io_width_reg <= io_width_calc[0]; // set bus width for command phase
        end else begin
            phase_idx_reg <= phase_idx_next; // update phase index for current command
            tx_reg <= tx_next;
            io_width_reg <= io_width_next;
        end
    end
end

always_comb begin
    phase_order_calc  = phase_order_reg;
    data_order_calc = data_order_reg;
    io_width_calc = io_width_reg;
    phase_count_total = phase_count_reg;
    build_idx        = 0;

    if (start_accept) begin
        phase_order_calc[build_idx] = INSTRUCTION;
        data_order_calc[build_idx] = opcode; // INSTRUCTION phase has no byte order
        io_width_calc[build_idx] = cmd_io_width; // INSTRUCTION phase bus width
        build_idx = build_idx + 1;

        if (has_addr) begin
            phase_order_calc[build_idx] = ADDRESS;
            data_order_calc[build_idx] = flash_addr; // ADDRESS phase has byte order from flash address
            io_width_calc[build_idx] = addr_io_width; // ADDRESS phase bus width
            build_idx = build_idx + 1;

            case(addr_bit_width) 
                1: addr_byte_cnt_calc = 3; // 24-bit address
                2: addr_byte_cnt_calc = 4; // 32-bit address
                default: addr_byte_cnt_calc = 0; // default to 24-bit address
            endcase
        end

        if (has_mode) begin
            phase_order_calc[build_idx] = MODE;
            data_order_calc[build_idx] = mode_bits; // MODE phase has byte order from mode bits
            io_width_calc[build_idx] = mode_io_width; // MODE phase bus width
            build_idx = build_idx + 1;
        end

        if (has_dummy) begin
            phase_order_calc[build_idx] = DUMMY;
            data_order_calc[build_idx] = 0; // DUMMY phase has no byte to transmit, so no byte order
            io_width_calc[build_idx] = 0; // DUMMY phase has no bus width
            build_idx = build_idx + 1;
        end

        if (has_rx_data) begin
            phase_order_calc[build_idx] = RX_DATA;
            data_order_calc[build_idx] = 0; // RX_DATA phase has no byte to transmit, so no byte order
            io_width_calc[build_idx] = data_io_width; // RX_DATA phase has no bus width
            build_idx = build_idx + 1;
        end else if (has_tx_data) begin
            phase_order_calc[build_idx] = TX_DATA;
            data_order_calc[build_idx] = 0; // TX_DATA phase has bytes to transmit, but that will be provided by the FIFO 
            io_width_calc[build_idx] = data_io_width; // TX_DATA phase has no bus width
            build_idx = build_idx + 1;
        end

        phase_order_calc[build_idx] = CS_HOLD;  
        data_order_calc[build_idx] = 0; // CS_HOLD phase has no byte to transmit, so no byte order
        io_width_calc[build_idx] = 0; // CS_HOLD phase has no
        build_idx = build_idx + 1;

        phase_count_total = build_idx;
    end
end

always_comb begin
    state_next = state_reg;
    phase_idx_next = phase_idx_reg;
    rx_byte_cnt_next = rx_byte_cnt;
    tx_byte_cnt_next = tx_byte_cnt;
    ready_o = 0;
    done_o = 0;
    error_o = 0;
    shift_tx_load_o = 0;
    shift_rx_en_o = 0;
    sclk_en_o = 0;

    case(state_reg)
        IDLE: begin
            ready_o = 1; // ready to accept new command in IDLE state
            if (start) begin
                phase_idx_next = 0; // reset phase index for new command
                state_next = CS_SETUP; // transition to CS_SETUP state
            end else begin
                state_next = IDLE;
            end
        end

        CS_SETUP: begin
            sclk_en_o = 1; // disable clock during CS setup
            shift_tx_load_o = 1; // load instruction into shift register at start
            phase_idx_next = phase_idx_reg + 1; // increment phase index
            tx_next = data_order_reg[phase_idx_next][DATA_BITS-1:0]; // load opcode into shift register
            io_width_next = io_width_reg[phase_idx_next]; // set bus width for command phase
            state_next = phase_order_reg[phase_idx_reg]; // transition to INSTRUCTION phase after CS setup
        end

        INSTRUCTION: begin
            sclk_en_o = 1; // enable clock for shifting instruction
            // logic to transition to next state based on has_addr, has_mode, etc.

            if(shift_tx_byte_done) begin
                shift_tx_load_o = 1; // load next byte into shift register
                phase_idx_next = phase_idx_reg + 1; // increment phase index
                tx_next = data_order_reg[phase_idx_next][DATA_BITS-1:0]; // load opcode into shift register
                io_width_next = io_width_reg[phase_idx_next]; // set bus width for command phase
                state_next = phase_order_reg[phase_index_reg]; // transition to INSTRUCTION phase after CS setup

                if(state_next == CS_HOLD) begin
                    sclk_en_o = 0; // disable clock when no further phases
                end
            end

        end
        ADDRESS: begin
            sclk_en_o = 1; // enable clock for shifting address
            // logic to transition to next state based on has_mode, has_dummy, etc.
            if(shift_tx_byte_done) begin
                tx_byte_cnt_next = tx_byte_cnt + 1; // increment tx byte counter
                if(tx_byte_cnt_next == addr_byte_cnt) begin
                    phase_idx_next = phase_idx_reg + 1; // increment phase index
                    tx_next = data_order_reg[phase_idx_next]; // load opcode into shift register
                    io_width_next = io_width_reg[phase_idx_next]; // set bus width for command phase
                    state_next = phase_order_reg[phase_idx_next]; // transition to INSTRUCTION phase after CS setup
                    
                    if(state_next == CS_HOLD) begin
                        sclk_en_o = 0; // disable clock when no further phases
                    end
                end else begin
                    tx_next = data_order_reg[phase_idx_reg] [8 +: 8]; // load next address byte into shift register
                    state_next = ADDRESS; // stay in ADDRESS phase until all bytes are transmitted
                end
            end
        end
        MODE: begin
            sclk_en_o = 1; // enable clock for shifting mode bits
            // logic to transition to next state based on has_dummy, has_tx_data, has_rx_data, etc.
            state_next = MODE; // stay in INSTRUCTION phase until done
            if (has_dummy_reg) begin
                phase_next = DUMMY;
            end else if (has_rx_data_reg) begin
                phase_next = RX_DATA;
                current_bus_width_o = data_io_width_reg;
                rx_byte_cnt_next = 0; // reset rx byte counter for data phase
            end else if (has_tx_data_reg) begin
                phase_next = TX_DATA;
                // shift_tx_rd_o = 1; // FWFT FIFO will have tx data ready immediately
                shift_tx_byte_o = fifo_tx_rbyte;
                current_bus_width_o = data_io_width_reg;
                tx_byte_cnt_next = 0; // reset tx byte counter for data phase
            end else begin
                phase_next = CS_HOLD; // no further phases, go back to CS_HOLD
            end
            
            if(shift_tx_byte_done) begin
                state_next = phase_next; // transition to next phase when instruction is done
                if(phase_next == CS_HOLD) begin
                    sclk_en_o = 0; // disable clock when no further phases
                end
            end 
        end
        DUMMY: begin
            sclk_en_o = 1; // enable clock for shifting address
            state_next = DUMMY; // stay in DUMMY phase until done
            // logic to transition to next state based on has_tx_data, has_rx_data, etc.
            if (has_rx_data_reg) begin
                phase_next = RX_DATA;
                current_bus_width_o = data_io_width_reg;
                rx_byte_cnt_next = 0; // reset rx byte counter for data phase
            end else if (has_tx_data_reg) begin
                phase_next = TX_DATA;
                // shift_tx_rd_o = 1; // FWFT FIFO will have tx data ready immediately
                shift_tx_byte_o = fifo_tx_rbyte;
                current_bus_width_o = data_io_width_reg;
                tx_byte_cnt_next = 0; // reset tx byte counter for data phase
            end else begin
                phase_next = CS_HOLD; // no further phases, go back to CS_HOLD
            end
            
            if(sample_tick) begin
                dummy_cycles_cnt_next = dummy_cycles_cnt + 1; // increment dummy cycle counter
                if(dummy_cycles_cnt_next >= dummy_cycles_reg) begin
                    state_next = phase_next; // transition to next phase when dummy cycles are done
                    if(phase_next == CS_HOLD) begin
                        sclk_en_o = 0; // disable clock when no further phases
                    end
                end 
            end 
        end
        TX_DATA: begin
            sclk_en_o = 1; // enable clock for shifting address
            // logic to transition back to IDLE when data transfer is complete
            state_next = TX_DATA; // stay in TX_DATA phase until done
            if(shift_tx_byte_done) begin
                tx_byte_cnt_next = tx_byte_cnt + 1; // increment tx byte counter
                fifo_tx_rd_o = 1; // read next byte from FIFO
                if(tx_byte_cnt_next == tx_len_reg) begin
                    state_next = CS_HOLD; // go to CS_HOLD when all bytes are transmitted
                    tx_byte_cnt_next = 0; // reset tx byte counter for next transfer
                end else begin
                    shift_tx_byte_o = fifo_tx_rbyte; // load next byte from FIFO
                end
            end else begin
                tx_byte_cnt_next = tx_byte_cnt; // keep current tx byte counter
            end
        end
        RX_DATA: begin
            sclk_en_o = 1; // enable clock for shifting address
                // logic to transition back to IDLE when data transfer is complete
            state_next = RX_DATA; // stay in RX_DATA phase until done
            if(shift_rx_byte_ready) begin
                rx_byte_cnt_next = rx_byte_cnt + 1; // increment rx byte counter
                fifo_rx_wbyte_o = shift_rx_byte; // write received byte to FIFO
                fifo_rx_wr_o = 1; // write to FIFO
                if(rx_byte_cnt_next == rx_len_reg) begin
                    state_next = CS_HOLD; // go to CS_HOLD when all bytes are transmitted
                    rx_byte_cnt_next = 0; // reset rx byte counter for next transfer
                end else begin
                    shift_tx_byte_o = fifo_tx_rbyte; // load next byte from FIFO
                end
            end else begin
                rx_byte_cnt_next = rx_byte_cnt; // keep current tx byte counter
            end
        end

        CS_HOLD: begin
            // logic to hold CS active for a specified duration if needed
            if(sclk_idle) begin
                state_next = IDLE; // transition back to IDLE after CS hold
            end else begin
                state_next = CS_HOLD; // stay in CS_HOLD until clock sequence is done
            end
        end

        default: state_next = IDLE;
    endcase
end

assign start_accept = start && (state_reg == IDLE); // accept start command only when ready

assign ready = ready_o;
assign done = done_o;
assign error = error_o;

assign sclk_en = sclk_en_o;

assign phase = state_reg;
assign current_bus_width = current_bus_width_o;
assign shift_tx_load = shift_tx_load_o;
assign shift_tx_byte = tx_reg;
assign shift_rx_en = shift_rx_en_o;

assign fifo_tx_rd = fifo_tx_rd_o && !fifo_tx_empty; // read from FIFO when loading shift register for data phase
assign fifo_rx_wr = fifo_rx_wr_o && !fifo_rx_full;
assign fifo_rx_wbyte = fifo_rx_wbyte_o;

assign qspi_cs = ({QSPI_SLAVE_COUNT{phase == IDLE}} | ~(1 << cs_num_reg)); // assert CS for selected slave during active phasesq

endmodule
