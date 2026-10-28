`timescale 1ns / 1ps

// Self-checking testbench for qspi_sclk_gen.
// Tick outputs are sampled on negedge clk; qspi_sclk updates on the following
// posedge. A VCD waveform is written to tb_qspi_sclk_gen.vcd.

module tb_qspi_sclk_gen;

    localparam int DIVIDER_WIDTH  = 4;
    localparam logic [DIVIDER_WIDTH-1:0] DIVIDER = 3;
    localparam int SCLK_CYCLES    = 8;
    localparam int CLK_PERIOD_NS  = 10;

    logic clk;
    logic reset;
    logic [DIVIDER_WIDTH-1:0] clk_div;
    logic cpol;
    logic cpha;
    logic sclk_en;
    logic eos;

    logic qspi_sclk;
    logic drive_tick;
    logic sample_tick;
    logic edge_tick;
    logic sclk_idle;

    int failures;

    qspi_sclk_gen #(
        .QSPI_DIVIDER_WIDTH(DIVIDER_WIDTH)
    ) dut0 (
        .clk        (clk),
        .reset      (reset),
        .clk_div    (clk_div),
        .cpol       (cpol),
        .cpha       (cpha),
        .sclk_en    (sclk_en),
        .eos        (eos),
        .qspi_sclk  (qspi_sclk),
        .drive_tick (drive_tick),
        .sample_tick(sample_tick),
        .edge_tick  (edge_tick),
        .sclk_idle  (sclk_idle)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    /*
    initial begin
        $dumpfile("tb_qspi_sclk_gen.vcd");
        $dumpvars(0, tb_qspi_sclk_gen);
    end
    */

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    task automatic apply_reset(input logic reset_cpol);
        cpol    = reset_cpol;
        cpha    = 1'b0;
        clk_div = DIVIDER;
        sclk_en = 1'b0;
        eos     = 1'b0;
        reset   = 1'b1;

        @(posedge clk);
        #1;
        check(qspi_sclk == reset_cpol,
              $sformatf("Reset: expected qspi_sclk=%0b, got %0b",
                        reset_cpol, qspi_sclk));
        check(sclk_idle, "Reset: expected sclk_idle=1");

        // Release asynchronous reset away from the active clock edge.
        @(negedge clk);
        reset = 1'b0;
    endtask

    task automatic run_mode(
        input logic mode_cpol,
        input logic mode_cpha,
        input string mode_name
    );
        int drive_tick_count;
        int sample_tick_count;
        int edge_tick_count;
        logic sclk_before_edge;
        time last_edge_time;
        time edge_time;

        $display("\n--- Testing %s: CPOL=%0b, CPHA=%0b ---",
                 mode_name, mode_cpol, mode_cpha);

        apply_reset(mode_cpol);

        cpha     = mode_cpha;
        sclk_en  = 1'b1;
        eos      = 1'b1;
        drive_tick_count  = 0;
        sample_tick_count = 0;
        edge_tick_count   = 0;
        last_edge_time    = 0;

        // CPHA=0 generates an initial drive tick while IDLE. CPHA=1 first
        // waits in CPHA_DELAY, so all initial ticks must be low.
        #1;
        if (mode_cpha == 1'b0) begin
            check(drive_tick,
                  $sformatf("%s: CPHA=0 must generate initial drive_tick",
                            mode_name));
            check(!sample_tick && !edge_tick,
                  $sformatf("%s: initial drive_tick must not be an SCLK edge",
                            mode_name));
        end else begin
            check(!drive_tick && !sample_tick && !edge_tick,
                  $sformatf("%s: CPHA=1 must delay initial ticks", mode_name));
        end

        // One data bit uses two SCLK edges. The tick counters below only
        // count ticks that are associated with an actual SCLK edge, so the
        // CPHA=0 startup drive_tick is intentionally excluded.
        while (edge_tick_count < 2 * SCLK_CYCLES) begin
            @(negedge clk);
            #1;

            if (edge_tick) begin
                edge_tick_count++;
                sclk_before_edge = qspi_sclk;
                edge_time = $time;

                check(drive_tick ^ sample_tick,
                      $sformatf("%s: each edge must have exactly one data tick",
                                mode_name));

                if (drive_tick)
                    drive_tick_count++;
                if (sample_tick)
                    sample_tick_count++;

                if (mode_cpha == 1'b0) begin
                    if ((edge_tick_count % 2) == 1)
                        check(sample_tick && !drive_tick,
                              $sformatf("%s: CPHA=0 odd edge must sample",
                                        mode_name));
                    else
                        check(drive_tick && !sample_tick,
                              $sformatf("%s: CPHA=0 even edge must drive",
                                        mode_name));
                end else begin
                    if ((edge_tick_count % 2) == 1)
                        check(drive_tick && !sample_tick,
                              $sformatf("%s: CPHA=1 odd edge must drive",
                                        mode_name));
                    else
                        check(sample_tick && !drive_tick,
                              $sformatf("%s: CPHA=1 even edge must sample",
                                        mode_name));
                end

                if (last_edge_time != 0)
                    check(edge_time - last_edge_time ==
                              int'(DIVIDER) * CLK_PERIOD_NS,
                          $sformatf("%s: edge spacing expected %0d ns, got %0d ns",
                                    mode_name,
                                    int'(DIVIDER) * CLK_PERIOD_NS,
                                    edge_time - last_edge_time));
                last_edge_time = edge_time;

                // edge_tick is evaluated before this posedge; qspi_sclk is
                // registered on this posedge and must change exactly once.
                @(posedge clk);
                #1;
                check(qspi_sclk == ~sclk_before_edge,
                      $sformatf("%s: qspi_sclk must toggle on every edge_tick",
                                mode_name));
            end
        end

        check(drive_tick_count == SCLK_CYCLES,
              $sformatf("%s: expected %0d drive_ticks, got %0d",
                        mode_name, SCLK_CYCLES, drive_tick_count));
        check(sample_tick_count == SCLK_CYCLES,
              $sformatf("%s: expected %0d sample_ticks, got %0d",
                        mode_name, SCLK_CYCLES, sample_tick_count));
        check(edge_tick_count == 2 * SCLK_CYCLES,
              $sformatf("%s: expected %0d edge_ticks, got %0d",
                        mode_name, 2 * SCLK_CYCLES, edge_tick_count));
        check(qspi_sclk == mode_cpol,
              $sformatf("%s: SCLK must return to CPOL after %0d cycles",
                        mode_name, SCLK_CYCLES));

        sclk_en = 1'b0;
        repeat (int'(DIVIDER) + 1) @(posedge clk);
        #1;
        check(sclk_idle,
              $sformatf("%s: generator must return to IDLE after disable",
                        mode_name));
        check(qspi_sclk == mode_cpol,
              $sformatf("%s: disabled SCLK must equal CPOL", mode_name));

        $display("%s: PASS; drive=%0d sample=%0d edge=%0d",
                 mode_name, drive_tick_count, sample_tick_count,
                 edge_tick_count);
    endtask

    initial begin
        failures = 0;

        apply_reset(1'b0);

        // Check that SCLK is not enabled when sclk_en=0 and eos = 0.
        repeat (2) begin
            @(posedge clk);
            #1;
            check(qspi_sclk == cpol, $sformatf("SCLK NOT ENABLED: expected qspi_sclk=%0b, got %0b", cpol, qspi_sclk));
            check(sclk_idle, "SCLK NOT ENABLED: expected sclk_idle=1");
        end

        @(negedge clk);
        eos = 1'b1;

        // Check that SCLK is not enabled when sclk_en=0 and eos = 1.
        repeat (2) begin
            @(posedge clk);
            #1;
            check(qspi_sclk == cpol, $sformatf("SCLK NOT ENABLED: expected qspi_sclk=%0b, got %0b", cpol, qspi_sclk));
            check(sclk_idle, "SCLK NOT ENABLED: expected sclk_idle=1");
        end

        @(negedge clk);
        sclk_en = 1'b1;
        eos     = 1'b0;

        // Check that SCLK is not enabled when sclk_en=1 and eos = 0.
        repeat (2) begin
            @(posedge clk);
            #1;
            check(qspi_sclk == cpol, $sformatf("SCLK NOT ENABLED: expected qspi_sclk=%0b, got %0b", cpol, qspi_sclk));
            check(sclk_idle, "SCLK NOT ENABLED: expected sclk_idle=1");
        end


        @(negedge clk);
        sclk_en = 1'b0;
        eos     = 1'b0;

        @(posedge clk);
        #1;

        run_mode(1'b0, 1'b0, "MODE 0");
        run_mode(1'b0, 1'b1, "MODE 1");
        run_mode(1'b1, 1'b0, "MODE 2");
        run_mode(1'b1, 1'b1, "MODE 3");

        if (failures == 0)
            $display("\ntb_qspi_sclk_gen: PASS - all four SPI modes verified");
        else
            $fatal(1, "\ntb_qspi_sclk_gen: %0d failure(s)", failures);

        $finish;
    end

endmodule
