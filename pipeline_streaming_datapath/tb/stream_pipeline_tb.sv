`timescale 1ns/1ps
module stream_pipeline_tb;

    parameter DATA_WIDTH = 8;

    logic clk;
    logic reset;

    logic [DATA_WIDTH-1:0] in_data;
    logic                  in_valid;
    logic                  in_ready;

    logic [DATA_WIDTH-1:0] out_data;
    logic                  out_valid;
    logic                  out_ready;

    stream_pipeline #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk       (clk),
        .reset     (reset),
        .in_data   (in_data),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .out_data  (out_data),
        .out_valid (out_valid),
        .out_ready (out_ready)
    );

    task automatic reset_sp();
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
    endtask

    task automatic test_reset();
        reset_sp();
        
        assert (in_ready) else $error("in_ready should be asserted after reset.");
        assert (!out_valid) else $error("out_valid asserted after reset.");
        assert (out_data == 0) else $error("data in buffer should be reset to 0 after reset.");
    endtask
    
    task automatic test_transaction_enters(input logic [DATA_WIDTH-1:0] test_data);
        reset_sp();

        in_data = test_data;
        in_valid = 1;

        assert (in_ready) else $error("Buffer not ready to accept transaction.");
        
        @(posedge clk);
        #1;

        in_valid = 0;

        assert (out_valid) else $error("out_valid not asserted when buffer is full.");
        assert (out_data == test_data) else $error("out_data has unexpected value.");
        assert (!in_ready) else $error("Buffer should be full after transaction.");
    endtask

    task automatic test_transaction_leaves(input logic [DATA_WIDTH-1:0] test_data);
        reset_sp();

        in_data = test_data;
        in_valid = 1;

        @(posedge clk);
        #1;

        in_valid = 0;

        out_ready = 1;

        @(posedge clk);
        #1;

        out_ready = 0;
        
        assert (!out_valid) else $error("out_valid asserted though buffer should be empty.");
        assert (in_ready) else $error("in_ready not asserted though buffer is empty");
    endtask

    task automatic test_simultaneous_transfer(input logic [DATA_WIDTH-1:0] test_data1, input logic [DATA_WIDTH-1:0] test_data2);
        reset_sp();

        in_data = test_data1;
        in_valid = 1;

        @(posedge clk);
        #1;

        in_valid = 0;
        
        ///// other transaction
        
        out_ready = 1;
        in_data = test_data2;
        in_valid = 1;

        #1; // give time for in_ready to evaluate the combinational logic

        // $display("in_ready=%b out_ready=%b out_valid=%b in_valid=%b",
        //  in_ready, out_ready, out_valid, in_valid);

        assert (out_valid) else $error("out_valid not asserted though currenct transaction is being consumed.");
        assert (in_ready) else $error("in_ready not asserted though current transaction is being consumed.");

        @(posedge clk);
        #1;

        in_valid = 0;

        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == test_data2) else $error("out_data has unexpected value.");
    endtask

    task automatic send_data(input logic [DATA_WIDTH-1:0] test_data);
        in_data = test_data;
        
        while (!in_ready) begin
            @(posedge clk);
            #1;
        end

        @(posedge clk);
        #1;
    endtask


    task automatic test_continuous_stream();
        reset_sp();

        out_ready = 1'b1;
        in_valid  = 1'b1;

        send_data(8'hA5);       
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'hA5) else $error("out_data has unexpected value.");

        send_data(8'h3C);
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'h3C) else $error("out_data has unexpected value.");

        send_data(8'h7F);
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'h7F) else $error("out_data has unexpected value.");

        send_data(8'h12);
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'h12) else $error("out_data has unexpected value.");

        send_data(8'hE1);
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is still high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'hE1) else $error("out_data has unexpected value.");

        out_ready = 1'b0;
        in_valid  = 1'b0;
    endtask

    task automatic test_stall();
        reset_sp();

        out_ready = 1'b1;
        in_valid  = 1'b1;

        send_data(8'hA5);       
        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'hA5) else $error("out_data has unexpected value.");

        out_ready = 1'b0;

        in_data = 8'h3C;
        repeat (5) begin
            @(posedge clk);
            #1;
            assert (!in_ready) else $error("in_ready asserted though buffer is full.");  // out_ready is low
            assert (out_valid) else $error("out_valid not asserted during continous streaming.");
            assert (out_data == 8'hA5) else $error("out_data has unexpected value.");
            assert (in_data == 8'h3C) else $error("Producer changed data while transaction was stalled.");
        end

        out_ready = 1'b1;

        @(posedge clk);
        #1; 

        assert (in_ready) else $error("in_ready not asserted during continuous streaming.");  // out_ready is high
        assert (out_valid) else $error("out_valid not asserted during continous streaming.");
        assert (out_data == 8'h3C) else $error("out_data has unexpected value.");

        out_ready = 1'b0;
        in_valid  = 1'b0;
    endtask


    always #5 clk = ~clk; // time period of 10ns

    initial begin
        clk       = 0;
        reset     = 1;
        in_valid  = 0;
        out_ready = 0;


        // test reset
        test_reset();


        // test transaction entering
        test_transaction_enters(8'hA5);


        // off the back of last test, test consumer backpressure
        out_ready = 0;
        in_valid  = 1;
        in_data   = 8'h3C;

        @(posedge clk);
        #1;

        assert (!in_ready) else $error("in_ready asserted though buffer is full.");
        assert (out_valid) else $error("out_valid not asserted though buffer is full.");
        assert (out_data == 8'hA5) else $error("Data entered a full buffer.");


        // test transaction leaving
        test_transaction_leaves(8'hA5);

        
        // test simultaneous transfer
        test_simultaneous_transfer(8'hA5, 8'h3C);


        // test continuous stream
        test_continuous_stream();


        // test stalling, mid continous stream
        test_stall();
        $finish;
    end

endmodule