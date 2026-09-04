`timescale 1ns/1ps
module arithmetic_datapath_tb;

    parameter DATA_WIDTH = 8;

    logic clk;
    logic reset;

    logic [DATA_WIDTH-1:0] in_data;
    logic                  in_valid;
    logic                  in_ready;

    logic [DATA_WIDTH-1:0] out_data;
    logic                  out_valid;
    logic                  out_ready;

    arithmetic_datapath #(
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

    task automatic reset_ad();
        reset = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
    endtask

    task automatic test_reset();
        reset_ad();
        
        assert (in_ready) else $error("in_ready should be asserted after reset.");
        assert (!out_valid) else $error("out_valid asserted after reset.");
    endtask

    task automatic test_single_transaction(input logic [DATA_WIDTH-1:0] test_data);
        reset_ad();

        in_valid = 1'b1;
        in_data = test_data;

        assert (in_ready) else $error("pipeline should be ready to accept data."); // handshake
        
        @(posedge clk);
        #1;

        in_valid = 1'b0; // stop accepting data

        repeat (2) @(posedge clk);
        #1;

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == test_data) else $error("out_data has unexpected value.");
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
        reset_ad();

        in_valid  = 1'b1;
        out_ready = 1'b1;

        send_data(8'hA5);
        send_data(8'h3C);
        send_data(8'h7F);
        
        // pipeline now filled

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'hA5) else $error("out_data has unexpected value.");

        send_data(8'h12);

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'h3C) else $error("out_data has unexpected value.");

        send_data(8'hE1);

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'h7F) else $error("out_data has unexpected value.");

        in_valid  = 1'b0;
        out_ready = 1'b0;
    endtask

    task automatic test_stall();
        reset_ad();

        in_valid  = 1'b1;
        out_ready = 1'b1;

        send_data(8'hA5);
        send_data(8'h3C);
        send_data(8'h7F);
        
        // pipeline now filled

        out_ready = 1'b0; // stall pipeline, apply backpressure
        in_data = 8'h12; // should be held at input

        repeat (5) begin 
            @(posedge clk);
            #1;

            assert (!in_ready) else $error("pipeline should not be ready to accept data.");
            assert (out_valid) else $error("stage 2 should remain full during stall.");
            assert (out_data == 8'hA5) else $error("out_data changed during stall.");
        end

        out_ready = 1'b1; // pipeline should start moving again

        // A5 leaves
        @(posedge clk);
        #1;
        
        in_valid  = 1'b0; // stop accepting data

        assert (in_ready)  else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'h3C) else $error("Expected 3C after stall.");

        // 3C leaves
        @(posedge clk);
        #1;

        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'h7F) else $error("Expected 7F after 3C.");

        // 7F leaves
        @(posedge clk);
        #1;

        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == 8'h12) else $error("Expected 12 after 7F.");

        // 12 leaves, empty pipeline
        @(posedge clk);
        #1;
        
        assert (!out_valid) else $error("stage 2 should be empty.");

        in_valid  = 1'b0; 
        out_ready = 1'b0;
    endtask


    always #5 clk = ~clk;

    initial begin 
        clk       = 0;
        reset     = 1;
        in_valid  = 0;
        out_ready = 0;


        // test reset
        test_reset();


        // test single transaction
        test_single_transaction(8'hA5);


        // test continuous stream
        test_continuous_stream();


        // test stalling
        test_stall();
        $finish;
    end


endmodule