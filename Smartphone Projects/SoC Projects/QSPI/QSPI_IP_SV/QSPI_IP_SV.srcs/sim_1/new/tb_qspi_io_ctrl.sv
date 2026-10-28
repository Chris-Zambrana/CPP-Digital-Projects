`timescale 1ns / 1ps

// Self-checking testbench for qspi_io_ctrl.
//
// The DUT has no clock: phase and bus_width determine which IO bits it drives,
// while io_rx continuously reflects the resolved value on the bidirectional
// bus.  The checks below cover every phase, all supported bus widths, and
// external-device drive during receive and idle states.

module tb_qspi_io_ctrl;

    import qspi_types_pkg::*;

    state_type phase;
    logic [2:0] bus_width;
    logic force_release;
    logic [3:0] io_tx;
    logic [3:0] io_rx;
    tri   [3:0] qspi_io;
    logic [3:0] external_drive;
    logic       external_drive_en;

    int failures;

    qspi_io_ctrl dut (
        .phase    (phase),
        .bus_width(bus_width),
        .force_release(force_release),
        .io_tx    (io_tx),
        .io_rx    (io_rx),
        .qspi_io  (qspi_io)
    );

    // Model a flash/device driving the bus during receive phases.
    assign qspi_io = external_drive_en ? external_drive : 4'bz;

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    function automatic logic is_tx_phase(input state_type test_phase);
        case (test_phase)
            CTRL_INSTRUCTION, CTRL_ADDRESS, CTRL_MODE, CTRL_TX_DATA:
                return 1'b1;
            default:
                return 1'b0;
        endcase
    endfunction

    function automatic logic [3:0] expected_drive(
        input state_type test_phase,
        input logic [2:0] test_width,
        input logic [3:0] test_tx
    );
        logic [3:0] expected;

        expected = 4'bz;
        if (is_tx_phase(test_phase)) begin
            if (test_width >= 1) expected[0] = test_tx[0];
            if (test_width >= 2) expected[1] = test_tx[1];
            if (test_width == 4) expected[3:2] = test_tx[3:2];
        end
        return expected;
    endfunction

    task automatic check_bus(
        input state_type test_phase,
        input logic [2:0] test_width,
        input logic [3:0] test_tx
    );
        logic [3:0] expected;

        phase     = test_phase;
        bus_width = test_width;
        io_tx     = test_tx;
        #1;

        expected = expected_drive(test_phase, test_width, test_tx);
        check(qspi_io === expected,
              $sformatf("phase=%s width=%0d tx=%b: expected bus=%b, got %b",
                        test_phase.name(), test_width, test_tx,
                        expected, qspi_io));
        check(io_rx === qspi_io,
              $sformatf("phase=%s width=%0d: io_rx must mirror qspi_io",
                        test_phase.name(), test_width));
    endtask

    task automatic check_external_read(
        input state_type test_phase,
        input logic [2:0] test_width,
        input logic [3:0] device_value
    );
        phase             = test_phase;
        bus_width         = test_width;
        io_tx             = 4'b0000;
        external_drive    = device_value;
        external_drive_en = 1'b1;
        #1;

        check(qspi_io === device_value,
              $sformatf("phase=%s width=%0d: expected external bus=%b, got %b",
                        test_phase.name(), test_width, device_value, qspi_io));
        check(io_rx === device_value,
              $sformatf("phase=%s width=%0d: expected io_rx=%b, got %b",
                        test_phase.name(), test_width, device_value, io_rx));

        external_drive_en = 1'b0;
    endtask

    initial begin
        failures          = 0;
        phase             = CTRL_IDLE;
        bus_width         = 3'd0;
        force_release    = 1'b0;
        io_tx             = 4'b0;
        external_drive    = 4'b0;
        external_drive_en = 1'b0;

        // Every defined phase must release the bus except the four TX phases.
        for (int state_index = 0; state_index <= int'(CTRL_CYCLE_DELAY); state_index++) begin
            check_bus(state_type'(state_index), 3'd4, 4'b1010);
        end

        // Verify the supported transmit widths and that unused lanes release.
        check_bus(CTRL_TX_DATA,     3'd0, 4'b1010);
        check_bus(CTRL_TX_DATA,     3'd1, 4'b1010);
        check_bus(CTRL_TX_DATA,     3'd2, 4'b1010);
        check_bus(CTRL_TX_DATA,     3'd4, 4'b1010);
        check_bus(CTRL_INSTRUCTION, 3'd1, 4'b0001);
        check_bus(CTRL_ADDRESS,     3'd2, 4'b0010);
        check_bus(CTRL_MODE,        3'd4, 4'b1101);

        // The DDR turnaround override must release even a normally driven
        // address bus, without changing the phase or configured lane width.
        phase = CTRL_ADDRESS;
        bus_width = 3'd4;
        io_tx = 4'b1010;
        force_release = 1'b1;
        #1;
        check(qspi_io === 4'bzzzz,
              "force_release must tri-state every host QSPI lane");
        force_release = 1'b0;

        // The receive phase must allow an external device to drive the
        // selected number of lanes. Unused lanes are modeled as high-Z.
        check_external_read(CTRL_RX_DATA, 3'd1, 4'bzzz1);
        check_external_read(CTRL_RX_DATA, 3'd2, 4'bzz10);
        check_external_read(CTRL_RX_DATA, 3'd4, 4'b0110);

        // Width zero and unsupported widths must never enable a transmitter.
        check_bus(CTRL_TX_DATA, 3'd3, 4'b1111);
        check_bus(CTRL_TX_DATA, 3'd5, 4'b1111);
        check_bus(CTRL_TX_DATA, 3'd7, 4'b1111);

        if (failures == 0)
            $display("tb_qspi_io_ctrl: PASS - all bus-drive and receive checks passed");
        else
            $fatal(1, "tb_qspi_io_ctrl: %0d failure(s)", failures);

        $finish;
    end

endmodule
