`timescale 1ns / 1ps
// qspi_clkgen.v
// -----------------------------------------------------------------------------
// SCLK Generator with CPOL/CPHA and programmable clock divider
// -----------------------------------------------------------------------------

`include "qspi_definitions.vh"

module qspi_sclk_gen
#(
    parameter QSPI_DIVIDER_WIDTH = `QSPI_DIVIDER_WIDTH
)
(
    input  logic clk,
    input  logic reset,

    // register to SCK generator signals
    input  logic [QSPI_DIVIDER_WIDTH-1:0] clk_div,
    input  logic cpol,
    input  logic cpha,

    // controller to SCK generator signals
    input  logic sclk_en,

    input logic eos, // end of startup signal from STARTUPE2

    // SCK generator to shift register / flash clock path signals
    output logic qspi_sclk,
    output logic drive_tick,
    output logic sample_tick,
    output logic edge_tick,
    output logic sclk_idle
);

typedef enum {
    IDLE,
    CPHA_DELAY,
    EDGE1,
    EDGE2
} state_type;

state_type state_reg, state_next;
logic sclk_reg, sclk_next;
logic p_clk;
logic drive_tick_flag, sample_tick_flag;
logic [QSPI_DIVIDER_WIDTH-1:0] cnt_reg, cnt_next;

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        sclk_reg <= cpol; // idle state of SCLK based on CPOL
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
            cnt_next = 0; // reset counter for next phase
            if(sclk_en && eos) begin 
                if (cpha) begin
                    state_next = CPHA_DELAY; // start the sequence on enable
                end else begin
                    state_next = EDGE1;
                    drive_tick_flag = 1; // generate a drive tick on the first edge
                end
            end else begin
                state_next = IDLE;
            end
        end

        CPHA_DELAY: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = EDGE1;
                    drive_tick_flag = 1; // generate a drive tick on the first edge
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = CPHA_DELAY;
            end
        end

        EDGE1: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = EDGE2;
                    sample_tick_flag = 1; // generate a sample tick at the end of the EDGE2 phase
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = EDGE1;
            end
        end

        EDGE2: begin
            if(cnt_reg == clk_div - 1) begin
                cnt_next = 0; // reset counter for next phase
                if(sclk_en) begin
                    state_next = EDGE1;
                    drive_tick_flag = 1; // generate a drive tick at the end of the EDGE1 phase
                end else begin
                    state_next = IDLE; // go back to idle if disabled
                end
            end else begin
                cnt_next = cnt_reg + 1; // increment counter
                state_next = EDGE2;
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

assign p_clk = (state_next==EDGE2 && ~cpha) || (state_next==EDGE1 && cpha);
assign sclk_next = (cpol) ? ~p_clk : p_clk;

assign qspi_sclk = sclk_reg;
assign drive_tick = drive_tick_flag;
assign sample_tick = sample_tick_flag;
assign edge_tick = sclk_next != sclk_reg; // edge tick is high when state changes
assign sclk_idle = (state_reg == IDLE);

endmodule


