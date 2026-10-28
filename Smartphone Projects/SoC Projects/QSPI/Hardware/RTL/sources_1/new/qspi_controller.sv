`timescale 1ns / 1ps
// qspi_controller.v
// -----------------------------------------------------------------------------
// QSPI Master Controller with Instruction, Address, Alternate, Dummy, and Data
// -----------------------------------------------------------------------------
import qspi_types_pkg::*;

`include "qspi_definitions.vh"

module qspi_controller 
#(
    parameter QSPI_MAX_ADDR_WIDTH = `QSPI_MAX_ADDR_WIDTH,
    parameter QSPI_SLAVE_COUNT = `QSPI_SLAVE_COUNT,
    parameter QSPI_CS_SEL_WIDTH = (QSPI_SLAVE_COUNT > 1) ? $clog2(QSPI_SLAVE_COUNT) : 1,
    parameter QSPI_DATA_LEN_WIDTH = `QSPI_DATA_LEN_WIDTH,
    parameter QSPI_DUMMY_COUNT_WIDTH = `QSPI_DUMMY_COUNT_WIDTH,
    parameter QSPI_MODE_WIDTH = `QSPI_MODE_WIDTH,    
    parameter QSPI_DATA_WIDTH = `QSPI_DATA_WIDTH,
    parameter MAX_PHASES = 8
) 
(
    // system level signals
    input  logic        clk,
    input  logic        reset,

    // register to controller signals
    input logic start,

    input logic ddr_en,

    input logic has_opcode,
    input logic has_addr,
    input logic has_mode,
    input logic has_dummy,
    input logic has_tx_data,
    input logic has_rx_data,
    input logic [2:0] cmd_io_width,
    input logic [2:0] addr_io_width,
    input logic [2:0] mode_io_width,
    input logic [2:0] data_io_width,
    input logic [1:0] addr_bit_width,

    input logic [7:0] opcode,
    input logic [QSPI_MODE_WIDTH-1:0] mode_bits,
    input logic [QSPI_DUMMY_COUNT_WIDTH-1:0] dummy_cycles,

    input logic [QSPI_MAX_ADDR_WIDTH-1:0] flash_addr,
    
    input logic [QSPI_DATA_LEN_WIDTH-1:0] tx_len,
    input logic [QSPI_DATA_LEN_WIDTH-1:0] rx_len,

    input logic [QSPI_CS_SEL_WIDTH-1:0] cs_num,

    // shift register to controller signals
    input logic shift_tx_byte_done,
    input logic shift_rx_byte_ready,
    input logic [QSPI_DATA_WIDTH-1:0] shift_rx_byte,

    // fifo to controller signals
    input logic fifo_tx_empty,
    input logic [QSPI_DATA_WIDTH-1:0] fifo_tx_rbyte,
    input logic fifo_rx_full,

    // sclk gen to controller signals
    input logic drive_tick,
    input logic sample_tick,
    input logic sclk_idle,

    // controller to register signals
    output logic ready,

    // controller to top-level flash interface signals
    output logic [QSPI_SLAVE_COUNT-1:0] qspi_cs,

    // controller to clock generator signals
    output logic sclk_en,

    // controller to shift register signals
    output state_type phase,
    output logic [2:0] bus_width,
    output logic [2:0] io_ctrl_width,
    output logic io_force_release,
    output logic shift_tx_load,
    output logic [QSPI_DATA_WIDTH-1:0] shift_tx_byte,
    output logic shift_rx_en,
    output rate_type rate,

    // controller to fifo signals
    output logic fifo_tx_rd,
    output logic fifo_rx_wr,
    output logic [QSPI_DATA_WIDTH-1:0] fifo_rx_wbyte

);  

typedef enum logic {
    CONFIG_DATA,
    TX_FIFO_DATA
} data_type;

typedef enum logic [1:0] {
    NONE,
    TX_TRANSACTION,
    RX_TRANSACTION
} phase_action_type;

