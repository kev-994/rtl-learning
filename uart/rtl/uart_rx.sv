`timescale 1ns/1ps
module uart_rx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 115_200,
    parameter DATA_WIDTH = 8
)(
    input logic clk,
    input logic reset,
    input logic rx,

    output logic [DATA_WIDTH-1:0] data_out,
    output logic data_valid
);

    // BAUD COUNTER
    localparam CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    localparam HALF_CLKS_PER_BIT = CLKS_PER_BIT / 2;
    localparam COUNTER_WIDTH = $clog2(CLKS_PER_BIT);
    localparam [COUNTER_WIDTH-1:0] MAX_COUNT = COUNTER_WIDTH'(CLKS_PER_BIT - 1);
    localparam [COUNTER_WIDTH-1:0] HALF_MAX_COUNT = COUNTER_WIDTH'(HALF_CLKS_PER_BIT - 1);
    logic baud_tick, half_baud_tick;
    logic [COUNTER_WIDTH-1:0] count;

    always_ff @(posedge clk) begin
        if (reset || (state == IDLE && !rx_sync) || (state == START && half_baud_tick && !rx_sync)) begin
            count <= 0;
        end
        
        else if (count == MAX_COUNT) begin
            count <= 0;
        end
        
        else begin
            count <= count + 1;
        end
    end

    assign baud_tick = (count == MAX_COUNT);
    assign half_baud_tick = (count == HALF_MAX_COUNT);


    // RX
    localparam BIT_COUNT_WIDTH = $clog2(DATA_WIDTH); // fails if data width is 1 bit 
    localparam [BIT_COUNT_WIDTH-1:0] MAX_BIT_COUNT = BIT_COUNT_WIDTH'(DATA_WIDTH - 1);
    logic [BIT_COUNT_WIDTH-1:0] bit_count;
    logic rx_meta, rx_sync;

    // 2-flop synchronizer
    always_ff @(posedge clk) begin
        if (reset) begin
            rx_meta <= 1;
            rx_sync <= 1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    typedef enum {
        IDLE,
        START,
        DATA,
        STOP
    }   state_t;

    state_t state, next_state;

    // state transition logic
    always_comb begin
        case (state)
        IDLE:  next_state = rx_sync ? IDLE : START;
        START: next_state = half_baud_tick ? (rx_sync ? IDLE : DATA) : START;
        DATA:  next_state = baud_tick ? (bit_count == MAX_BIT_COUNT ? STOP : DATA) : DATA;
        STOP:  next_state = baud_tick ? IDLE : STOP;
        default: next_state = IDLE;
        endcase
    end

    assign data_valid = (state == STOP && baud_tick && rx_sync); // could put this in the always_comb block

    // state register
    always_ff @(posedge clk) begin 
        if (reset) begin
            state     <= IDLE;
            data_out  <= 0;
            bit_count <= 0;
        end
        else begin
            state <= next_state;

            if (state == START && half_baud_tick && !rx_sync) // valid start
                bit_count <= 0;

            if (state == DATA && baud_tick) begin
                if (bit_count == MAX_BIT_COUNT)
                    bit_count <= 0;
                else begin
                    bit_count <= bit_count + 1;
                end
                data_out <= {rx_sync, data_out[DATA_WIDTH-1:1]};
            end
        end
    end

endmodule