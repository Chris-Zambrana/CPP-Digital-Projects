`timescale 1ns / 1ps

// Self-checking testbench for qspi_csr_map.
// Exercises reset, CSR writes, decoded controller outputs, start qualification,
// status/RX reads, and FIFO request protection.
module tb_qspi_csr_map;

    localparam int CSR_DEPTH         = 32;
    localparam int CSR_WIDTH         = 32;
    localparam int DIVIDER_WIDTH     = 16;
    localparam int MAX_ADDR_WIDTH    = 32;
    localparam int DATA_LEN_WIDTH    = 16;
    localparam int DUMMY_WIDTH       = 8;
    localparam int MODE_WIDTH        = 8;
    localparam int DATA_WIDTH        = 8;
    localparam int SLAVE_COUNT       = 3;

    localparam logic [$clog2(CSR_DEPTH)-1:0]
        PULSE_REG    = 0,
        CONTROL_REG  = 1,
        STATUS_REG   = 2,
        DIVIDER_REG  = 3,
        CMD_CONF_REG = 4,
        CMD_DATA_REG = 5,
        FADDR_REG    = 6,
        TX_LEN_REG   = 7,
        RX_LEN_REG   = 8,
        TX_DATA_REG  = 9,
        RX_DATA_REG  = 10,
        CS_REG       = 11;

    logic clk, reset;
    logic cs, read, write;
    logic [4:0] addr;
    logic [31:0] wr_data, rd_data;
    logic ready, fifo_tx_full, fifo_rx_empty;
    logic [DATA_WIDTH-1:0] fifo_rx_rbyte;

    logic start, cpol, cpha, lsb_first, ddr_en;
    logic [DIVIDER_WIDTH-1:0] clk_div;
    logic has_opcode, has_addr, has_mode, has_dummy, has_tx_data, has_rx_data;
    logic [2:0] cmd_io_width, addr_io_width, mode_io_width, data_io_width;
    logic [1:0] addr_bit_width;
    logic [7:0] opcode;
    logic [MODE_WIDTH-1:0] mode_bits;
    logic [DUMMY_WIDTH-1:0] dummy_cycles;
    logic [MAX_ADDR_WIDTH-1:0] flash_addr;
    logic [DATA_LEN_WIDTH-1:0] tx_len, rx_len;
    logic [$clog2(SLAVE_COUNT)-1:0] cs_num;
    logic fifo_tx_wr;
    logic [DATA_WIDTH-1:0] fifo_tx_wbyte;
    logic fifo_rx_rd;
    int failures;

    qspi_csr_map #(
        .QSPI_CSR_DEPTH(CSR_DEPTH),
        .QSPI_CSR_WIDTH(CSR_WIDTH),
        .QSPI_DIVIDER_WIDTH(DIVIDER_WIDTH),
        .QSPI_MAX_ADDR_WIDTH(MAX_ADDR_WIDTH),
        .QSPI_DATA_LEN_WIDTH(DATA_LEN_WIDTH),
        .QSPI_DUMMY_COUNT_WIDTH(DUMMY_WIDTH),
        .QSPI_MODE_WIDTH(MODE_WIDTH),
        .QSPI_DATA_WIDTH(DATA_WIDTH),
        .QSPI_SLAVE_COUNT(SLAVE_COUNT)
    ) dut (.*);

    initial clk = 1'b0;
    always #5 clk = ~clk;

    /*
    initial begin
        $dumpfile("tb_qspi_csr_map.vcd");
        $dumpvars(0, tb_qspi_csr_map);
    end
    */

    task automatic check(input logic condition, input string message);
        if (!condition) begin
            failures++;
            $error("%s", message);
        end
    endtask

    task automatic csr_write(input logic [4:0] write_addr,
                             input logic [31:0] data);
        begin
            @(negedge clk);
            cs = 1'b1; write = 1'b1; read = 1'b0;
            addr = write_addr; wr_data = data;
            @(posedge clk);
            #1;
            cs = 1'b0; write = 1'b0; addr = '0; wr_data = '0;
        end
    endtask

    task automatic csr_read(input logic [4:0] read_addr,
                            input logic [31:0] expected,
                            input string message);
        begin
            @(negedge clk);
            cs = 1'b1; write = 1'b0; read = 1'b1; addr = read_addr;
            #1;
            check(rd_data === expected,
                  $sformatf("%s: expected %08h, got %08h", message, expected, rd_data));
            @(posedge clk);
            #1;
            cs = 1'b0; read = 1'b0; addr = '0;
        end
    endtask

    initial begin
        failures = 0;
        cs = 0; read = 0; write = 0; addr = '0; wr_data = '0;
        ready = 0; fifo_tx_full = 0; fifo_rx_empty = 1; fifo_rx_rbyte = '0;
        reset = 1;
        #1;

        check(!start && !fifo_tx_wr && !fifo_rx_rd, "Reset: request outputs must be inactive");
        check({cpol, cpha, lsb_first, ddr_en, clk_div, opcode, flash_addr,
               tx_len, rx_len, cs_num} === '0,
              "Reset: programmable outputs must be zero");

        @(negedge clk);
        reset = 0;
        @(posedge clk);
        #1;

        csr_write(CONTROL_REG, 32'b1111);
        check({ddr_en, lsb_first, cpha, cpol} === 4'b1111,
              "CONTROL_REG: mode bits did not decode");

        csr_write(DIVIDER_REG, 32'h0000_a55a);
        check(clk_div === 16'ha55a, "DIVIDER_REG: divider did not decode");

        csr_write(CMD_CONF_REG, 32'h000a_bfff);
        check(has_opcode && has_addr && has_mode && has_dummy && has_tx_data && has_rx_data,
              "CMD_CONF_REG: feature enables did not decode");
        check(cmd_io_width === 3'b111 && addr_io_width === 3'b111 &&
              mode_io_width === 3'b011 && data_io_width === 3'b101 &&
              addr_bit_width === 2'b10,
              "CMD_CONF_REG: IO widths did not decode");

        csr_write(CMD_DATA_REG, 32'h0003_5aa5);
        check(opcode === 8'ha5 && mode_bits === 8'h5a && dummy_cycles === 8'h03,
              "CMD_DATA_REG: command fields did not decode");
        csr_write(FADDR_REG, 32'hdead_beef);
        csr_write(TX_LEN_REG, 32'h0000_1234);
        csr_write(RX_LEN_REG, 32'h0000_5678);
        csr_write(CS_REG, 32'h0000_0002);
        check(flash_addr === 32'hdead_beef && tx_len === 16'h1234 &&
              rx_len === 16'h5678 && cs_num === 2,
              "Address/length/CS registers did not decode");

        // PULSE_REG is a qualified one-cycle combinational start request.
        ready = 1'b0;
        @(negedge clk); cs = 1; write = 1; addr = PULSE_REG; wr_data = 1;
        #1; check(!start, "PULSE_REG: start must wait for ready");
        ready = 1'b1;
        #1; check(start, "PULSE_REG: start must assert when ready is high");
        @(posedge clk); #1;
        cs = 0; write = 0; addr = '0; wr_data = '0;
        #1; check(!start, "PULSE_REG: start must deassert after the request");

        fifo_tx_full = 1'b0;
        @(negedge clk); cs = 1; write = 1; addr = TX_DATA_REG; wr_data = 32'h000000c3;
        #1; check(fifo_tx_wr && fifo_tx_wbyte === 8'hc3,
                 "TX_DATA_REG: FIFO write request/data incorrect");
        fifo_tx_full = 1'b1;
        #1; check(!fifo_tx_wr, "TX_DATA_REG: write must be blocked when FIFO is full");
        @(posedge clk); #1; cs = 0; write = 0; fifo_tx_full = 0;

        fifo_rx_empty = 1'b0; fifo_rx_rbyte = 8'h5a;
        @(negedge clk); cs = 1'b1; read = 1'b1; addr = RX_DATA_REG;
        #1;
        check(fifo_rx_rd && rd_data === 32'h0000_005a,
              "RX_DATA_REG: FIFO read request/data incorrect");
        @(posedge clk); #1; cs = 0; read = 0; addr = '0;
        fifo_rx_empty = 1'b1;
        @(negedge clk); cs = 1; read = 1; addr = RX_DATA_REG; #1;
        check(!fifo_rx_rd && rd_data === 0,
              "RX_DATA_REG: read must be blocked when FIFO is empty");
        @(posedge clk); #1; cs = 0; read = 0; addr = '0;

        ready = 1'b1; fifo_tx_full = 1'b1; fifo_rx_empty = 1'b0;
        csr_read(STATUS_REG, 32'h0000_0003, "STATUS_REG");
        ready = 1'b0; fifo_tx_full = 1'b0; fifo_rx_empty = 1'b1;
        csr_read(STATUS_REG, 32'h0000_0004, "STATUS_REG (empty/not ready)");

        if (failures == 0)
            $display("tb_qspi_csr_map: PASS - all CSR map checks completed");
        else
            $fatal(1, "tb_qspi_csr_map: %0d failure(s)", failures);
        $finish;
    end

endmodule
