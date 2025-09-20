`timescale 1ns / 1ps
// qspi_clkgen.v
// -----------------------------------------------------------------------------
// SCLK Generator with CPOL/CPHA and programmable clock divider
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module clkgen
#(
    parameter DIVIDER_WIDTH = `MAX_DIVIDER_WIDTH
)
(
    input  wire                      clk,
    input  wire                      reset,
    input  wire                      enable,      // Active during transfer
    input  wire                      cpol,
    input  wire                      cpha,
    input  wire [DIVIDER_WIDTH-1:0]  dvsr,        // Divider (must be ? 1)
    
    output reg                       sclk,
    output reg                       sample_edge,
    output reg                       drive_edge     // Toggles at SCLK active edges
);
    localparam [1:0] IDLE = 2'd0,
                     PHA_DELAY = 2'd1,
                     RUN = 2'd2;
                     
    reg [1:0] state_reg, state_next;
    reg [DIVIDER_WIDTH-1:0] count_reg, count_next;
    reg toggle;
    reg sclk_next;
    reg leading_edge;   // edge moving away from CPOL
    reg trailing_edge;  // edge moving toward CPOL
    
    always @(posedge clk or negedge reset) begin
      if (!reset) begin
         state_reg <= IDLE;
         count_reg <= 0;
         sclk        <= 0;               // will be forced to CPOL in IDLE path
         sample_edge <= 1'b0;
         drive_edge  <= 1'b0;
      end else begin
         state_reg <= state_next;
         count_reg <= count_next;
         sclk <= sclk_next;
         sample_edge <= (state_reg==RUN) && toggle && enable && (cpha ? trailing_edge : leading_edge);

         drive_edge  <= (state_reg==RUN) && toggle && enable && (cpha ? leading_edge  : trailing_edge);
      end
    end

    
    always @(*) begin
    state_next = state_reg;
    count_next = count_reg;
    sclk_next    = sclk;
    leading_edge = 1'b0;
    trailing_edge= 1'b0;

    toggle = 0;
    
        if (state_reg != IDLE) begin
           if (count_reg == dvsr) begin
              toggle = 1;
              count_next = 0;
           end else begin
              count_next = count_reg + 1;
           end
        end else begin
           count_next = 0;
        end
              
        case (state_reg) 
           IDLE: begin
               // Hold SCLK at CPOL while idle
               sclk_next = cpol;
               if (enable) begin
                   count_next = {DIVIDER_WIDTH{1'b0}};
                   state_next = (cpha ? PHA_DELAY : RUN);
               end
           end
           
           PHA_DELAY: begin
               // Wait exactly one divider interval, do NOT toggle SCLK here.
               // This provides the CPHA=1 initial half-period before the first active edge.
               if (toggle) begin
                   // consume the delay interval, then go RUN and restart counting
                   state_next = RUN;
               end
               // sclk holds at CPOL during the delay
               sclk_next = cpol;
           end
           
           RUN: begin
               // Generate toggles on divider hit
               if (toggle) begin
                   // Edge classification is based on the PRE-TOGGLE level:
                   // if current sclk == CPOL, next transition is LEADING (away from idle)
                   // else it's TRAILING (back toward idle)
                   leading_edge  = (sclk == cpol);
                   trailing_edge = ~leading_edge;
    
                   // Perform the actual toggle
                   sclk_next = ~sclk;
               end
    
               // Exit back to idle
               if (!enable) begin
                   state_next = IDLE;
                   sclk_next  = cpol;
               end
           end
           
           default: begin
                   state_next = IDLE;
                   sclk_next  = cpol;
           end
        endcase
    end

endmodule