state_type state_reg, state_next, active_phase_reg, active_phase_next;
state_type phase_order_reg [MAX_PHASES]; 
state_type phase_order_calc [MAX_PHASES];

rate_type rate_type_order_reg[MAX_PHASES];
rate_type rate_type_order_calc[MAX_PHASES];
rate_type lookahead_rate_type_reg, lookahead_rate_type_next;

data_type data_type_order_reg[MAX_PHASES];
data_type data_type_order_calc[MAX_PHASES];
data_type lookahead_data_type_reg, lookahead_data_type_next;

phase_action_type phase_action_order_reg[MAX_PHASES];
phase_action_type phase_action_order_calc[MAX_PHASES];
phase_action_type lookahead_phase_action_reg, lookahead_phase_action_next;

logic [QSPI_DATA_WIDTH-1:0] data_order_reg [MAX_PHASES];
logic [QSPI_DATA_WIDTH-1:0] data_order_calc [MAX_PHASES];
logic [QSPI_DATA_WIDTH-1:0] lookahead_data_reg, lookahead_data_next;

logic [2:0] io_width_order_reg [MAX_PHASES];
logic [2:0] io_width_calc [MAX_PHASES];
logic [2:0] lookahead_io_width_reg, lookahead_io_width_next, active_io_width_reg, active_io_width_next;

logic [$clog2(MAX_PHASES)-1:0] phase_idx_reg, phase_idx_next;
logic [$clog2(MAX_PHASES+1)-1:0] phase_total_reg, phase_total_calc, build_idx;
logic [QSPI_DUMMY_COUNT_WIDTH-1:0] dummy_cycles_cnt, dummy_cycles_cnt_next;

logic ready_o;
logic sclk_en_o;
logic shift_tx_load_o, shift_rx_en_o;
logic fifo_tx_rd_o, fifo_rx_wr_o;

logic [QSPI_DATA_LEN_WIDTH-1:0] byte_cnt_reg, byte_cnt_next;
logic [2:0] addr_byte_cnt;
logic start_accept;
logic last_transaction_reg, last_transaction_next;
logic active_transaction_reg, active_transaction_next;
logic initial_load;
logic dummy_cycle_done;

logic [QSPI_CS_SEL_WIDTH-1:0] cs_num_reg;
logic [QSPI_DATA_LEN_WIDTH-1:0] tx_len_reg, rx_len_reg;
logic [QSPI_DUMMY_COUNT_WIDTH-1:0] dummy_cycles_reg;
logic ddr_en_reg;

function automatic logic is_last_transaction;
    input logic [$clog2(MAX_PHASES)-1:0] phase_idx;
    input logic [$clog2(MAX_PHASES+1)-1:0] phase_total;
    input state_type phase_order[MAX_PHASES];
    input logic [QSPI_DATA_LEN_WIDTH-1:0] byte_cnt_reg;
    input logic [QSPI_DATA_LEN_WIDTH-1:0] tx_len;
    input logic [QSPI_DATA_LEN_WIDTH-1:0] rx_len;

    begin
        if(phase_idx == phase_total-1) begin
            if(phase_order[phase_idx] == CTRL_TX_DATA) begin
                if(byte_cnt_reg == tx_len-1) begin 
                    is_last_transaction = 1; // set last phase flag when all phases are done
                end else begin
                    is_last_transaction = 0; // clear last phase flag when not all phases are done
                end
            end else if(phase_order[phase_idx] == CTRL_RX_DATA) begin
                if(byte_cnt_reg == rx_len-1) begin 
                    is_last_transaction = 1; // set last phase flag when all phases are done
                end else begin
                    is_last_transaction = 0; // clear last phase flag when not all phases are done
                end
            end else begin
                is_last_transaction = 1; // set last phase flag when all phases are done
            end
        end else begin
            is_last_transaction = 0; // clear last phase flag when not all phases are done
        end
    end
