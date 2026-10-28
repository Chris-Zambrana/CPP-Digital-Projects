`timescale 1ns / 1ps

import qspi_types_pkg::*;

// System-level smoke test for top_qspi_core.
//
// The testbench intentionally uses only the public MMIO slot and QSPI pins.
// It programs an opcode + 24-bit address + one-byte quad transmit, starts the
// transaction through PULSE_REG, and checks chip-select and QSPI bus ownership
// as the command moves through each phase.
module tb_top_qspi_core;

    localparam time CLK_PERIOD = 10ns;

    localparam logic [4:0]
        PULSE_REG    = 5'd0,
        CONTROL_REG  = 5'd1,
        STATUS_REG   = 5'd2,
        DIVIDER_REG  = 5'd3,
        CMD_CONF_REG = 5'd4,
        CMD_DATA_REG = 5'd5,
        FADDR_REG    = 5'd6,
        TX_LEN_REG   = 5'd7,
        RX_LEN_REG   = 5'd8,
        TX_DATA_REG  = 5'd9,
        RX_DATA_REG  = 5'd10,
        CS_REG       = 5'd11;

    localparam int MAX_FLASH_RESPONSE_BYTES = 16;
    localparam int MAX_CAPTURE_BYTES = 64;

    logic clk, reset;
    logic cs, read, write;
    logic [4:0] addr;
    logic [31:0] wr_data, rd_data;
    logic [2:0] qspi_cs;
    tri [3:0] qspi_io;
    logic flash_drive_en;
    logic [3:0] flash_drive_mask;
    logic [3:0] flash_io_out;
    int failures;
    bit active_seen, instruction_seen, address_seen, mode_seen;
    bit dummy_seen, tx_data_seen, rx_data_seen;

    // Expected values for the transaction currently being monitored. These
    // are updated by set_expected_transaction() before each start pulse.
    logic [1:0] expected_cs_num;
    logic [2:0] expected_cmd_io_width;
    logic [2:0] expected_addr_io_width;
    logic [2:0] expected_mode_io_width;
    logic [2:0] expected_data_io_width;

    // Flash BFM response and controller TX capture storage.
    logic [7:0] flash_response [0:MAX_FLASH_RESPONSE_BYTES-1];
    int flash_response_count;
    logic [2:0] flash_response_width;
    int flash_response_group;
    bit flash_rx_edge_seen;
    int flash_expected_dummy_cycles;
    int flash_dummy_falling_count;
    bit flash_ddr_response_started;
    bit flash_ddr_launch_edge_pending;
    bit flash_ddr_launch_seen;
    bit ddr_tx_first_edge_seen;
    bit ddr_tx_first_sample_seen;
    bit ddr_turnaround_release_seen;
    logic [7:0] tx_capture [0:MAX_CAPTURE_BYTES-1];
    int tx_capture_count;
    logic [7:0] tx_capture_shift;
    int tx_capture_bits;

    top_qspi_core dut (.*);

    // The flash begins DDR output at the terminal falling edge of the dummy
    // phase. flash_ddr_response_started is set at that edge, before the first
    // rising RX sample. SDR responses remain phase-qualified.
    assign flash_drive_en = (qspi_cs !== 3'b111) &&
                            ((dut.ddr_en && flash_ddr_response_started) ||
                             (dut.master_controller.phase == CTRL_RX_DATA));
    // Flash single-bit output data uses SO/IO1 (not the host's SI/IO0).
    // Dual output uses IO[1:0], and quad output uses IO[3:0]. Keep every
    // inactive flash pin high-impedance so the BFM models bus ownership.
    assign qspi_io[0] = (flash_drive_en && flash_drive_mask[0]) ? flash_io_out[0] : 1'bz;
    assign qspi_io[1] = (flash_drive_en && flash_drive_mask[1]) ? flash_io_out[1] : 1'bz;
    assign qspi_io[2] = (flash_drive_en && flash_drive_mask[2]) ? flash_io_out[2] : 1'bz;
    assign qspi_io[3] = (flash_drive_en && flash_drive_mask[3]) ? flash_io_out[3] : 1'bz;

    always #(CLK_PERIOD / 2) clk = ~clk;

    // SDR samples are monitored on rising SCLK edges. DDR address/mode/data
    // are captured separately at the system-clock edge, before the DUT's
    // nonblocking updates change qspi_sclk and advance the output shifter.
    // The opcode remains SDR for the flash's DDR-read commands.
    always @(posedge dut.qspi_sclk) begin
        if (qspi_cs !== 3'b111) begin
            if (dut.ddr_en) begin
                if (dut.master_controller.phase == CTRL_INSTRUCTION)
                    capture_tx_group(expected_cmd_io_width, qspi_io);
            end else begin
                case (dut.master_controller.phase)
                    CTRL_INSTRUCTION: capture_tx_group(expected_cmd_io_width, qspi_io);
                    CTRL_ADDRESS:     capture_tx_group(expected_addr_io_width, qspi_io);
                    CTRL_MODE:        capture_tx_group(expected_mode_io_width, qspi_io);
                    CTRL_TX_DATA:     capture_tx_group(expected_data_io_width, qspi_io);
                    default:          ;
                endcase
            end
        end
    end

    // edge_tick is asserted in the system-clock cycle that will toggle SCLK.
    // At the SDR-instruction -> DDR-address boundary, the first falling edge
    // launches the first DDR group; it is not a sample edge. The flash samples
    // that stable group on the following rising edge, then samples every edge.
    always @(posedge clk) begin
        if (dut.ddr_en && dut.edge_tick && qspi_cs !== 3'b111) begin
            case (dut.master_controller.phase)
                CTRL_ADDRESS, CTRL_MODE, CTRL_TX_DATA: begin
                    if (!ddr_tx_first_edge_seen) begin
                        ddr_tx_first_edge_seen = 1'b1;
                        check(dut.qspi_sclk === 1'b1,
                              "DDR TX first edge should be falling-edge launch after SDR instruction");
                    end else begin
                        if (!ddr_tx_first_sample_seen) begin
                            check(dut.qspi_sclk === 1'b0,
                                  "DDR TX first group should be sampled on rising edge after launch");
                            ddr_tx_first_sample_seen = 1'b1;
                        end
                        case (dut.master_controller.phase)
                            CTRL_ADDRESS: capture_tx_group(expected_addr_io_width, qspi_io);
                            CTRL_MODE:    capture_tx_group(expected_mode_io_width, qspi_io);
                            CTRL_TX_DATA: capture_tx_group(expected_data_io_width, qspi_io);
                            default:      ;
                        endcase
                    end
                end
                default:      ;
            endcase

            // For DDR RX, the terminal dummy falling edge is the flash's
            // launch boundary. D0 is already on the bus for the next rising
            // edge, which is the controller's first sample edge.
            if (dut.master_controller.phase == CTRL_DUMMY &&
                flash_expected_dummy_cycles > 0 &&
                dut.qspi_sclk === 1'b1) begin
                if (flash_dummy_falling_count >= flash_expected_dummy_cycles - 1) begin
                    check(!flash_ddr_response_started,
                          "DDR flash response launch detected more than once");
                    flash_ddr_response_started <= 1'b1;
                    flash_ddr_launch_edge_pending = 1'b1;
                    flash_ddr_launch_seen = 1'b1;
                end else begin
                    flash_dummy_falling_count++;
                end
            end
        end
    end

    // The shifter's registered byte-done pulse becomes visible immediately
    // after the final falling sample edge. Confirm that it forces all host
    // lanes high-Z during the latency cycle, before the FSM changes phase.
    always @(posedge dut.io_force_release) begin
        #1;
        check(dut.qspi_sclk === 1'b0,
              "DDR TX-to-latency release did not coincide with final falling sample edge");
        check(qspi_io === 4'bzzzz,
              "DDR TX-to-latency turnaround did not release QSPI IO immediately after final sample");
        ddr_turnaround_release_seen = 1'b1;
    end

    task automatic capture_tx_group(input logic [2:0] width,
                                    input logic [3:0] sample);
        case (width)
            3'd1: begin
                check(!$isunknown(sample[0]),
                      "flash BFM: unknown value observed on TX IO0");
                tx_capture_shift = {tx_capture_shift[6:0], sample[0]};
            end
            3'd2: begin
                check(!$isunknown(sample[1:0]),
                      "flash BFM: unknown value observed on TX IO0-IO1");
                tx_capture_shift = {tx_capture_shift[5:0], sample[1:0]};
            end
            3'd4: begin
                check(!$isunknown(sample),
                      "flash BFM: unknown value observed on TX IO0-IO3");
                tx_capture_shift = {tx_capture_shift[3:0], sample};
            end
            default: begin
                check(1'b0, "flash BFM: invalid TX lane width");
            end
        endcase

        if (width == 3'd1 || width == 3'd2 || width == 3'd4)
            tx_capture_bits += width;

        if (tx_capture_bits == 8) begin
            if (tx_capture_count < MAX_CAPTURE_BYTES) begin
                tx_capture[tx_capture_count] = tx_capture_shift;
                tx_capture_count++;
            end else begin
                check(1'b0, "flash BFM: TX capture buffer overflow");
            end
            tx_capture_shift = '0;
            tx_capture_bits = 0;
        end
    endtask

    // SDR: present one group for the rising sample, then advance on falling.
    // DDR: D0 is launched at the terminal dummy falling edge and sampled at
    // the following rising edge; advance only after each subsequent SCLK edge.
    always @(dut.qspi_sclk) begin
        if (qspi_cs !== 3'b111 && dut.ddr_en &&
            (flash_ddr_response_started ||
             dut.master_controller.phase == CTRL_RX_DATA)) begin
            if (flash_ddr_launch_edge_pending) begin
                flash_ddr_launch_edge_pending = 1'b0;
            end else begin
                flash_advance_response();
            end
        end else if (qspi_cs !== 3'b111 &&
                     dut.master_controller.phase == CTRL_RX_DATA) begin
            if (!dut.ddr_en && dut.qspi_sclk === 1'b0) begin
                if (flash_rx_edge_seen)
                    flash_advance_response();
                else
                    flash_rx_edge_seen = 1'b1;
            end
        end else begin
            flash_rx_edge_seen = 1'b0;
        end
    end

     task automatic flash_clear_response;
        flash_response_count = 0;
        flash_response_width = 1;
        flash_response_group = 0;
        flash_io_out = '0;
        flash_drive_mask = '0;
        flash_rx_edge_seen = 1'b0;
        flash_expected_dummy_cycles = 0;
        flash_dummy_falling_count = 0;
        flash_ddr_response_started = 1'b0;
        flash_ddr_launch_edge_pending = 1'b0;
        flash_ddr_launch_seen = 1'b0;
    endtask

    task automatic flash_set_response(input logic [2:0] response_width,
                                      input logic [7:0] response_byte0,
                                      input logic [7:0] response_byte1,
                                      input int dummy_cycles);
        flash_response_width = response_width;
        flash_response[0] = response_byte0;
        flash_response[1] = response_byte1;
        flash_response_count = 2;
        flash_response_group = 0;
        flash_rx_edge_seen = 1'b0;
        flash_expected_dummy_cycles = dummy_cycles;
        flash_dummy_falling_count = 0;
        flash_ddr_response_started = 1'b0;
        flash_ddr_launch_edge_pending = 1'b0;
        flash_ddr_launch_seen = 1'b0;
        flash_load_current_group();
    endtask

    task automatic flash_load_current_group;
        int groups_per_byte;
        int byte_index;
        int group_index;

        case (flash_response_width)
            3'd1, 3'd2, 3'd4: groups_per_byte = 8 / flash_response_width;
            default:          groups_per_byte = 1;
        endcase
        byte_index = flash_response_group / groups_per_byte;
        group_index = flash_response_group % groups_per_byte;

        if (byte_index >= flash_response_count) begin
            flash_io_out = 4'b0000;
        end else begin
            case (flash_response_width)
                // In standard SPI, flash output data is on SO/IO1.
                3'd1: flash_io_out = {2'b00,
                                       flash_response[byte_index][7-group_index], 1'b0};
                3'd2: flash_io_out = {2'b00,
                                       flash_response[byte_index][7-(group_index*2) -: 2]};
                3'd4: flash_io_out = flash_response[byte_index][7-(group_index*4) -: 4];
                default: flash_io_out = 4'b0000;
            endcase
        end

        case (flash_response_width)
            3'd1:    flash_drive_mask = 4'b0010; // SO/IO1 only
            3'd2:    flash_drive_mask = 4'b0011; // IO0 and IO1
            3'd4:    flash_drive_mask = 4'b1111; // IO0 through IO3
            default: flash_drive_mask = 4'b0000;
        endcase
    endtask

    task automatic flash_advance_response;
        int total_groups;

        total_groups = flash_response_count * (8 / flash_response_width);
        if (flash_response_group < total_groups) begin
            flash_response_group++;
            flash_load_current_group();
        end
    endtask

    // There is no flash model driving qspi_io for this transmit-only command.
    // The monitor verifies the selected CS and the configured lane ownership
    // for every phase that is visible on the external bus.
    always @(posedge clk) begin
        if (qspi_cs !== 3'b111) begin
            active_seen = 1'b1;
            check_selected_cs();

            case (dut.master_controller.phase)
                CTRL_INSTRUCTION: begin
                    instruction_seen = 1'b1;
                    check_phase_bus(expected_cmd_io_width, 1'b1, 1'b0, "instruction");
                end
                CTRL_ADDRESS: begin
                    address_seen = 1'b1;
                    if (dut.io_force_release)
                        check_phase_bus(3'd0, 1'b0, 1'b0,
                                        "DDR address-to-dummy turnaround");
                    else
                        check_phase_bus(expected_addr_io_width, 1'b1, 1'b0,
                                        "address");
                end
                CTRL_MODE: begin
                    mode_seen = 1'b1;
                    if (dut.io_force_release)
                        check_phase_bus(3'd0, 1'b0, 1'b0,
                                        "DDR mode-to-dummy turnaround");
                    else
                        check_phase_bus(expected_mode_io_width, 1'b1, 1'b0,
                                        "mode");
                end
                CTRL_DUMMY: begin
                    dummy_seen = 1'b1;
                    check_phase_bus(3'd0, 1'b0, 1'b0, "dummy");
                end
                CTRL_TX_DATA: begin
                    tx_data_seen = 1'b1;
                    check_phase_bus(expected_data_io_width, 1'b1, 1'b0, "TX data");
                end
                CTRL_RX_DATA: begin
                    rx_data_seen = 1'b1;
                    check_phase_bus(expected_data_io_width, 1'b0, 1'b1, "RX data");
                end
                default: begin
                    check_phase_bus(3'd0, 1'b0, 1'b0, "non-data");
                end
            endcase
        end else begin
            check_phase_bus(3'd0, 1'b0, 1'b0, "idle");
        end
    end

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    task automatic clear_transaction_observations;
        active_seen = 1'b0;
        instruction_seen = 1'b0;
        address_seen = 1'b0;
        mode_seen = 1'b0;
        dummy_seen = 1'b0;
        tx_data_seen = 1'b0;
        rx_data_seen = 1'b0;
        tx_capture_count = 0;
        tx_capture_shift = '0;
        tx_capture_bits = 0;
        ddr_tx_first_edge_seen = 1'b0;
        ddr_tx_first_sample_seen = 1'b0;
        ddr_turnaround_release_seen = 1'b0;
    endtask

    task automatic set_expected_transaction(input logic [1:0] cs_num,
                                             input logic [2:0] cmd_width,
                                             input logic [2:0] addr_width,
                                             input logic [2:0] mode_width,
                                             input logic [2:0] data_width);
        expected_cs_num = cs_num;
        expected_cmd_io_width = cmd_width;
        expected_addr_io_width = addr_width;
        expected_mode_io_width = mode_width;
        expected_data_io_width = data_width;
    endtask

    task automatic check_selected_cs;
        logic [2:0] expected_cs;

        expected_cs = 3'b111;
        expected_cs[expected_cs_num] = 1'b0;
        check(qspi_cs === expected_cs,
              $sformatf("QSPI CS: expected slave %0d, observed %03b",
                        expected_cs_num, qspi_cs));
    endtask

    // Check actual bus ownership and the active lane mapping for each phase.
    // The flash's single-lane output is on IO1; controller single-lane input
    // phases (instruction/address/mode/TX data) are driven on IO0.
    task automatic check_phase_bus(input logic [2:0] expected_width,
                                   input logic dut_drives_bus,
                                   input logic flash_drives_bus,
                                   input string phase_name);
        if (!dut_drives_bus && !flash_drives_bus) begin
            check(qspi_io === 4'bzzzz,
                  $sformatf("%s phase: QSPI bus must be released", phase_name));
        end else if (dut_drives_bus && flash_drives_bus) begin
            check(1'b0,
                  $sformatf("%s phase: DUT and flash must not drive simultaneously",
                            phase_name));
        end else begin
            case (expected_width)
                3'd1: begin
                    if (flash_drives_bus)
                        check(qspi_io[3:2] === 2'bzz && qspi_io[0] === 1'bz &&
                              !$isunknown(qspi_io[1]),
                              $sformatf("%s phase: expected flash drive on SO/IO1 only",
                                        phase_name));
                    else
                        check(qspi_io[3:1] === 3'bzzz && !$isunknown(qspi_io[0]),
                              $sformatf("%s phase: expected DUT drive on SI/IO0 only",
                                        phase_name));
                end
                3'd2: check(qspi_io[3:2] === 2'bzz &&
                            !$isunknown(qspi_io[1:0]),
                            $sformatf("%s phase: expected dual-lane drive", phase_name));
                3'd4: check(!$isunknown(qspi_io) &&
                            qspi_io !== 4'bzzzz,
                            $sformatf("%s phase: expected quad-lane drive", phase_name));
                default: check(qspi_io === 4'bzzzz,
                               $sformatf("%s phase: invalid/zero width must release bus",
                                         phase_name));
            endcase
        end
    endtask

    task automatic csr_write(input logic [4:0] write_addr,
                             input logic [31:0] data);
        @(negedge clk);
        cs = 1'b1; read = 1'b0; write = 1'b1;
        addr = write_addr; wr_data = data;
        @(posedge clk);
        #1 cs = 1'b0; write = 1'b0; addr = '0; wr_data = '0;
    endtask

    task automatic csr_read(input logic [4:0] read_addr,
                            input logic [31:0] expected,
                            input string message);
        @(negedge clk);
        cs = 1'b1; read = 1'b1; write = 1'b0;
        addr = read_addr;
        #1 check(rd_data === expected,
                 $sformatf("%s: expected %08h, got %08h", message, expected, rd_data));
        @(posedge clk);
        #1 cs = 1'b0; read = 1'b0; addr = '0;
    endtask

    task automatic reset_dut;
        reset = 1'b1;
        repeat (2) @(posedge clk);
        #1 reset = 1'b0;
        @(posedge clk);
        #1;
    endtask

    // Hold a public STATUS_REG read until the controller reports ready.
    // Because rd_data is combinational, wait() resumes as soon as
    // STATUS_REG[0] changes to 1; no divider-dependent delay is required.
    task automatic wait_for_ready;
        @(negedge clk);
        cs = 1'b1; read = 1'b1; write = 1'b0;
        addr = STATUS_REG;
        wait (rd_data[0] === 1'b1);
        @(posedge clk);
        #1 cs = 1'b0; read = 1'b0; addr = '0;
    endtask

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        cs = 1'b0; read = 1'b0; write = 1'b0;
        addr = '0; wr_data = '0;
        failures = 0;
        active_seen = 0; instruction_seen = 0;
        address_seen = 0; mode_seen = 0; dummy_seen = 0;
        tx_data_seen = 0; rx_data_seen = 0;
        flash_clear_response();
        clear_transaction_observations();

        reset_dut();

        // STATUS_REG: ready=1, TX FIFO not full, RX FIFO empty.
        csr_read(STATUS_REG, 32'h0000_0005, "reset status");
        // DIVIDER_REG=3 sets the QSPI clock divider for every scenario below.
        csr_write(DIVIDER_REG, 32'h0000_0003);

        // CONTROL_REG=0: CPOL=0, CPHA=0, MSB-first, SDR (DDR disabled).
        csr_write(CONTROL_REG, 32'h0000_0000);

        // SDR Quad Page Program (QPP, opcode 32h), phase widths 1-1-4:
        //   instruction: 32h, 8 bits on IO0 (1 lane)
        //   address:     12_3456h, 24 bits on IO0 (1 lane)
        //   data:        A5h, 8 bits on IO[3:0] (4 lanes); one byte total
        // No mode or dummy phase is enabled. CMD_CONF (0002_0253h) means:
        //   has_opcode=1, has_addr=1, has_tx_data=1, has_rx_data=0,
        //   opcode width=1, address width=1, data width=4, address length=24.
        // CMD_DATA (0000_0032h) supplies opcode 32h; FADDR supplies 12_3456h;
        // TX_LEN=1 byte; TX_DATA=A5h; CS_REG=2 selects slave 2.
        // Real flash prerequisites: WREN must be sent and QUAD must be enabled.
        set_expected_transaction(2, 3'd1, 3'd1, 3'd1, 3'd4);
        csr_write(CMD_CONF_REG, 32'h0002_0253);
        csr_write(CMD_DATA_REG, 32'h0000_0032);
        csr_write(FADDR_REG, 32'h0012_3456);
        csr_write(TX_LEN_REG, 32'h0000_0001);
        csr_write(CS_REG, 32'h0000_0002);
        csr_write(TX_DATA_REG, 32'h0000_00A5);

        // The bus is idle and released before PULSE_REG is written.
        check(qspi_cs === 3'b111, "pre-start: all chip selects must be inactive");
        check(qspi_io === 4'bzzzz, "pre-start: QSPI bus must be released");

        // PULSE_REG is a one-cycle, ready-qualified transaction request.
        csr_write(PULSE_REG, 32'h0000_0001);

        wait_for_ready();
        #1;

        check(active_seen, "transaction never asserted chip select");
        check(instruction_seen, "transaction never reached instruction phase");
        check(address_seen, "transaction never reached address phase");
        check(tx_data_seen, "transaction never reached TX data phase");
        check(tx_capture_count >= 5, "flash BFM did not capture the complete TX command");
        if (tx_capture_count >= 5) begin
            check(tx_capture[0] === 8'h32, "TX capture: opcode mismatch");
            check(tx_capture[1] === 8'h12 && tx_capture[2] === 8'h34 &&
                  tx_capture[3] === 8'h56,
                  "TX capture: address mismatch");
            check(tx_capture[4] === 8'hA5, "TX capture: data mismatch");
        end
        check(qspi_cs === 3'b111, "post-transaction: chip select did not release");
        check(qspi_io === 4'bzzzz, "post-transaction: QSPI bus did not release");

        csr_read(STATUS_REG, 32'h0000_0005, "post-transaction status");

        // Generic four-phase SDR write, widths 1-1-1-1:
        //   instruction: 02h on IO0 (1 lane); address: 00_1357h on IO0 (1)
        //   mode:        3Ch on IO0 (1); TX data: A6h on IO0 (1), one byte
        // No dummy or RX phase. CMD_CONF (0000_9257h) enables opcode, address,
        // mode, and TX; all four phase widths are 1 and address length is 24.
        // CMD_DATA (0000_3C02h) carries opcode 02h in [7:0] and mode 3Ch in
        // [15:8]; FADDR=00_1357h, TX_LEN=1, TX_DATA=A6h, CS_REG=0.
        // This is controller phase-coverage, not a legal S25FL128S PP sequence:
        // its standard Page Program is 1-1-1 and has no mode phase.
        clear_transaction_observations();
        set_expected_transaction(0, 3'd1, 3'd1, 3'd1, 3'd1);
        csr_write(CMD_CONF_REG, 32'h0000_9257);
        csr_write(CMD_DATA_REG, 32'h0000_3C02);
        csr_write(FADDR_REG, 32'h0000_1357);
        csr_write(TX_LEN_REG, 32'h0000_0001);
        csr_write(CS_REG, 32'h0000_0000);
        csr_write(TX_DATA_REG, 32'h0000_00A6);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen, "1-1-1-1 write missed instruction phase");
        check(address_seen, "1-1-1-1 write missed address phase");
        check(mode_seen, "1-1-1-1 write missed mode phase");
        check(tx_data_seen, "1-1-1-1 write missed TX data phase");
        check(tx_capture_count >= 6,
              "1-1-1-1 write did not capture opcode/address/mode/data");
        if (tx_capture_count >= 6) begin
            check(tx_capture[0] === 8'h02, "1-1-1-1 write opcode mismatch");
            check(tx_capture[1] === 8'h00 && tx_capture[2] === 8'h13 &&
                  tx_capture[3] === 8'h57,
                  "1-1-1-1 write address mismatch");
            check(tx_capture[4] === 8'h3C, "1-1-1-1 write mode mismatch");
            check(tx_capture[5] === 8'hA6, "1-1-1-1 write data mismatch");
        end

        // SDR standard READ (S25FL128S opcode 03h), widths 1-1-1:
        //   instruction: 03h on IO0 (1 lane); address: 00_2468h on IO0 (1)
        //   data:        flash returns 96h then 2Dh on IO0 (1), 2 bytes total
        // No mode or dummy phase. CMD_CONF (0000_8263h) enables opcode,
        // address, and RX; command/address/data widths are each 1; address
        // length is 24 bits. CMD_DATA=0000_0003h (opcode 03h), FADDR=2468h,
        // TX_LEN=0, RX_LEN=2 bytes, CS_REG=1. The flash BFM is preloaded with
        // response bytes 96h and 2Dh.
        clear_transaction_observations();
        flash_set_response(3'd1, 8'h96, 8'h2D, 0);
        set_expected_transaction(1, 3'd1, 3'd1, 3'd1, 3'd1);
        csr_write(CMD_CONF_REG, 32'h0000_8263);
        csr_write(CMD_DATA_REG, 32'h0000_0003);
        csr_write(FADDR_REG, 32'h0000_2468);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0001);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen, "1-1-1 read missed instruction phase");
        check(address_seen, "1-1-1 read missed address phase");
        check(rx_data_seen, "1-1-1 read missed RX data phase");
        check(!mode_seen && !dummy_seen,
              "1-1-1 read unexpectedly entered mode/dummy phase");
        csr_read(RX_DATA_REG, 32'h0000_0096, "1-1-1 first RX byte");
        csr_read(RX_DATA_REG, 32'h0000_002D, "1-1-1 second RX byte");

        // SDR Dual I/O Read (DIOR, S25FL128S opcode BBh), widths 1-2-2:
        //   instruction: BBh on IO0 (1 lane)
        //   address:     00_3579h on IO[1:0] (2 lanes)
        //   mode:        00h on IO[1:0] (2 lanes); one dummy cycle follows
        //   data:        flash returns 69h then B4h on IO[1:0] (2 lanes)
        // CMD_CONF (0001_246Fh) enables opcode/address/mode/dummy/RX; widths
        // are command=1, address=2, mode=2, data=2; address length=24 bits.
        // CMD_DATA (0001_00BBh) sets opcode BBh, mode=00h, dummy count=1;
        // FADDR=3579h, TX_LEN=0, RX_LEN=2 bytes, CS_REG=2. BFM response is
        // 69h, B4h. Dummy=1 is the configured test value; actual required
        // latency depends on the physical flash's latency-code configuration.
        clear_transaction_observations();
        flash_set_response(3'd2, 8'h69, 8'hB4, 1);
        set_expected_transaction(2, 3'd1, 3'd2, 3'd2, 3'd2);
        csr_write(CMD_CONF_REG, 32'h0001_246F);
        csr_write(CMD_DATA_REG, 32'h0001_00BB);
        csr_write(FADDR_REG, 32'h0000_3579);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0002);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen, "1-2-2 read missed instruction phase");
        check(address_seen, "1-2-2 read missed address phase");
        check(mode_seen, "1-2-2 read missed mode phase");
        check(dummy_seen, "1-2-2 read missed dummy phase");
        check(rx_data_seen, "1-2-2 read missed RX data phase");
        check_phase_bus(3'd0, 1'b0, 1'b0, "1-2-2 RX release");
        check(tx_capture_count >= 5,
              "1-2-2 read did not capture opcode/address/mode");
        if (tx_capture_count >= 5) begin
            check(tx_capture[0] === 8'hBB, "1-2-2 read opcode mismatch");
            check(tx_capture[1] === 8'h00 && tx_capture[2] === 8'h35 &&
                  tx_capture[3] === 8'h79,
                  "1-2-2 read address mismatch");
            check(tx_capture[4] === 8'h00, "1-2-2 read mode mismatch");
        end
        csr_read(RX_DATA_REG, 32'h0000_0069, "1-2-2 first RX byte");
        csr_read(RX_DATA_REG, 32'h0000_00B4, "1-2-2 second RX byte");

        // SDR Quad I/O Read (QIOR, S25FL128S opcode EBh), widths 1-4-4:
        //   instruction: EBh on IO0 (1 lane)
        //   address:     45_6789h on IO[3:0] (4 lanes)
        //   mode:        00h on IO[3:0] (4 lanes); one dummy cycle follows
        //   data:        flash returns 5Ah then C3h on IO[3:0] (4 lanes)
        // CMD_CONF (0002_486Fh) enables opcode/address/mode/dummy/RX; widths
        // are command=1, address=4, mode=4, data=4; address length=24 bits.
        // CMD_DATA (0001_00EBh) sets opcode EBh, mode=00h, dummy count=1;
        // FADDR=45_6789h, TX_LEN=0, RX_LEN=2 bytes, CS_REG=1. The BFM
        // supplies 5Ah and C3h and captures the outgoing opcode/address/mode.
        // The one dummy cycle is the test configuration; a real flash's
        // required latency must match its configured latency code.
        clear_transaction_observations();
        flash_set_response(3'd4, 8'h5A, 8'hC3, 1);
        set_expected_transaction(1, 3'd1, 3'd4, 3'd4, 3'd4);
        csr_write(CMD_CONF_REG, 32'h0002_486F);
        csr_write(CMD_DATA_REG, 32'h0001_00EB);
        csr_write(FADDR_REG, 32'h0045_6789);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0001);
        csr_write(PULSE_REG, 32'h0000_0001);

        wait_for_ready();
        #1;

        check(active_seen, "RX transaction never asserted chip select");
        check(instruction_seen, "RX transaction never reached instruction phase");
        check(address_seen, "RX transaction never reached address phase");
        check(mode_seen, "RX transaction never reached mode phase");
        check(dummy_seen, "RX transaction never reached dummy phase");
        check(rx_data_seen, "RX transaction never reached RX data phase");
        check(tx_capture_count >= 4, "flash BFM did not capture the RX command/address");
        if (tx_capture_count >= 4) begin
            check(tx_capture[0] === 8'hEB, "RX command capture: opcode mismatch");
            check(tx_capture[1] === 8'h45 && tx_capture[2] === 8'h67 &&
                  tx_capture[3] === 8'h89,
                  "RX command capture: address mismatch");
        end

        csr_read(RX_DATA_REG, 32'h0000_005A, "first RX response byte");
        csr_read(RX_DATA_REG, 32'h0000_00C3, "second RX response byte");
        csr_read(STATUS_REG, 32'h0000_0005, "RX transaction status");

        // CONTROL_REG bit 3 enables DDR. The S25FL128S DDR read opcodes keep
        // the instruction byte SDR; address/mode/data (where present) use
        // both SCLK edges. These are reads only: the flash has no DDR program
        // command. Dummy=1 is a controller test setting; real latency must
        // match the flash's CR1 latency configuration and clock rate.
        csr_write(CONTROL_REG, 32'h0000_0008);

        // DDR Fast Read (0Dh), phase widths 1-1-1:
        //   instruction: 0Dh, 8 bits SDR on IO0 (1 lane)
        //   address:     00_1357h on IO0 (1 lane), DDR on both SCLK edges
        //   dummy:       one configured DDR dummy cycle, all IO released
        //   data:        flash returns 3Ch then A7h on SO/IO1 (1 lane), DDR
        // HPLC form has no mode phase. CMD_CONF=0000_826Bh enables opcode,
        // address, dummy, RX; width=1 for all bus phases; address=24 bits.
        // CMD_DATA=0001_000Dh sets dummy count=1 and opcode=0Dh. CS=0.
        clear_transaction_observations();
        flash_set_response(3'd1, 8'h3C, 8'hA7, 1);
        set_expected_transaction(0, 3'd1, 3'd1, 3'd1, 3'd1);
        csr_write(CMD_CONF_REG, 32'h0000_826B);
        csr_write(CMD_DATA_REG, 32'h0001_000D);
        csr_write(FADDR_REG, 32'h0000_1357);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0000);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen && address_seen && dummy_seen && rx_data_seen,
              "DDR 1-1-1 read missed one or more configured phases");
        check(!mode_seen, "DDR 1-1-1 HPLC read unexpectedly entered mode phase");
        check(tx_capture_count >= 4, "DDR 1-1-1 read did not capture opcode/address");
        check(ddr_tx_first_edge_seen && ddr_tx_first_sample_seen,
              "DDR 1-1-1 did not launch address on falling then sample on rising edge");
        check(ddr_turnaround_release_seen,
              "DDR 1-1-1 host did not release IO immediately after final address sample");
        check(flash_ddr_launch_seen,
              "DDR 1-1-1 flash did not launch D0 on terminal dummy falling edge");
        if (tx_capture_count >= 4) begin
            check(tx_capture[0] === 8'h0D, "DDR 1-1-1 opcode mismatch");
            check(tx_capture[1] === 8'h00 && tx_capture[2] === 8'h13 &&
                  tx_capture[3] === 8'h57,
                  "DDR 1-1-1 address mismatch");
        end
        csr_read(RX_DATA_REG, 32'h0000_003C, "DDR 1-1-1 first RX byte");
        csr_read(RX_DATA_REG, 32'h0000_00A7, "DDR 1-1-1 second RX byte");

        // DDR Dual I/O Read (BDh), phase widths 1-2-2:
        //   instruction: BDh, 8 bits SDR on IO0 (1 lane)
        //   address:     00_2468h on IO[1:0] (2 lanes), DDR on both edges
        //   dummy:       one configured DDR dummy cycle, all IO released
        //   data:        flash returns 69h then B4h on IO[1:0] (2 lanes), DDR
        // HPLC form has no mode phase. CMD_CONF=0001_046Bh enables opcode,
        // address, dummy, RX; address/data widths=2 and address=24 bits.
        // CMD_DATA=0001_00BD sets dummy count=1 and opcode=BDh. CS=2.
        clear_transaction_observations();
        flash_set_response(3'd2, 8'h69, 8'hB4, 1);
        set_expected_transaction(2, 3'd1, 3'd2, 3'd2, 3'd2);
        csr_write(CMD_CONF_REG, 32'h0001_046B);
        csr_write(CMD_DATA_REG, 32'h0001_00BD);
        csr_write(FADDR_REG, 32'h0000_2468);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0002);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen && address_seen && dummy_seen && rx_data_seen,
              "DDR 1-2-2 read missed one or more configured phases");
        check(!mode_seen, "DDR 1-2-2 HPLC read unexpectedly entered mode phase");
        check(tx_capture_count >= 4, "DDR 1-2-2 read did not capture opcode/address");
        check(ddr_tx_first_edge_seen && ddr_tx_first_sample_seen,
              "DDR 1-2-2 did not launch address on falling then sample on rising edge");
        check(ddr_turnaround_release_seen,
              "DDR 1-2-2 host did not release IO immediately after final address sample");
        check(flash_ddr_launch_seen,
              "DDR 1-2-2 flash did not launch D0 on terminal dummy falling edge");
        if (tx_capture_count >= 4) begin
            check(tx_capture[0] === 8'hBD, "DDR 1-2-2 opcode mismatch");
            check(tx_capture[1] === 8'h00 && tx_capture[2] === 8'h24 &&
                  tx_capture[3] === 8'h68,
                  "DDR 1-2-2 address mismatch");
        end
        csr_read(RX_DATA_REG, 32'h0000_0069, "DDR 1-2-2 first RX byte");
        csr_read(RX_DATA_REG, 32'h0000_00B4, "DDR 1-2-2 second RX byte");

        // DDR Quad I/O Read (EDh), phase widths 1-4-4:
        //   instruction: EDh, 8 bits SDR on IO0 (1 lane)
        //   address:     00_3579h on IO[3:0] (4 lanes), DDR on both edges
        //   mode:        00h on IO[3:0] (4 lanes), DDR
        //   dummy:       one configured DDR dummy cycle, all IO released
        //   data:        flash returns 5Ah then C3h on IO[3:0] (4 lanes), DDR
        // CMD_CONF=0002_486F enables opcode/address/mode/dummy/RX; address,
        // mode, and data widths=4; address=24 bits. CMD_DATA=0001_00ED
        // sets mode=00h, dummy count=1, opcode=EDh. CS=1. QUAD must be
        // enabled in the actual flash for this command to operate.
        clear_transaction_observations();
        flash_set_response(3'd4, 8'h5A, 8'hC3, 1);
        set_expected_transaction(1, 3'd1, 3'd4, 3'd4, 3'd4);
        csr_write(CMD_CONF_REG, 32'h0002_486F);
        csr_write(CMD_DATA_REG, 32'h0001_00ED);
        csr_write(FADDR_REG, 32'h0000_3579);
        csr_write(TX_LEN_REG, 32'h0000_0000);
        csr_write(RX_LEN_REG, 32'h0000_0002);
        csr_write(CS_REG, 32'h0000_0001);
        csr_write(PULSE_REG, 32'h0000_0001);
        wait_for_ready();
        #1;
        check(instruction_seen && address_seen && mode_seen && dummy_seen &&
              rx_data_seen,
              "DDR 1-4-4 read missed one or more configured phases");
        check(tx_capture_count >= 5,
              "DDR 1-4-4 read did not capture opcode/address/mode");
        check(ddr_tx_first_edge_seen && ddr_tx_first_sample_seen,
              "DDR 1-4-4 did not launch address on falling then sample on rising edge");
        check(ddr_turnaround_release_seen,
              "DDR 1-4-4 host did not release IO immediately after final mode sample");
        check(flash_ddr_launch_seen,
              "DDR 1-4-4 flash did not launch D0 on terminal dummy falling edge");
        if (tx_capture_count >= 5) begin
            check(tx_capture[0] === 8'hED, "DDR 1-4-4 opcode mismatch");
            check(tx_capture[1] === 8'h00 && tx_capture[2] === 8'h35 &&
                  tx_capture[3] === 8'h79,
                  "DDR 1-4-4 address mismatch");
            check(tx_capture[4] === 8'h00, "DDR 1-4-4 mode mismatch");
        end
        csr_read(RX_DATA_REG, 32'h0000_005A, "DDR 1-4-4 first RX byte");
        csr_read(RX_DATA_REG, 32'h0000_00C3, "DDR 1-4-4 second RX byte");
        csr_write(CONTROL_REG, 32'h0000_0000);

        if (failures == 0)
            $display("tb_top_qspi_core: PASS - complete MMIO-to-QSPI transaction verified");
        else
            $fatal(1, "tb_top_qspi_core: %0d failure(s)", failures);
        $finish;
    end

endmodule
