`timescale 1ns / 1ps

module spi_testbench;

  parameter NBITS = 8;
  parameter NSLAVE = 4;
  parameter CLK_PER = 10;
  parameter DVSR = 4;

  logic clk = 0;
  logic reset;
  logic start;
  logic [NBITS-1:0] tx_data;
  logic [15:0] dvsr;
  logic cpol, cpha, lsb_first;
  logic [$clog2(NSLAVE)-1:0] cs_num;

  logic [NBITS-1:0] rx_data;
  logic ready;
  logic spi_done_tick;
  logic sclk;
  logic mosi;
  logic [NSLAVE-1:0] cs_decode;

  logic [NSLAVE-1:0] miso_reg;
  logic miso;
  assign miso = (cs_decode[0] == 1'b0) ? miso_reg[0] :
              (cs_decode[1] == 1'b0) ? miso_reg[1] :
              (cs_decode[2] == 1'b0) ? miso_reg[2] :
              (cs_decode[3] == 1'b0) ? miso_reg[3] : 1'bz;

  top_spi_master #(.NBITS(NBITS), .NSLAVE(NSLAVE)) dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .tx_data(tx_data),
    .rx_data(rx_data),
    .dvsr(dvsr),
    .ready(ready),
    .spi_done_tick(spi_done_tick),
    .sclk(sclk),
    .mosi(mosi),
    .miso(miso),
    .cpol(cpol),
    .cpha(cpha),
    .cs_decode(cs_decode),
    .lsb_first(lsb_first),
    .cs_num(cs_num)
  );

  always #(CLK_PER/2) clk = ~clk;

  logic [NBITS-1:0] slave_data_reg [NSLAVE-1:0];

  genvar i;
  generate
    for (i = 0; i < NSLAVE; i++) begin : slave_logic_pos
      always_ff @(posedge sclk or posedge reset) begin
        if (reset) begin
          slave_data_reg[i] <= 8'h00;
          miso_reg[i] <= 1'b0;
        end else if (cs_decode[i] == 1'b0) begin
          if (!cpha & !cpol | cpha & cpol)
            slave_data_reg[i] <= lsb_first ? {mosi, slave_data_reg[i][NBITS-1:1]} : {slave_data_reg[i][NBITS-2:0], mosi};
          else
            miso_reg[i] <= lsb_first ? slave_data_reg[i][0] : slave_data_reg[i][NBITS-1];
        end
      end
    end
  endgenerate

  generate
    for (i = 0; i < NSLAVE; i++) begin : slave_logic_neg
      always_ff @(negedge sclk or posedge reset) begin
        if (reset) begin
          slave_data_reg[i] <= 8'h00;
          miso_reg[i] <= 1'b0;
        end else if (cs_decode[i] == 1'b0) begin
          if (cpha & !cpol | !cpha & cpol)
            slave_data_reg[i] <= lsb_first ? {mosi, slave_data_reg[i][NBITS-1:1]} : {slave_data_reg[i][NBITS-2:0], mosi};
          else
            miso_reg[i] <= lsb_first ? slave_data_reg[i][0] : slave_data_reg[i][NBITS-1];
        end
      end
    end
  endgenerate


  task run_tx(input [NBITS-1:0] master_tx_data, input [NBITS-1:0] slave_tx_data, input bit mode_cpol, input bit mode_cpha, input bit mode_lsb, input int slave_num);
    begin
      wait(ready);
      cpol = mode_cpol;
      cpha = mode_cpha;
      lsb_first = mode_lsb;
      cs_num = slave_num;
      dvsr = DVSR;
      tx_data = master_tx_data;
      slave_data_reg[slave_num] = slave_tx_data;
      miso_reg[slave_num] = mode_lsb ? slave_tx_data[0] : slave_tx_data[NBITS-1]; 
      @(posedge clk);
      start <= 1'b1;
      @(posedge clk);
      start <= 1'b0;
      wait(spi_done_tick);
    end
  endtask

  initial begin
    reset = 1;
    start = 0;
    repeat(2) @(posedge clk);
    reset = 0;

    run_tx(8'hA5, 8'h7B, 0, 0, 0, 0); // Mode 0 MSB-first
    #500
    run_tx(8'h3C, 8'hE9, 0, 1, 0, 1); // Mode 1 MSB-first
    #500
    run_tx(8'hF9, 8'hDB, 1, 0, 0, 2); // Mode 2 MSB-first
    #500
    run_tx(8'h21, 8'h48, 1, 1, 0, 3); // Mode 3 MSB-first
    #500
    
    run_tx(8'hA5, 8'h7B, 0, 0, 1, 0); // Mode 0 LSB-first
    #500
    run_tx(8'h3C, 8'hE9, 0, 1, 1, 1); // Mode 1 LSB-first
    #500
    run_tx(8'hF9, 8'hDB, 1, 0, 1, 2); // Mode 2 LSB-first
    #500
    run_tx(8'h21, 8'h48, 1, 1, 1, 3); // Mode 3 LSB-first
    

    $finish;
  end

endmodule