endfunction

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        state_reg <= CTRL_IDLE;
        byte_cnt_reg <= 0; // latch byte counter for current command
        dummy_cycles_cnt <= 0; // latch dummy cycle counter for current command
        initial_load <= 0; // clear initial load flag for first phase of command
        last_transaction_reg <= 0; // clear last phase flag for current command

        cs_num_reg <= 0; // latch chip select number
        tx_len_reg <= 0; // latch tx length
        rx_len_reg <= 0; // latch rx length
        dummy_cycles_reg <= 0; // latch dummy cycles
        ddr_en_reg <= 1'b0; // latch DDR mode for the active transaction
        active_transaction_reg <= 0; // clear active transaction flag for current command
        
        phase_total_reg <= 0; // latch phase count
        phase_idx_reg <= 0; // latch phase index

        active_phase_reg <= CTRL_IDLE; // latch active phase
        active_io_width_reg <= 0; // latch active phase bus width
        lookahead_io_width_reg <= 0;
        lookahead_data_reg <= 0;
        lookahead_rate_type_reg <= RATE_SDR;
        lookahead_data_type_reg <= CONFIG_DATA;
        lookahead_phase_action_reg <= NONE;

    end else begin
        state_reg <= state_next;
        phase_idx_reg <= phase_idx_next; // update phase index for current command
        active_phase_reg <= active_phase_next; // transition to CTRL_CS_SETUP phase after latching command parameters
        dummy_cycles_cnt <= dummy_cycles_cnt_next; // update dummy cycle counter for current command
        byte_cnt_reg <= byte_cnt_next; // update tx byte counter for current command
        active_transaction_reg <= active_transaction_next; // update active transaction flag for current command

        if(start_accept) begin
            // latch all command parameters from registers to internal registers
                cs_num_reg <= cs_num; // latch chip select number
                tx_len_reg <= tx_len; // latch tx length
                rx_len_reg <= rx_len; // latch rx length
                dummy_cycles_reg <= dummy_cycles; // latch dummy cycles
                ddr_en_reg <= ddr_en; // freeze DDR mode for the active transaction

                for (int i = 0; i <= MAX_PHASES-1; i++) begin
                    phase_order_reg[i] <= phase_order_calc[i];
                    data_order_reg[i] <= data_order_calc[i];
                    io_width_order_reg[i] <= io_width_calc[i];
                    data_type_order_reg[i] <= data_type_order_calc[i];
                    rate_type_order_reg[i] <= rate_type_order_calc[i];
                    phase_action_order_reg[i] <= phase_action_order_calc[i];
                end

                phase_total_reg <= phase_total_calc; // latch phase count
                
                lookahead_io_width_reg <= io_width_calc[0]; // set bus width for command phase
                lookahead_data_reg <= data_order_calc[0]; // load opcode into shift register
                lookahead_rate_type_reg <= rate_type_order_calc[0]; // load opcode rate type

                lookahead_data_type_reg <= data_type_order_calc[0]; // load opcode data type
                lookahead_phase_action_reg <= phase_action_order_calc[0]; // load opcode phase action type

                initial_load <= 1; // set initial load flag for first phase of command

                last_transaction_reg <= phase_total_calc == 1; // set last phase flag for single phase command
                
        end else begin
            lookahead_io_width_reg <= lookahead_io_width_next; // update active phase bus width for current command
            lookahead_data_reg <= lookahead_data_next; // update active phase data for current command
            lookahead_rate_type_reg <= lookahead_rate_type_next; // update active phase rate type for current command


            lookahead_data_type_reg <= lookahead_data_type_next; // update active phase data type for current command
            lookahead_phase_action_reg <= lookahead_phase_action_next; // update active phase action type for current command

            active_io_width_reg <= active_io_width_next; // update active phase bus width for current command

            initial_load <= 0; // clear initial load flag after first phase of command

            last_transaction_reg <= last_transaction_next; // update last phase flag for current command
        end
    end
end

