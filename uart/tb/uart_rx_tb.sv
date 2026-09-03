`timescale 1ns/1ps
module uart_rx_tb #(
    parameter CLOCK_FREQ = 10_000_000,
    parameter BAUD_RATE  = 1_000_000, // CLKS_PER_BIT is 10
    parameter DATA_WIDTH = 8
);
    localparam CLKS_PER_BIT = CLOCK_FREQ / BAUD_RATE; // BAUD PERIOD
    logic clk, reset, rx, data_valid, received_valid;
    logic [DATA_WIDTH-1:0] data_out;

    uart_rx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_valid(data_valid),
        .data_out(data_out)
    );

    task automatic reset_rx();
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
    endtask

    task automatic send_bit(input logic bit_value);
        rx = bit_value;

        repeat (CLKS_PER_BIT) @(posedge clk);
        #1;
    endtask

    task automatic send_byte(input logic [DATA_WIDTH-1:0] data_value);
        send_bit(1'b0); // start bit

        for (int i=0; i < DATA_WIDTH; ++i) begin
            send_bit(data_value[i]);
        end

        send_bit(1'b1); // stop bit
    endtask

    task automatic test_byte(input logic [DATA_WIDTH-1:0] test_data);
        received_valid = 0;
        reset_rx();
        send_byte(test_data);
        assert (data_out == test_data) else $error("data_out doesn't match expected_data.");
        assert (received_valid) else $error("data_valid was never asserted.");
    endtask

    task automatic test_consecutive(input logic [DATA_WIDTH-1:0] test_data, input int n); // test n consecutive identical frames
        reset_rx();
        
        for (int i=0; i < n; i++) begin
            received_valid = 0;
            send_byte(test_data);
            assert (received_valid) else $error("data_valid not asserted.");
            assert (data_out == test_data) else $error("data_out doesn't match test data.");
        end
    endtask

    task automatic test_invalid_stop(input logic [DATA_WIDTH-1:0] test_data);
        reset_rx();
        received_valid = 0;
        
        send_bit(1'b0); // start bit

        for (int i=0; i < DATA_WIDTH; ++i) begin
            send_bit(test_data[i]);
        end

        send_bit(1'b0); // not a valid stop bit

        assert (!received_valid) else $error("data_valid asserted after invalid stop bit.");
    endtask

    always_ff @(posedge clk) begin
            if (data_valid)
                received_valid <= 1;
    end

    always #5 clk = ~clk; // clock period 10ns

    initial begin
        $dumpfile("sim/uart_rx.vcd");
        $dumpvars(0, uart_rx_tb);
        $dumpvars(0, uart_rx_tb.dut);
        
        clk = 0;
        reset = 1;
        rx = 1;
        received_valid = 0;

        // test reset
        reset_rx();
        repeat (CLKS_PER_BIT) @(posedge clk);
        #1;
        assert (data_out == 0) else $error("Unexpected output after reset.");
        assert (!data_valid)   else $error("Unexpected output after reset");


        // test invalid start bit
        reset_rx();
        rx = 0;
        repeat (3) @(posedge clk); // shorter than half a bit period
        #1;
        rx = 1;
        repeat (2*CLKS_PER_BIT) @(posedge clk); // potentially start receiving data
        #1;
        assert (!data_valid) else $error("data_valid asserted for invalid start bit.");
        assert (data_out == 0) else $error("data_out changed after invalid start bit.");


        // test valid start bit, observe waveform
        reset_rx();
        rx = 0;
        repeat (CLKS_PER_BIT) @(posedge clk);
        #1;
        rx = 1;
        assert (!data_valid) else $error("data_valid asserted unexpectedly.");


        // automate frame test, test multiple values
        test_byte(8'b1010_0101);
        test_byte(8'b0000_0000);
        test_byte(8'b1111_1111);
        test_byte(8'b0101_1010);
        test_byte(8'b0000_0001);
        test_byte(8'b1000_0000);


        // test back to back frames, no reset between frames
        received_valid = 0;
        reset_rx();
        send_byte(8'hB2);
        assert (received_valid) else $error("data_valid not asserted.");
        assert (data_out == 8'hB2) else $error("data_out doesn't match test data.");
        received_valid = 0; // reset for next frame
        send_byte(8'h5C);
        assert (received_valid) else $error("data_valid not asserted.");
        assert (data_out == 8'h5C) else $error("data_out doesn't match test data.");


        // test consecutive identical frames
        test_consecutive(8'h09, 4);
        test_consecutive(8'h10, 7);


        // test invalid data
        test_invalid_stop(8'b1010_0101);
        test_invalid_stop(8'b0000_0000);
        test_invalid_stop(8'b1111_1111);
        test_invalid_stop(8'b0101_1010);
        test_invalid_stop(8'b0000_0001);
        test_invalid_stop(8'b1000_0000);

        /*
        Parameterisation/edge-case testing would be the next step.
        It's just kind of long.
        */

        $finish;
    
    end


endmodule