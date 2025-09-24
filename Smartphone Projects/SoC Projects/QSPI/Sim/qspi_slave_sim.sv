`timescale 1ns/1ps
`include "qspi_definitions.vh"

module qspi_slave_sim #(
  parameter integer IO_WIDTH     = `IO_WIDTH_DEFAULT,   // DQ0..DQ(IO_WIDTH-1)
  parameter integer ADDR_BITS    = `BITS_ADDR,          // address width
  parameter integer MEM_BYTES    = `MAX_MEMORY_BYTES,   // internal memory size (bytes)
  parameter integer CPOL         = `CPOL_0,             // clock polarity
  parameter integer CPHA         = `CPHA_0,             // clock phase
  parameter integer LSB_FIRST    = 0,                   // 0=MSB-first, 1=LSB-first
  parameter        MEM_INIT_HEX  = ""                   // optional mem preload
)(
  input  logic                   reset,     // async active-low reset
  input  logic                   cs,        // chip select, active low
  input  logic                   sclk,      // serial clock from master
  inout  wire  [IO_WIDTH-1:0]    io,        // bidirectional data lines
  input  logic [1:0]             phase_mode // 0->x1, 1->x2, 2/3->x4 (DATA phase only)
);

  // Opcodes (JEDEC-like)
  localparam logic [7:0] OPC_READ  = 8'h03;
  localparam logic [7:0] OPC_WRITE = 8'h02;

  // Internal memory
  byte unsigned mem [0:MEM_BYTES-1];
  initial if (MEM_INIT_HEX != "") $readmemh(MEM_INIT_HEX, mem);

  // IO bus: output data and OE
  logic [IO_WIDTH-1:0] io_out;
  logic [IO_WIDTH-1:0] io_oe;
  wire  [IO_WIDTH-1:0] s_io_in = io;

  genvar i;
  generate
    for (i = 0; i < IO_WIDTH; i++) begin : gen_tristate
      assign io[i] = io_oe[i] ? io_out[i] : 1'bz;
    end
  endgenerate

  // Convert phase_mode (0/1/2/3) -> active lanes (1/2/4), clamp to IO_WIDTH
  function automatic int unsigned lane_enable (input logic [1:0] r_phase_mode);
    int unsigned active_lanes;
    begin
      case (r_phase_mode)
        0: active_lanes = 0;
        1: active_lanes = 1;
        2: active_lanes = 2;
        3: active_lanes = 4;
        default: active_lanes = 0;
      endcase
      return (active_lanes > IO_WIDTH) ? IO_WIDTH : active_lanes;
    end
  endfunction

  // State machine
  typedef enum logic [2:0] {
    IDLE      = 3'd0,
    RX_OPCODE = 3'd1,
    RX_ADDR   = 3'd2,
    RD_DATA   = 3'd3,
    WR_DATA   = 3'd4
  } state_type;

  state_type               state;

  // Shift/counters for opcode + address
  logic [7:0]              instr_shift;
  logic [3:0]              instr_length;   // 0..8
  logic [ADDR_BITS-1:0]    addr_shift;
  int unsigned             addr_cnt;       // 0..ADDR_BITS

  // Data phase (byte oriented)
  byte unsigned            tx_byte;        // READ path
  byte unsigned            rx_byte;        // WRITE path
  int unsigned             tx_bit_idx;     // 0..7, step by L
  int unsigned             rx_bit_idx;     // 0..7, step by L
  logic [ADDR_BITS-1:0]    cur_addr;

  // Reset / CS# control (multi-edge sensitivity)
  always @(negedge reset or posedge cs or negedge cs) begin
    if (!reset) begin
      state       <= IDLE;
      io_oe       <= '0;
      io_out      <= '0;
      instr_shift <= '0;
      instr_length<= '0;
      addr_shift  <= '0;
      addr_cnt    <= 0;
      tx_byte     <= '0;
      rx_byte     <= '0;
      tx_bit_idx  <= 0;
      rx_bit_idx  <= 0;
      cur_addr    <= '0;
    end else if (!cs) begin
      // CS# asserted (frame start)
      state        <= RX_OPCODE;
      io_oe        <= '0;         // never drive during opcode/address
      instr_shift  <= '0;
      instr_length <= '0;
      addr_shift   <= '0;
      addr_cnt     <= 0;
      tx_bit_idx   <= 0;
      rx_bit_idx   <= 0;
    end else begin
      // CS# deasserted (frame end)
      state       <= IDLE;
      io_oe       <= '0;
      tx_bit_idx  <= 0;
      rx_bit_idx  <= 0;
    end
  end

    // Edge policy
  logic sample_on_leading = (CPHA == 1'b0);
  
  // SAMPLE task
  task automatic sample (input bit leading_edge);
    int k, lanes, bitpos;
    logic [IO_WIDTH-1:0] pin_sample;
    begin
      if (!cs) begin
        if ( (sample_on_leading && leading_edge) ||
             (!sample_on_leading && !leading_edge) ) begin
          unique case (state)
            RX_OPCODE: begin
              // Opcode on IO0, 1-bit wide
              if (LSB_FIRST)
                instr_shift[instr_length] <= s_io_in[0];
              else
                instr_shift[7 - instr_length] <= s_io_in[0];
              instr_length <= instr_length + 1;
              if (instr_length == 4'd7) begin
                state        <= RX_ADDR;
                instr_length <= '0;
              end
            end

            RX_ADDR: begin
              // Address on IO0, 1-bit wide
              if (LSB_FIRST)
                addr_shift[addr_cnt] <= s_io_in[0];
              else
                addr_shift[ADDR_BITS-1 - addr_cnt] <= s_io_in[0];
              addr_cnt <= addr_cnt + 1;
              if (addr_cnt == (ADDR_BITS-1)) begin
                cur_addr <= addr_shift;
                if (instr_shift == OPC_READ) begin
                  state      <= RD_DATA;
                  tx_byte    <= mem[addr_shift % MEM_BYTES]; // prefetch with fresh address
                  tx_bit_idx <= 0;
                  io_oe      <= '0; // enable on DRIVE edge only
                end else if (instr_shift == OPC_WRITE) begin
                  state      <= WR_DATA;
                  rx_byte    <= '0;
                  rx_bit_idx <= 0;
                  io_oe      <= '0; // writes never drive
                end else begin
                  state      <= IDLE; // unsupported opcode: stay quiet
                  io_oe      <= '0;
                end
              end
            end

            WR_DATA: begin
              // Receive L bits on IO[L-1:0]
              lanes = lane_enable(phase_mode);
              pin_sample = s_io_in;
              for (k = 0; k < lanes; k++) begin
                bitpos = LSB_FIRST ? (rx_bit_idx + k) : (7 - (rx_bit_idx + k));
                if ((bitpos >= 0) && (bitpos < 8))
                  rx_byte[bitpos] = pin_sample[k];
              end
              rx_bit_idx = rx_bit_idx + lanes;
              if (rx_bit_idx >= 8) begin
                mem[cur_addr % MEM_BYTES] <= rx_byte;
                cur_addr                  <= cur_addr + 1;
                rx_bit_idx                <= 0;
                rx_byte                   <= '0;
              end
            end

            default: ; // IDLE/RD_DATA: no sampling work
          endcase
        end
      end
    end
  endtask

  // DRIVE task
  task automatic drive (input bit leading_edge);
    int k, lanes, bitpos;
    logic [IO_WIDTH-1:0] r_io_out;
    logic [IO_WIDTH-1:0] lane_mask;
    begin
      if (!cs) begin
        if ( (sample_on_leading && !leading_edge) ||
             (!sample_on_leading &&  leading_edge) ) begin
          unique case (state)
            RD_DATA: begin
              lanes = lane_enable(phase_mode);
              r_io_out = '0;

              // Map L bits from tx_byte to IO[L-1:0]
              for (k = 0; k < lanes; k++) begin
                bitpos = LSB_FIRST ? (tx_bit_idx + k) : (7 - (tx_bit_idx + k));
                if ((bitpos >= 0) && (bitpos < 8))
                  r_io_out[k] = tx_byte[bitpos];
              end

              io_out <= r_io_out;

              // Enable only the active lanes
              lane_mask = (lanes >= IO_WIDTH) ? {IO_WIDTH{1'b1}} :
                          logic'((1 << lanes) - 1);
              io_oe <= lane_mask;

              tx_bit_idx = tx_bit_idx + lanes;
              if (tx_bit_idx >= 8) begin
                cur_addr   <= cur_addr + 1;
                tx_byte    <= mem[cur_addr % MEM_BYTES];
                tx_bit_idx <= 0;
              end
            end

            default: begin
              io_oe <= '0; // never drive outside READ data phase
            end
          endcase
        end
      end else begin
        io_oe <= '0; // CS# high: tri-state
      end
    end
  endtask

  // Edge dispatchers
  always_ff @(posedge sclk) begin
    sample( (CPOL == 1'b0) ? 1'b1 : 1'b0 ); // posedge is leading if CPOL=0
    drive ( (CPOL == 1'b0) ? 1'b1 : 1'b0 );
  end

  always_ff @(negedge sclk) begin
    sample( (CPOL == 1'b1) ? 1'b1 : 1'b0 ); // negedge is leading if CPOL=1
    drive ( (CPOL == 1'b1) ? 1'b1 : 1'b0 );
  end

endmodule