always_comb begin : phase_config_build
    phase_order_calc  = phase_order_reg;
    data_order_calc = data_order_reg;
    io_width_calc = io_width_order_reg;
    phase_total_calc = phase_total_reg;
    data_type_order_calc = data_type_order_reg;
    rate_type_order_calc = rate_type_order_reg;
    phase_action_order_calc = phase_action_order_reg;
    build_idx        = 0;
    addr_byte_cnt    = 3;

    if(start_accept) begin
        if(has_opcode) begin
            phase_order_calc[build_idx] = CTRL_INSTRUCTION;
            data_order_calc[build_idx] = opcode; // CTRL_INSTRUCTION phase has no byte order
            io_width_calc[build_idx] = cmd_io_width; // CTRL_INSTRUCTION phase bus width
            data_type_order_calc[build_idx] = CONFIG_DATA; // CTRL_INSTRUCTION phase is a config byte
            rate_type_order_calc[build_idx] = RATE_SDR; // CTRL_INSTRUCTION phase is a config byte
            phase_action_order_calc[build_idx] = TX_TRANSACTION; // CTRL_INSTRUCTION phase is a config byte
            build_idx = build_idx + 1;
        end

        if (has_addr) begin
            case (addr_bit_width)
                2'd0:    addr_byte_cnt = 3; // 24-bit address
                2'd1:    addr_byte_cnt = 4; // 32-bit address
                default: addr_byte_cnt = 3; // safe fallback
            endcase

            for(int unsigned i = 0; i < addr_byte_cnt; i++) begin
                phase_order_calc[build_idx] = CTRL_ADDRESS;
                data_order_calc[build_idx] = flash_addr[(addr_byte_cnt-i-1)*8 +: 8]; // CTRL_ADDRESS phase has byte order from flash address
                io_width_calc[build_idx] = addr_io_width; // CTRL_ADDRESS phase bus width
                data_type_order_calc[build_idx] = CONFIG_DATA; // CTRL_ADDRESS phase is a config byte
                rate_type_order_calc[build_idx] = (ddr_en) ? RATE_DDR : RATE_SDR; // CTRL_ADDRESS phase is a config byte
                phase_action_order_calc[build_idx] = TX_TRANSACTION; // CTRL_ADDRESS phase is a config byte
                build_idx = build_idx + 1;
            end
        end

        if (has_mode) begin
            phase_order_calc[build_idx] = CTRL_MODE;
            data_order_calc[build_idx] = mode_bits; // CTRL_MODE phase has byte order from mode bits
            io_width_calc[build_idx] = mode_io_width; // CTRL_MODE phase bus width
            data_type_order_calc[build_idx] = CONFIG_DATA; // CTRL_MODE phase is a config byte
            rate_type_order_calc[build_idx] = (ddr_en) ? RATE_DDR : RATE_SDR; // CTRL_MODE phase is a config byte
            phase_action_order_calc[build_idx] = TX_TRANSACTION; // CTRL_MODE phase is a config byte
            build_idx = build_idx + 1;
        end

        if (has_dummy) begin
            phase_order_calc[build_idx] = CTRL_DUMMY;
            data_order_calc[build_idx] = 0; // CTRL_DUMMY phase has no byte to transmit, so no byte order
            io_width_calc[build_idx] = 0; // CTRL_DUMMY phase has no bus width\
            data_type_order_calc[build_idx] = CONFIG_DATA; // CTRL_DUMMY phase is a config byte
            rate_type_order_calc[build_idx] = (ddr_en) ? RATE_DDR : RATE_SDR; // CTRL_DUMMY phase is a config byte
            phase_action_order_calc[build_idx] = NONE; // CTRL_DUMMY phase is a config byte
            build_idx = build_idx + 1;
        end

        if (has_rx_data) begin
            phase_order_calc[build_idx] = CTRL_RX_DATA;
            data_order_calc[build_idx] = 0; // CTRL_RX_DATA phase has no byte to transmit, so no byte order
            io_width_calc[build_idx] = data_io_width; // CTRL_RX_DATA phase has no bus width
            data_type_order_calc[build_idx] = CONFIG_DATA; // CTRL_RX_DATA phase is a data byte
            rate_type_order_calc[build_idx] = (ddr_en) ? RATE_DDR : RATE_SDR; // CTRL_RX_DATA phase is a data byte
            phase_action_order_calc[build_idx] = RX_TRANSACTION; // CTRL_RX_DATA phase is a data byte
            build_idx = build_idx + 1;
        end else if (has_tx_data) begin
            phase_order_calc[build_idx] = CTRL_TX_DATA;
            data_order_calc[build_idx] = 0; // CTRL_TX_DATA phase has bytes to transmit, but that will be provided by the FIFO 
            io_width_calc[build_idx] = data_io_width; // CTRL_TX_DATA phase has no bus width
            data_type_order_calc[build_idx] = TX_FIFO_DATA; // CTRL_TX_DATA phase is a data byte
            rate_type_order_calc[build_idx] = (ddr_en) ? RATE_DDR : RATE_SDR; // CTRL_TX_DATA phase is a data byte
            phase_action_order_calc[build_idx] = TX_TRANSACTION; // CTRL_TX_DATA phase is a data byte
            build_idx = build_idx + 1;
        end

        phase_total_calc = build_idx;
    end
