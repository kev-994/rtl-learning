`timescale 1ns/1ps
module uart_tx #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 115_200,
    parameter DATA_WIDTH = 8
)(
    input logic       clk,
    input logic       reset,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic       tx_start,


    output logic      tx,
    output logic      busy
);

    // BAUD COUNTER
    localparam CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    localparam COUNTER_WIDTH = $clog2(CLKS_PER_BIT);
    localparam [COUNTER_WIDTH-1:0] MAX_COUNT = COUNTER_WIDTH'(CLKS_PER_BIT - 1);
    logic baud_tick;
    logic [COUNTER_WIDTH-1:0] count;

    always_ff @(posedge clk) begin
        if (reset || (state == IDLE && tx_start)) begin
            count <= 0; // reset the baud counter when tx_start
        end
        
        else if (count == MAX_COUNT) begin
            count <= 0;
        end
        
        else begin
            count <= count + 1;
        end
    end

    assign baud_tick = (count == MAX_COUNT);

    // TX
    localparam BIT_COUNT_WIDTH = $clog2(DATA_WIDTH); // fails if data width is 1 bit 
    localparam [BIT_COUNT_WIDTH-1:0] MAX_BIT_COUNT = BIT_COUNT_WIDTH'(DATA_WIDTH - 1);
    logic [DATA_WIDTH-1:0] tx_data;
    logic [BIT_COUNT_WIDTH-1:0] bit_count;

    typedef enum {
        IDLE,
        START,
        DATA,
        STOP
    }   state_t;

    state_t state, next_state;

    assign tx   = ((state == IDLE) ||
                   (state == DATA && tx_data[bit_count]) ||
                   (state == STOP));
    assign busy = (state != IDLE); 

    // state register
    always_ff @(posedge clk) begin
        if (reset) begin
            state     <= IDLE;
            tx_data   <= 0;
            bit_count <= 0;
        end
        
        else begin
            state <= next_state;
            
            if (state == IDLE && tx_start) begin
                tx_data <= data_in; // capture the data
                bit_count <= 0;
            end

            if (state == DATA && baud_tick) begin
                if (bit_count == MAX_BIT_COUNT) 
                    bit_count <= 0;
                else 
                    bit_count <= bit_count + 1;
            end
        end
    end

    // state transition logic
    always_comb begin
        case (state)
        IDLE:  next_state = tx_start ? START : IDLE;
        START: next_state = baud_tick ? DATA : START;
        DATA:  next_state = baud_tick ? (bit_count == MAX_BIT_COUNT ? STOP : DATA) : DATA;
        STOP:  next_state = baud_tick ? IDLE : STOP;
        default: next_state = IDLE; 
        endcase
    end
endmodule