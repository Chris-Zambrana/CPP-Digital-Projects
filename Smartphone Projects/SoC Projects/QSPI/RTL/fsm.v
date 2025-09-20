`timescale 1ns / 1ps

`include "qspi_definitions.vh"

module fsm (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire        done_tick,      // Signals end of shift for a phase
    output reg  [2:0]  current_phase,
    output reg         busy,
    output reg         done
);

    // FSM States
    localparam [2:0] IDLE   = `PHASE_IDLE;
    localparam [2:0] INSTR  = `PHASE_INSTR;
    localparam [2:0] ADDR   = `PHASE_ADDRESS;
    localparam [2:0] ALT    = `PHASE_ALT;     // <-- NEW: Alternate/Mode Phase
    localparam [2:0] DUMMY  = `PHASE_DUMMY;
    localparam [2:0] DATA   = `PHASE_DATA;
    localparam [2:0] DONE   = 3'd6;

    reg [2:0] state, next_state;

    // State transition logic
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:   if (start)         next_state = INSTR;
            INSTR:  if (done_tick)     next_state = ADDR;
            ADDR:   if (done_tick)     next_state = ALT;     // <-- NEW TRANSITION
            ALT:    if (done_tick)     next_state = DUMMY;
            DUMMY:  if (done_tick)     next_state = DATA;
            DATA:   if (done_tick)     next_state = DONE;
            DONE:                      next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_phase <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            current_phase <= state;
            busy <= (state != IDLE && state != DONE);
            done <= (state == DONE);
        end
    end

endmodule