end

always_comb begin : io_ctrl_update
    active_phase_next = active_phase_reg;
    active_io_width_next = active_io_width_reg;

    if(sclk_idle && (state_reg == CTRL_CS_HOLD || state_reg == CTRL_IDLE || state_reg == CTRL_CYCLE_DELAY)) begin
        active_phase_next = CTRL_IDLE; // maintain active phase as CTRL_IDLE when in CS_HOLD or IDLE state
        active_io_width_next = io_width_order_reg[0]; // maintain active phase bus width as CTRL_IDLE when in CS_HOLD or IDLE state
    end else begin 
        case(rate_type_order_reg[phase_idx_next])
            RATE_SDR: begin
                if(drive_tick) begin
                    active_phase_next = phase_order_reg[phase_idx_next]; // set active phase for current command
                    active_io_width_next = io_width_order_reg[phase_idx_next]; // set active phase bus width for current command
                end
            end
            RATE_DDR: begin
                //shift_rx_byte_ready doesn't need to be part of the conditional bc it only applies for RX_DATA phase, which is the last phase and the io_width remains constant even for multiple bytes
                active_phase_next = phase_order_reg[phase_idx_next]; // set active phase for current command
                active_io_width_next = io_width_order_reg[phase_idx_next]; // set active phase bus width for current command
            end
            default: begin
                active_phase_next = active_phase_reg; // maintain current active phase for current command
                active_io_width_next = active_io_width_reg; // maintain current active phase bus width for current command
            end
        endcase
    end
end

always_comb begin : lookahead_data_update
    fifo_tx_rd_o = 0;
    lookahead_data_next = lookahead_data_reg;

    if(active_transaction_reg) begin
        case(lookahead_data_type_next)
            CONFIG_DATA: begin
                if(!last_transaction_next) begin
                    lookahead_data_next = data_order_reg[phase_idx_next + 1]; // load shift register with config byte
                end
            end
            TX_FIFO_DATA: begin
                if((dummy_cycle_done || shift_tx_byte_done || initial_load) && !last_transaction_next) begin // need to send rd when loading fifo bytes into shift register for above logic to work^
                    lookahead_data_next = fifo_tx_rbyte; // load shift register with tx data byte from FIFO
                    fifo_tx_rd_o = 1; // read next byte from FIFO for CTRL_TX_DATA phase
                end
            end
            default: begin
                lookahead_data_next = lookahead_data_reg; // maintain current shift register value for other phases
            end
        endcase
    end
end

