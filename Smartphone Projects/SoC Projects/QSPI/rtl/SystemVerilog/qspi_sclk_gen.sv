`timescale 1ns / 1ps
// qspi_clkgen.v
// -----------------------------------------------------------------------------
// SCLK Generator with CPOL/CPHA and programmable clock divider
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_sclk_gen
#(
    parameter DIVIDER_BITS = `DIVIDER_BITS
)
(
    input  logic clk,
    input  logic reset,

    // register to SCK generator signals
    input  logic soft_reset,
    input  logic [DIVIDER_BITS-1:0] clk_div,
    input  logic cpol,
    input  logic cpha,

    // controller to SCK generator signals
    input  logic sclk_en,

    // SCK generator to shift register / flash clock path signals
    output logic qspi_sclk,
    output logic drive_tick,
    output logic sample_tick,
    output logic sclk_idle
);

typedef enum {
    IDLE,
    CPHA_DELAY,
    DRIVE,
    SAMPLE
} state_type;

state_type state_reg, state_next;
logic sclk_reg, sclk_next;
logic p_clk;
logic drive_tick_flag, sample_tick_flag;
logic [DIVIDER_BITS-1:0] cnt_reg, cnt_next;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        sclk_reg <= 0; // idle state of SCLK based on CPOL
        cnt_reg <= 0;
        state_reg <= IDLE;
    end else if (soft_reset) begin
        sclk_reg <= cpol;
        cnt_reg <= 0;
        state_reg <= IDLE;
    end else begin
        sclk_reg <= sclk_next;
        cnt_reg <= cnt_next;
        state_reg <= state_next;
    end 
end

always_comb begin
    drive_tick_flag = 0;
    sample_tick_flag = 0;
    state_next = state_reg;
    cnt_next = cnt_reg;
    
    case(state_reg)
        IDLE: begin
            if(sclk_en) begin 
                if (cpha) begin
                    state_next = CPHA_DELAY; // start the sequence on enable
                    cnt_next = 0; // reset counter for next phase
                end else begin
                    state_next = DRIVE;
                    drive_tick_flag = 1; // generate a drive tick on the first edge
                    cnt_next = 0; // reset counter for next phase
                end
            end else begin
                state_next = IDLE;
                cnt_next = 0; // load the counter with the divider value
            end
        end

        CPHA_DELAY: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = DRIVE;
                    drive_tick_flag = 1; // generate a drive tick on the first edge
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = CPHA_DELAY;
            end
        end

        DRIVE: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = SAMPLE;
                    sample_tick_flag = 1; // generate a sample tick at the end of the SAMPLE phase
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = DRIVE;
            end
        end

        SAMPLE: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = DRIVE;
                    drive_tick_flag = 1; // generate a drive tick at the end of the DRIVE phase
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = SAMPLE;
            end
        end

        default: begin
            state_next = IDLE;
            drive_tick_flag = 0;
            sample_tick_flag = 0;
            cnt_next = 0;
        end
    endcase
    
end

assign p_clk = (state_next==SAMPLE && ~cpha) || (state_next==DRIVE && cpha);
assign sclk_next = (cpol) ? ~p_clk : p_clk;

assign qspi_sclk = sclk_reg;
assign drive_tick = drive_tick_flag;
assign sample_tick = sample_tick_flag;
assign sclk_idle = (state_reg == IDLE);

endmodule


