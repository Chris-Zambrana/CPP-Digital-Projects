`timescale 1ns / 1ps

// Module: spi_controller
// -----------------------------------------------------------------------
// Description:
//   Core SPI master controller that supports full-duplex communication with
//   configurable SPI modes (0-3), LSB-first/MSB-first shifting, and clock
//   frequency control via divider. Built as a finite state machine that
//   controls bit-level serial exchange.
//
// Parameters:
//   NBITS - Number of bits per SPI transaction 
// -----------------------------------------------------------------------

module spi_controller
  #(parameter NBITS = 8)
  (
   input  clk,                      // System clock
   input  reset,                    // Synchronous reset (active low)
   input  lsb_first,                // 0 = MSB is sent first (tx_data is shifted left), 1 = LSB is sent first (tx_data is shifted right)
   input  cpol,                     // Clock polarity
   input  cpha,                     // Clock phase
   input  start,                    // Trigger for beginning a transfer
   input  miso,                     // Master-In Slave-Out 
   input  [NBITS-1:0] tx_data,      // Data to transmit (parallel input)
   input  [15:0] dvsr,              // Clock divider for generating SCLK

   output wire ready,              // Indicates controller is idle and ready
   output wire spi_done_tick,      // Pulse indicating end of transaction
   output wire sclk,               // SPI clock output
   output wire mosi,               // Master-Out Slave-In
   output wire cs,                 // Active-low chip select
   output wire [NBITS-1:0] rx_data // Received data (parallel output)
  );

   // FSM states
   localparam[2:0] IDLE     = 0,
                   CPHA_DLY = 1,   // Used only for CPHA=1 (delay before first edge)
                   EDGE_1   = 2,   // First edge of SPI clock
                   EDGE_2   = 3;   // Second edge of SPI clock

   // FSM and data-path registers
   reg [1:0] state_reg, state_next;            // State Registers
   reg [15:0] cnt_reg, cnt_next;               // Clock divider counter
   reg clk_phase_reg, clk_phase_next;          // Internal SPI clock phase
   reg spi_done_tick_i, ready_i;               // Internal done and ready line
   reg cs_i;                                   // Internal CS line
   reg toggle;                                 // Divider tick flag
   reg [NBITS-1:0] so_reg, so_next;            // Shift-out register (transmit)
   reg [NBITS-1:0] si_reg, si_next;            // Shift-in register (receive)
   reg [$clog2(NBITS):0] bit_reg, bit_next;    // Bit index counter

   // Edge detector for start signal 
   // -----------------------------------------------------------------------
   // Ensures the start signal is clean and secure so that it doesn't get set more than one clock cycle
   // start_d saves the previous cycles value of start
   // if start = 1 and previous cycle start = 0, start_pulse = 1 then the communication starts
   // -----------------------------------------------------------------------
   reg start_d;
   always @(posedge clk or negedge reset) begin
      if (!reset)
         start_d <= 1'b0;
      else
         start_d <= start;
   end
   wire start_pulse = start & ~start_d;

   // Sequential block for register
   // -----------------------------------------------------------------------
   // Takes into account of resets and sets the next state/data from the previous cycle into the current cycles registers
   // Ex: cycle 1 (previous cycle) - state_reg = IDLE, state_next = EDGE_1
   //     cycle 2 (current cycle that calls this block) - state_reg = EDGE_1, state_next = EDGE_2
   // -----------------------------------------------------------------------
   always @(posedge clk or negedge reset) begin
      if (!reset) begin
         state_reg <= IDLE;
         cnt_reg <= 0;
         clk_phase_reg <= 0;
         so_reg <= 0;
         si_reg <= 0;
         bit_reg <= 0;
      end else begin
         state_reg <= state_next;
         cnt_reg <= cnt_next;
         clk_phase_reg <= clk_phase_next;
         so_reg <= so_next;
         si_reg <= si_next;
         bit_reg <= bit_next;
      end
   end

   // FSM and datapath next-state logic

   always @(*) begin
      // Default next values 
      state_next = state_reg;
      cnt_next = cnt_reg;
      clk_phase_next = clk_phase_reg;
      so_next = so_reg;
      si_next = si_reg;
      bit_next = bit_reg;
      ready_i = 1'b0;
      spi_done_tick_i = 1'b0;
      cs_i = 1'b1;
      toggle = 1'b0;
      
      // Clock divider toggle logic
      // ---------------------------------------------------------------------------------------------------------------------------------------------------------------
      // generates a slower toggling signal based on a counter
      // divides the input clock (clk) to derive a lower-frequency clock used to control the timing of SPI signal transitions
      // think of dvsr as the number of system clock (clk) cycles it takes to generate HALF a SPI clk (sclk) cycle
      // Operations will occur on + and - edges, which is why we need to generate HALF sck cycles 
      //
      // Ex: clk = 0, dvsr = 4
      //     when counter(cnt) reaches 4, it will set toggle which allows the rest of the system to do the operation (sample/drive) of the upcoming edge
      // ---------------------------------------------------------------------------------------------------------------------------------------------------------------
      if (state_reg != IDLE) begin
         if (cnt_reg == dvsr) begin
            toggle = 1'b1;
            cnt_next = 16'd0;
         end else begin
            cnt_next = cnt_reg + 16'd1;
         end
      end else begin
         cnt_next = 16'd0;
      end

      // FSM behavior

      case (state_reg)
         IDLE: begin
            ready_i = 1'b1;           // Signal ready to upper logic
            clk_phase_next = 1'b0;    
            if (start_pulse) begin
               cs_i = 1'b0;           // chip select enabled
               so_next = tx_data;     // Load data to shift out
               si_next = 0;           // reset the register that will recieve data from the slave
               bit_next = 0;          // beginning of operation, so number of bits transferred = 0
               state_next = cpha ? CPHA_DLY : EDGE_1;   // cpha needs a delay before first edge, so if CPHA go do the delay else go to first edge
            end
         end
         
         CPHA_DLY: begin
            cs_i = 1'b0;
            if (toggle) begin
               clk_phase_next = ~clk_phase_reg;
               state_next = EDGE_2; // go to edge 2 because the next edge will be sampling, so # of bits transferred needs to be updated
            end
         end

         EDGE_1: begin
            cs_i = 1'b0;
            if (toggle) begin
               // Sample data on first edge if CPHA=0
               if (!cpha) begin
                  si_next = lsb_first ?
                      {miso, si_reg[NBITS-1:1]} : {si_reg[NBITS-2:0], miso};
               end else begin
                  // Otherwise, drive the next MOSI bit from tx_data
                  so_next = lsb_first ?
                      {1'b0, so_reg[NBITS-1:1]} : {so_reg[NBITS-2:0], 1'b0};
               end
               clk_phase_next = ~clk_phase_reg;
               state_next = EDGE_2;
            end
         end

         EDGE_2: begin
            cs_i = 1'b0;
            if (toggle) begin
               // Sample data if CPHA = 1 
               if (cpha) begin
                  si_next = lsb_first ?
                      {miso, si_reg[NBITS-1:1]} : {si_reg[NBITS-2:0], miso};
               end else begin
                  // Otherwise, drive the next MOSI bit from tx_data
                  so_next = lsb_first ?
                      {1'b0, so_reg[NBITS-1:1]} : {so_reg[NBITS-2:0], 1'b0};
               end
               
               // if all the bits have been transferred, send done tick
               if (bit_reg == NBITS-1) begin
                  spi_done_tick_i = 1'b1;
                  state_next = IDLE;
               end else begin
                  // Otherwise, increment the bit counter and continue to the next operation
                  bit_next = bit_reg + 1;
                  state_next = EDGE_1;
               end
               clk_phase_next = ~clk_phase_reg;
            end
         end

         default: state_next = IDLE;
      endcase
   end

   // Output assignments
   assign sclk = (cpol) ? ~clk_phase_reg : clk_phase_reg; // cpol being set means the sclk is inverted
   assign mosi = lsb_first ? so_reg[0] : so_reg[NBITS-1]; 
   assign cs = cs_i & (state_reg == IDLE);  // CS goes inactive during IDLE
   assign ready = ready_i;
   assign rx_data = si_reg;
   assign spi_done_tick = spi_done_tick_i;

endmodule