always_comb begin : shift_control_update
    shift_tx_load_o = 1'b0;
    shift_rx_en_o   = 1'b0;

    if(active_transaction_reg) begin
        case (lookahead_phase_action_reg)
            TX_TRANSACTION: begin
                if (initial_load || (!(last_transaction_reg))) begin
                    shift_tx_load_o = 1'b1;
                end
            end

            RX_TRANSACTION: begin
                // There will never a scenario where RX_TRANSACTION is the first phase, so we don't need an initial condition
                if (state_reg == CTRL_RX_DATA && !(shift_rx_byte_ready && last_transaction_reg)) begin 
                    shift_rx_en_o = 1'b1;
                end
            end

            default: begin
                shift_tx_load_o = 1'b0;
                shift_rx_en_o   = 1'b0;
            end
        endcase
    end
end

// shift_tx_byte_done is registered by the shifter on the same system-clock
// edge as the final DDR sample edge. The phase FSM consumes it one clock later;
// force the external drivers off during that intervening cycle when the next
// protocol phase is latency/RX, without advancing the FSM early.
always_comb begin : io_force_release_update
    io_force_release = 1'b0;
    if (ddr_en_reg && shift_tx_byte_done &&
        (state_reg == CTRL_ADDRESS || state_reg == CTRL_MODE)) begin
        if ((phase_idx_reg + 1) < phase_total_reg) begin
            if (phase_order_reg[phase_idx_reg + 1] == CTRL_DUMMY) begin
                io_force_release = 1'b1;
            end
        end
    end
end

