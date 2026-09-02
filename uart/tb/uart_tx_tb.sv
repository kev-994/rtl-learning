`timescale 1ns/1ps
module uart_tx_tb #(
    parameter CLOCK_FREQ = 10_000_000,
    parameter BAUD_RATE  = 1_000_000, // CLKS_PER_BIT is 10
    parameter DATA_WIDTH = 8
);
    localparam BAUD_PERIOD = CLOCK_FREQ / BAUD_RATE; // CLKS_PER_BIT
    logic clk, reset, tx_start, tx, busy;
    logic [DATA_WIDTH-1:0] data_in;

    uart_tx #(
        .CLOCK_FREQ(CLOCK_FREQ),
        .BAUD_RATE(BAUD_RATE),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .data_in(data_in),
        .tx(tx),
        .busy(busy)
    );

    task automatic reset_tx();
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
    endtask

    task automatic baud_wait(int n); // wait for n baud periods
        repeat (n*BAUD_PERIOD) @(posedge clk);
        #1; 
    endtask

    task automatic start_tx();
        tx_start = 1;
        @(posedge clk);
        #1;
        tx_start = 0;
    endtask

    always #5 clk = ~clk; // clock time period 10ns

    initial begin
        $dumpfile("sim/uart_tx.vcd");
        $dumpvars(0, uart_tx_tb);
        
        clk      = 0;
        reset    = 1;
        tx_start = 0;
        data_in  = 0;

        // wait 2 baud periods and test tx and busy
        reset_tx();
        baud_wait(2);
        assert (tx)    else $error("tx is high before tx_start is asserted.");
        assert (!busy) else $error("uart tx is busy before tx_start.");


        // start transmission, confirm busy and start bit
        reset_tx();
        start_tx();
        assert (busy) else $error("uart tx isn't busy in START.");
        assert (!tx)  else $error("start bit should be 0.");
        

        // check first data bit
        reset_tx();
        data_in = 8'b0000_0001;
        start_tx();
        baud_wait(1);
        assert (busy) else $error("uart tx isn't busy in DATA.");
        assert (tx)   else $error("LSB should be 1.");

        
        // test all 8 data bits
        reset_tx();
        data_in = 8'b1010_0110;
        start_tx();
        baud_wait(1);
        for (int i=0; i < DATA_WIDTH; ++i) begin
            assert (busy) else $error("uart tx should be busy in DATA.");
            assert (tx == data_in[i]) else $error("tx_data doesn't match data_in.");
            baud_wait(1);
        end


        // test stop bit and returning to idle
        reset_tx();
        start_tx();
        baud_wait(1); // start
        baud_wait(8); // data
        assert (tx)   else $error("stop bit should be 1.");
        assert (busy) else $error("uart tx should be busy in STOP.");
        baud_wait(1); // stop
        assert (tx)    else $error("tx should be high in IDLE.");
        assert (!busy) else $error("uart tx should not be busy in IDLE.");


        // test back-to-back transmission, off the back of last test
        data_in = 8'b0101_1001;
        start_tx();
        baud_wait(1);
        for (int i=0; i < DATA_WIDTH; ++i) begin
            assert (busy) else $error("uart tx should be busy in DATA.");
            assert (tx == data_in[i]) else $error("tx_data doesn't match data_in.");
            baud_wait(1);
        end


        // test reset during active transmission
        reset_tx();
        start_tx();
        baud_wait(1);
        baud_wait(4); // mid transmission;
        reset_tx(); // reset mid transmission
        assert (tx)   else $error("tx should be high after reset (IDLE).");
        assert (!busy) else $error("uart tx should not be busy after reset (IDLE).");




        $finish;
    end

endmodule