`timescale 1ns / 1ps
module fsm(
    input clk,
    input reset,
    input ena,
    output red,
    output green, 
    output yellow
);

    typedef enum {
        RED,
        GREEN,
        YELLOW
    }   state_t;

    state_t state, nextState;

    // state transition logic
    always_comb begin
        case (state) 
        RED:     nextState = ena ?  GREEN : RED;
        GREEN:   nextState = ena ? YELLOW : GREEN;
        YELLOW:  nextState = ena ? RED : YELLOW;
        default: nextState = RED;
        endcase
    end

    // state storage
    always_ff @(posedge clk) begin 
        if (reset) state <= RED;
        else state <= nextState;
    end

    // output logic
    assign red    = (state == RED);
    assign green  = (state == GREEN);
    assign yellow = (state == YELLOW);

endmodule