always_comb begin : FSM
    state_next = state_reg;
    phase_idx_next = phase_idx_reg;
    byte_cnt_next = byte_cnt_reg;
    dummy_cycles_cnt_next = dummy_cycles_cnt;
    last_transaction_next = last_transaction_reg;
    active_transaction_next = active_transaction_reg;

    lookahead_io_width_next = lookahead_io_width_reg;
    lookahead_data_type_next = lookahead_data_type_reg;
    lookahead_phase_action_next = lookahead_phase_action_reg;
    lookahead_rate_type_next = lookahead_rate_type_reg;

    ready_o = 0;
    sclk_en_o = 0;
    dummy_cycle_done = 0;
    fifo_rx_wr_o = 0;

    case(state_reg)
        CTRL_IDLE: begin
            ready_o = 1; // ready to accept new command in CTRL_IDLE state
            phase_idx_next = 0; // reset phase index for new command
            dummy_cycles_cnt_next = 0; // reset dummy cycle counter for new command
            byte_cnt_next = 0; // reset tx byte counter for new command
            last_transaction_next = 0; // reset last phase flag for new command
            active_transaction_next = 0; // reset active transaction flag for new command

            if (start) begin
                state_next = CTRL_PRELOAD; // transition to CTRL_CS_SETUP state
                active_transaction_next = 1; // reset active transaction flag for new command
            end else begin
                state_next = CTRL_IDLE;
            end
        end

        CTRL_PRELOAD: begin
            // sclk_en_o = 0; 
            // according to flash tCSs, the CS needs to be asserted for a min of 3ns before activating the sclk, this whole state will last 10ns 
            // however, with the way our shift_reg logic is set up for DDR we need the CS to be asserted for 20ns because the upcoming 
            // sys clk edge is when io_tx_reg is updated and on the IO line for the active edge, which statisfies DDR timing
            active_transaction_next = 1; // set active transaction flag for current command

            if(!last_transaction_reg) begin
                lookahead_io_width_next = io_width_order_reg[phase_idx_next + 1]; // set bus width for next phase
                lookahead_data_type_next = data_type_order_reg[phase_idx_next + 1]; // set data type for next phase
                lookahead_phase_action_next = phase_action_order_reg[phase_idx_next + 1]; // set phase action for next phase
                lookahead_rate_type_next = rate_type_order_reg[phase_idx_next + 1]; // set rate type for next phase
            end

            state_next = phase_order_reg[phase_idx_next]; // transition to active phase after preloading shift register
        end

        CTRL_INSTRUCTION, CTRL_ADDRESS, CTRL_MODE: begin
            sclk_en_o = 1; // enable clock for shifting instruction
            // logic to transition to next state based on has_addr, has_mode, etc.

            active_transaction_next = 1; // set active transaction flag for current command

            if(shift_tx_byte_done) begin
                if(last_transaction_reg) begin
                    state_next = CTRL_CS_HOLD; // transition to CTRL_CS_HOLD phase when all phases are done
                end else begin
                    phase_idx_next = phase_idx_reg + 1; // increment phase index

                    last_transaction_next = is_last_transaction(phase_idx_next, phase_total_reg, phase_order_reg, byte_cnt_reg, tx_len_reg, rx_len_reg); // check if next phase is the last phase

                    if(!last_transaction_next && phase_order_reg[phase_idx_next] != CTRL_RX_DATA && phase_order_reg[phase_idx_next] != CTRL_TX_DATA) begin
                        lookahead_io_width_next = io_width_order_reg[phase_idx_next + 1]; // set bus width for next phase
                        lookahead_data_type_next = data_type_order_reg[phase_idx_next + 1]; // set data type for next phase
                        lookahead_phase_action_next = phase_action_order_reg[phase_idx_next + 1]; // set phase action for next phase
                        lookahead_rate_type_next = rate_type_order_reg[phase_idx_next + 1]; // set rate type for next phase
                    end

                    state_next = phase_order_reg[phase_idx_next]; // transition to next phase after instruction is done
                end
            end
        end
        CTRL_DUMMY: begin
            sclk_en_o = 1; // enable clock for shifting address

            active_transaction_next = 1; // set active transaction flag for current command

            if (ddr_en_reg) begin
                // DDR latency cycles are bounded by falling edges. The terminal
                // falling edge launches the flash's first read bit; RX must be
                // active before the following rising-edge sample.
                if (drive_tick) begin
                    if (dummy_cycles_cnt >= dummy_cycles_reg - 1'b1) begin
                        dummy_cycle_done = 1;
                    end else begin
                        dummy_cycles_cnt_next = dummy_cycles_cnt + 1'b1;
                    end
                end
            end else begin
                // Preserve the existing SDR convention: count falling edges,
                // then leave DUMMY on the corresponding rising sample edge.
                if(drive_tick) begin
                    dummy_cycles_cnt_next = dummy_cycles_cnt + 1'b1;
                end else if(sample_tick && dummy_cycles_cnt >= dummy_cycles_reg) begin
                    dummy_cycle_done = 1;
                end
            end

            if (dummy_cycle_done) begin
                dummy_cycles_cnt_next = 0; // reset dummy cycle counter for next transfer
                if(last_transaction_reg) begin
                    state_next = CTRL_CS_HOLD; // transition to CTRL_CS_HOLD phase when all phases are done
                end else begin 
                    phase_idx_next = phase_idx_reg + 1; // increment phase index

                    last_transaction_next = is_last_transaction(phase_idx_next, phase_total_reg, phase_order_reg, byte_cnt_reg, tx_len_reg, rx_len_reg); // check if next phase is the last phase

                    state_next = phase_order_reg[phase_idx_next]; // transition to next phase after instruction is done
                end
            end
        end
        CTRL_TX_DATA: begin
            sclk_en_o = 1; // enable clock for shifting address
            // logic to transition back to CTRL_IDLE when data transfer is complete

            active_transaction_next = 1; // set active transaction flag for current command

             if(shift_tx_byte_done) begin
                if(last_transaction_reg) begin
                    state_next = CTRL_CS_HOLD; // transition to CTRL_CS_HOLD phase when all phases are done
                    byte_cnt_next = 0; // reset tx byte counter for next transfer
                end else begin

                    byte_cnt_next = byte_cnt_reg + 1; // increment tx byte counter
                    
                    if(byte_cnt_next == tx_len_reg-1) begin
                        last_transaction_next = 1; // set last phase flag when all phases are done
                    end 

                    state_next = CTRL_TX_DATA; // transition to CTRL_INSTRUCTION phase after CS setup
                end
            end
        end
        CTRL_RX_DATA: begin
            sclk_en_o = 1; // enable clock for shifting address
                // logic to transition back to CTRL_IDLE when data transfer is complete

            active_transaction_next = 1; // set active transaction flag for current command

            if(shift_rx_byte_ready) begin
                fifo_rx_wr_o = 1; // write received byte to FIFO
                
                if(last_transaction_reg) begin
                    state_next = CTRL_CS_HOLD; // transition to CTRL_CS_HOLD phase when all phases are done
                    byte_cnt_next = 0; // reset tx byte counter for next transfer
                end else begin

                    byte_cnt_next = byte_cnt_reg + 1; // increment tx byte counter
                    
                    if(byte_cnt_next == rx_len_reg-1) begin
                        last_transaction_next = 1; // set last phase flag when all phases are done
                    end 

                    state_next = CTRL_RX_DATA; // transition to CTRL_INSTRUCTION phase after CS setup
                end
            end
        end

        CTRL_CS_HOLD: begin
            // logic to hold CS active for a specified duration if needed

            active_transaction_next = 1; // set active transaction flag for current command

            if(sclk_idle) begin
                state_next = CTRL_CYCLE_DELAY; // transition back to CTRL_CYCLE_DELAY after CS hold
                phase_idx_next = 0; // reset phase index for next transfer
                last_transaction_next = 0; // reset last phase flag for next transfer
                active_transaction_next = 0; // reset active transaction flag for next transfer
            end else begin
                state_next = CTRL_CS_HOLD; // stay in CTRL_CS_HOLD until clock sequence is done
            end
        end

        CTRL_CYCLE_DELAY: begin
            // a 10ns delay after CS is high to meet tCS for read transactions
            active_transaction_next = 0; // reset active transaction flag for next transfer
            state_next = CTRL_IDLE; // transition back to CTRL_IDLE after delay
        end

        default: begin
            state_next = CTRL_IDLE;
            phase_idx_next = 0;
            byte_cnt_next = 0;
            dummy_cycles_cnt_next = 0;
            last_transaction_next = 0;
            lookahead_io_width_next = 0;
            lookahead_data_type_next = CONFIG_DATA;
            lookahead_phase_action_next = NONE;
            lookahead_rate_type_next = RATE_SDR;
            active_transaction_next = 0; // reset active transaction flag for next transfer
            sclk_en_o = 0; // disable clock if no valid state
        end
    endcase
end

assign start_accept = start && (state_reg == CTRL_IDLE); // accept start command only when ready

assign ready = ready_o;

assign rate = lookahead_rate_type_reg; // set rate type for shift register based on active phase rate type

assign sclk_en = sclk_en_o;

assign phase = active_phase_reg;
assign bus_width = lookahead_io_width_reg;
assign io_ctrl_width = active_io_width_reg; // set io_ctrl_width for shift register based on active phase rate type

assign shift_tx_load = shift_tx_load_o; // load active phase data into shift register when phase transition occurs
assign shift_tx_byte = lookahead_data_reg; // load active phase data into shift register when phase transition occurs
assign shift_rx_en = shift_rx_en_o;

assign fifo_tx_rd = fifo_tx_rd_o && !fifo_tx_empty; // read from FIFO when loading shift register for data phase
assign fifo_rx_wr = fifo_rx_wr_o && !fifo_rx_full;
assign fifo_rx_wbyte = shift_rx_byte;

assign qspi_cs = {QSPI_SLAVE_COUNT{state_reg == CTRL_IDLE || state_reg == CTRL_CYCLE_DELAY}} | ~({{(QSPI_SLAVE_COUNT-1){1'b0}}, 1'b1} << cs_num_reg);
endmodule
