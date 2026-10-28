`timescale 1ns / 1ps

import qspi_types_pkg::*;

// Self-checking testbench for realistic multi-phase flash transactions.
module tb_qspi_controller;

    localparam int ADDR_WIDTH  = 32;
    localparam int SLAVE_COUNT = 3;
    localparam int LEN_WIDTH   = 16;
    localparam int DUMMY_WIDTH = 8;
    localparam int MODE_WIDTH  = 8;
    localparam int DATA_WIDTH  = 8;
    localparam time CLK_PERIOD = 10ns;

    logic clk, reset;
    logic start, ddr_en;
    logic has_opcode, has_addr, has_mode, has_dummy, has_tx_data, has_rx_data;
    logic [2:0] cmd_io_width, addr_io_width, mode_io_width, data_io_width;
    logic [1:0] addr_bit_width;
    logic [7:0] opcode;
    logic [MODE_WIDTH-1:0] mode_bits;
    logic [DUMMY_WIDTH-1:0] dummy_cycles;
    logic [ADDR_WIDTH-1:0] flash_addr;
    logic [LEN_WIDTH-1:0] tx_len, rx_len;
    logic [$clog2(SLAVE_COUNT)-1:0] cs_num;

    logic shift_tx_byte_done, shift_rx_byte_ready;
    logic [DATA_WIDTH-1:0] shift_rx_byte;
    logic fifo_tx_empty, fifo_rx_full;
    logic [DATA_WIDTH-1:0] fifo_tx_rbyte;
    logic drive_tick, sample_tick, sclk_idle;

    logic ready;
    logic [SLAVE_COUNT-1:0] qspi_cs;
    logic sclk_en;
    state_type phase;
    logic [2:0] bus_width, io_ctrl_width;
    logic io_force_release;
    logic shift_tx_load;
    logic [DATA_WIDTH-1:0] shift_tx_byte;
    logic shift_rx_en;
    rate_type rate;
    logic fifo_tx_rd, fifo_rx_wr;
    logic [DATA_WIDTH-1:0] fifo_rx_wbyte;
    int failures;
    time cycle_delay_start;

    qspi_controller #(
        .QSPI_MAX_ADDR_WIDTH(ADDR_WIDTH),
        .QSPI_SLAVE_COUNT(SLAVE_COUNT),
        .QSPI_DATA_LEN_WIDTH(LEN_WIDTH),
        .QSPI_DUMMY_COUNT_WIDTH(DUMMY_WIDTH),
        .QSPI_MODE_WIDTH(MODE_WIDTH),
        .QSPI_DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    task automatic reset_dut;
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        @(posedge clk);
        #1;
    endtask

    task automatic defaults;
        start = 0; ddr_en = 0;
        has_opcode = 0; has_addr = 0; has_mode = 0; has_dummy = 0;
        has_tx_data = 0; has_rx_data = 0;
        cmd_io_width = 1; addr_io_width = 1; mode_io_width = 1; data_io_width = 1;
        addr_bit_width = 0;
        opcode = 0; mode_bits = 0; dummy_cycles = 0; flash_addr = 0;
        tx_len = 0; rx_len = 0; cs_num = 0;
        shift_tx_byte_done = 0; shift_rx_byte_ready = 0; shift_rx_byte = 0;
        fifo_tx_empty = 1; fifo_tx_rbyte = 0; fifo_rx_full = 0;
        drive_tick = 0; sample_tick = 0; sclk_idle = 0;
    endtask

    task automatic start_command;
        start = 1'b1;
        @(posedge clk);
        #1 start = 1'b0;
    endtask

    task automatic tx_done;
        shift_tx_byte_done = 1'b1;
        @(posedge clk);
        #1 shift_tx_byte_done = 1'b0;
    endtask

    task automatic complete_tx_byte(
        input logic [DATA_WIDTH-1:0] expected,
        input string message
    );
        #1;
        check(shift_tx_load && shift_tx_byte === expected, message);
        tx_done();
    endtask

    task automatic rx_ready(
        input logic [DATA_WIDTH-1:0] value,
        input logic [DATA_WIDTH-1:0] expected,
        input string message
    );
        shift_rx_byte = value;
        shift_rx_byte_ready = 1'b1;
        #1;
        check(fifo_rx_wr && fifo_rx_wbyte === expected, message);
        @(posedge clk);
        #1 shift_rx_byte_ready = 1'b0;
    endtask

    task automatic dummy_edge(input logic drive, input logic sample);
        drive_tick = drive;
        sample_tick = sample;
        @(posedge clk);
        #1 begin drive_tick = 0; sample_tick = 0; end
    endtask

    task automatic finish_command;
        check(!ready && qspi_cs === 3'b011,
              "CS hold: chip select must remain asserted before sclk_idle");
        sclk_idle = 1'b1;
        @(posedge clk);
        #1;
        cycle_delay_start = $time;
        check(dut.state_reg === CTRL_CYCLE_DELAY,
              "CS hold: controller did not enter CYCLE_DELAY");
        check(qspi_cs === {SLAVE_COUNT{1'b1}},
              "CYCLE_DELAY: chip select must be deasserted");
        sclk_idle = 1'b0;
        @(posedge clk);
        #1;
        check(ready, "controller did not return to IDLE after CS hold");
        check(qspi_cs === {SLAVE_COUNT{1'b1}}, "CS was not deasserted in IDLE");
        check(($time - cycle_delay_start) == CLK_PERIOD,
              "CYCLE_DELAY: delay was not exactly one system clock");
    endtask

    initial begin
        clk = 0;
        failures = 0;
        defaults();
        reset_dut();

        check(ready, "reset: controller must be ready in IDLE");
        check(qspi_cs === {SLAVE_COUNT{1'b1}},
              "reset: all chip selects must be inactive");
        check(!sclk_en && !shift_tx_load && !shift_rx_en &&
              !fifo_tx_rd && !fifo_rx_wr,
              "reset: activity outputs must be inactive");

        // JEDEC 32h quad-input page program:
        // opcode + 24-bit address + one byte of quad TX data.
        has_opcode = 1; has_addr = 1; has_tx_data = 1;
        opcode = 8'h32;
        flash_addr = 32'h12_34_56; addr_bit_width = 0;
        cmd_io_width = 1; addr_io_width = 1; data_io_width = 4;
        tx_len = 1; cs_num = 2;
        fifo_tx_empty = 0; fifo_tx_rbyte = 8'hA5;
        start_command();
        #1;
        check(!ready && qspi_cs === 3'b011,
              "program: CS selection/preload incorrect");
        check(shift_tx_load && shift_tx_byte === 8'h32,
              "program: opcode was not presented during preload");
        @(posedge clk);
        #1;
        check(dut.state_reg === CTRL_INSTRUCTION,
              "program: controller did not enter opcode phase");
        complete_tx_byte(8'h12, "program: address MSB mismatch");
        complete_tx_byte(8'h34, "program: address middle byte mismatch");
        complete_tx_byte(8'h56, "program: address LSB mismatch");
        complete_tx_byte(8'hA5, "program: first TX data lookahead mismatch");
        check(dut.state_reg === CTRL_TX_DATA,
              "program: controller did not enter TX_DATA");
        // The TX byte was loaded on the final address completion edge above.
        // After that edge, the one-byte TX phase is marked last and the RTL
        // intentionally removes the load strobe.
        tx_done();
        finish_command();

        // JEDEC EBh quad-I/O fast read:
        // opcode + address + mode + dummy cycles + RX data.
        defaults();
        has_opcode = 1; has_addr = 1; has_mode = 1; has_dummy = 1;
        has_rx_data = 1;
        opcode = 8'hEB;
        flash_addr = 32'h12_34_56; addr_bit_width = 0;
        mode_bits = 8'hA5; dummy_cycles = 6;
        cmd_io_width = 1; addr_io_width = 4; mode_io_width = 4;
        data_io_width = 4; rx_len = 2; cs_num = 2;
        start_command();
        #1;
        check(!ready && qspi_cs === 3'b011,
              "read: CS selection/preload incorrect");
        check(shift_tx_load && shift_tx_byte === 8'hEB,
              "read: opcode was not presented during preload");
        @(posedge clk);
        #1;
        check(dut.state_reg === CTRL_INSTRUCTION,
              "read: controller did not enter opcode phase");
        complete_tx_byte(8'h12, "read: address MSB mismatch");
        complete_tx_byte(8'h34, "read: address middle byte mismatch");
        complete_tx_byte(8'h56, "read: address LSB mismatch");
        complete_tx_byte(8'hA5, "read: mode byte lookahead mismatch");
        tx_done();
        check(dut.state_reg === CTRL_DUMMY,
              "read: controller did not enter DUMMY phase");
        dummy_edge(0, 1);
        check(dut.state_reg === CTRL_DUMMY,
              "read: dummy phase ended before configured cycles");
        repeat (6) dummy_edge(1, 0);
        dummy_edge(0, 1);
        check(dut.state_reg === CTRL_RX_DATA,
              "read: controller did not enter RX_DATA after dummy cycles");
        rx_ready(8'h3C, 8'h3C, "read: first RX FIFO write incorrect");
        rx_ready(8'hC3, 8'hC3, "read: second RX FIFO write incorrect");
        finish_command();

        // Immediate new valid command after the cycle-delay state.
        defaults();
        has_opcode = 1; has_addr = 1; has_rx_data = 1;
        opcode = 8'h0B; flash_addr = 32'h00_10_20;
        addr_bit_width = 0; cmd_io_width = 1; addr_io_width = 1;
        data_io_width = 1; rx_len = 1; cs_num = 2;
        start_command();
        #1;
        check(qspi_cs === 3'b011,
              "back-to-back read: new command did not assert selected CS");
        check(($time - cycle_delay_start) >= (2 * CLK_PERIOD),
              "back-to-back read: CS high interval was too short");
        @(posedge clk);
        #1;
        complete_tx_byte(8'h00, "back-to-back read: address MSB mismatch");
        complete_tx_byte(8'h10, "back-to-back read: address middle byte mismatch");
        complete_tx_byte(8'h20, "back-to-back read: address LSB mismatch");
        tx_done();
        check(dut.state_reg === CTRL_RX_DATA,
              "back-to-back read: controller did not enter RX_DATA");
        rx_ready(8'h96, 8'h96, "back-to-back read: RX FIFO write incorrect");
        finish_command();

        if (failures == 0)
            $display("tb_qspi_controller: PASS");
        else
            $fatal(1, "tb_qspi_controller: %0d failure(s)", failures);
        $finish;
    end

endmodule
