`timescale 1ns / 1ps

// Self-checking testbench for fifo.
// The test covers reset, FIFO ordering, pointer wraparound, and protection
// against writes while full or reads while empty.
module tb_qspi_fifo;

    localparam int DATA_WIDTH = 8;
    localparam int ADDR_WIDTH = 3;
    localparam int FIFO_DEPTH = 1 << ADDR_WIDTH;

    logic clk;
    logic reset;
    logic rd;
    logic wr;
    logic [DATA_WIDTH-1:0] w_data;
    logic [DATA_WIDTH-1:0] r_data;
    logic empty;
    logic full;
    int failures;

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_qspi_fifo.vcd");
        $dumpvars(0, tb_qspi_fifo);
    end

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    task automatic apply_reset;
        begin
            rd     = 1'b0;
            wr     = 1'b0;
            w_data = '0;
            reset  = 1'b1;
            #1;
            check(empty && !full, "Reset: FIFO must be empty and not full");

            @(negedge clk);
            reset = 1'b0;
            @(posedge clk);
            #1;
            check(empty && !full,
                  "Reset release: FIFO must remain empty and not full");
        end
    endtask

    task automatic write_word(input logic [DATA_WIDTH-1:0] data);
        begin
            @(negedge clk);
            w_data = data;
            wr     = 1'b1;
            rd     = 1'b0;
            @(posedge clk);
            #1;
            wr = 1'b0;
        end
    endtask

    task automatic read_word(input logic [DATA_WIDTH-1:0] expected);
        begin
            @(negedge clk);
            check(!empty, $sformatf("Read %02h: FIFO unexpectedly empty", expected));
            check(r_data === expected,
                  $sformatf("Read data: expected %02h, got %02h", expected, r_data));
            rd = 1'b1;
            wr = 1'b0;
            @(posedge clk);
            #1;
            rd = 1'b0;
        end
    endtask

    initial begin
        failures = 0;
        apply_reset();

        // A read while empty must not change FIFO state.
        @(negedge clk);
        rd = 1'b1;
        @(posedge clk);
        #1;
        rd = 1'b0;
        check(empty && !full, "Read while empty: FIFO status changed");

        // Fill the FIFO, checking that all entries are accepted in order.
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            write_word(DATA_WIDTH'(i));
            if (i == FIFO_DEPTH-1)
                check(full && !empty, "Fill: FIFO must be full after final write");
            else
                check(!full && !empty, "Fill: FIFO status incorrect before full");
        end

        // A write while full must be ignored.
        write_word(8'hEE);
        check(full && !empty, "Write while full: FIFO status changed");

        // Drain the FIFO and verify FIFO ordering across the wrapped pointers.
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            read_word(DATA_WIDTH'(i));
            if (i == FIFO_DEPTH-1)
                check(empty && !full, "Drain: FIFO must be empty after final read");
            else
                check(!empty && !full, "Drain: FIFO status incorrect before empty");
        end

        // A read while empty must not expose a new transaction.
        @(negedge clk);
        rd = 1'b1;
        @(posedge clk);
        #1;
        rd = 1'b0;
        check(empty && !full, "Second read while empty: FIFO status changed");

        // Simultaneous read/write in the normal (neither boundary) state.
        write_word(8'hA1);
        write_word(8'hB2);
        @(negedge clk);
        check(r_data === 8'hA1, "Concurrent operation: wrong head before transfer");
        w_data = 8'hC3;
        wr     = 1'b1;
        rd     = 1'b1;
        @(posedge clk);
        #1;
        wr = 1'b0;
        rd = 1'b0;
        check(!empty && !full, "Concurrent operation: FIFO status changed");
        check(r_data === 8'hB2,
              $sformatf("Concurrent operation: expected next head B2, got %02h", r_data));
        read_word(8'hB2);
        read_word(8'hC3);
        check(empty && !full, "Concurrent operation: FIFO did not drain");

        if (failures == 0)
            $display("tb_qspi_fifo: PASS - all FIFO checks completed");
        else
            $fatal(1, "tb_qspi_fifo: %0d failure(s)", failures);

        $finish;
    end

endmodule
