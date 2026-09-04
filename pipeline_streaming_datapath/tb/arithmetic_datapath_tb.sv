`timescale 1ns/1ps
module arithmetic_datapath_tb;

    parameter DATA_WIDTH = 8;
    parameter logic [DATA_WIDTH-1:0] A = 2;
    parameter logic [DATA_WIDTH-1:0] B = 3;
    parameter logic [DATA_WIDTH-1:0] C = 4;

    logic clk;
    logic reset;

    logic [DATA_WIDTH-1:0]   in_data;
    logic                    in_valid;
    logic                    in_ready;

    logic [2*DATA_WIDTH+1:0] out_data;
    logic                    out_valid;
    logic                    out_ready;

    // Reference model
    logic [DATA_WIDTH:0]       expected_stage0; 
    logic [2*DATA_WIDTH:0]     expected_stage1; 
    logic [2*DATA_WIDTH+1:0]   expected;        
    logic [2*DATA_WIDTH+1:0]   ref_expected [$]; // FIFO

    arithmetic_datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .A(A),
        .B(B),
        .C(C)
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
        ref_expected.delete();
        @(posedge clk);
        #1;
        reset = 1'b0;
    endtask

    task automatic test_reset();
        reset_ad();
        
        assert (in_ready) else $error("in_ready should be asserted after reset.");
        assert (!out_valid) else $error("out_valid asserted after reset.");
    endtask

    // PRE-ARITHMETIC COMMENTED OUT
    
    /*
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
    */

    task automatic send_data(input logic [DATA_WIDTH-1:0] test_data);
        logic input_output_handshake;

        in_data = test_data;
        
        while (!in_ready) begin
            @(posedge clk);
            #1;
        end

        expected_stage0 = {1'b0, test_data} + {1'b0, A};
        expected_stage1 = {{DATA_WIDTH{1'b0}}, expected_stage0} * B;
        expected        = {1'b0, expected_stage1} + {{(DATA_WIDTH+1){1'b0}}, C};

        input_output_handshake = (in_ready && in_valid) && (out_ready && out_valid);

        if (input_output_handshake) begin
            assert (ref_expected.size() > 0)
                else $error("Output handshake occurred with empty reference queue.");

            ref_expected.pop_front();
        end
        ref_expected.push_back(expected);

        @(posedge clk);
        #1;
    endtask

    /*
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
    */

    // POST-ARITHMETIC TESTS ARE ESSENTIALY THE SAME, WITH A DIFFERENT VALUE FOR OUT_DATA

    task automatic test_single_arithmetic_transaction(input logic [DATA_WIDTH-1:0] test_data);
        reset_ad();

        in_valid = 1'b1;
        in_data = test_data;
        expected_stage0 = {1'b0, test_data} + {1'b0, A};
        expected_stage1 = {{DATA_WIDTH{1'b0}}, expected_stage0} * B;
        expected        = {1'b0, expected_stage1} + {{(DATA_WIDTH+1){1'b0}}, C};

        assert (in_ready) else $error("pipeline should be ready to accept data."); // handshake
        
        @(posedge clk);
        #1;

        in_valid = 1'b0; // stop accepting data

        repeat (2) @(posedge clk);
        #1;

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == expected)
            else $error("Expected %0d, got %0d", expected, out_data);
    endtask

    task automatic test_continuous_arithmetic_stream();
        reset_ad();

        in_valid  = 1'b1;
        out_ready = 1'b1;

        send_data(8'hA5);
        send_data(8'h3C);
        send_data(8'h7F);
        
        // pipeline now filled

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == ref_expected[0]) 
            else $error("Expected %0d, got %0d", ref_expected[0], out_data);

        send_data(8'h12);

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == ref_expected[0]) 
            else $error("Expected %0d, got %0d", ref_expected[0], out_data);

        send_data(8'hE1);

        assert (in_ready) else $error("pipeline should be ready to accept data.");
        assert (out_valid) else $error("stage 2 should be full.");
        assert (out_data == ref_expected[0]) 
            else $error("Expected %0d, got %0d", ref_expected[0], out_data);

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

        // PRE-ARITHMETIC
        
        /*
        // test single transaction
        test_single_transaction(8'hA5);


        // test continuous stream
        test_continuous_stream();


        // test stalling
        test_stall();
        */

        // POST-ARITHMETIC

        test_single_arithmetic_transaction(8'hA5);

        test_continuous_arithmetic_stream();


        $finish;
    end


endmodule