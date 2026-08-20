module counter_tb;
    logic clk, reset; 
    logic [3:0] count, expected, expected_overflow;

    counter dut (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin // stimulus
        $dumpfile("counter.vcd");
        $dumpvars(0, counter_tb);
        
        clk = 0;
        reset = 1;

        #12 reset = 0;

        #20 reset = 1;

        #10 reset = 0;
    end

    initial begin // test reset
    @(posedge reset);
    @(posedge clk);
    #1; // tiny delay to check count just after rising edge of clk
    assert (count == 0)
        else $error("Reset asserted, count not zero");
    $display("Reset test passed");
    end
    
    initial begin // test counting
        expected = 0;
        
        @(negedge reset);
        
        repeat (10) begin
            @(posedge clk);
            
            assert (count == expected)
                else $error("Count does not match expected");
            
            if (!reset) 
                ++expected;
            else
                expected = 0;   
        end    
        $display("Counting test passed");
    end

    initial begin // test overflow
        expected_overflow = 0;

        @(negedge reset);
        
        while (expected_overflow < 14) begin
            @(posedge clk);

            if (!reset)
                ++expected_overflow;
            else
                expected_overflow = 0;
        end
        
        repeat (3) begin
            @(posedge clk);

            assert (count == expected_overflow)
                else $error("Overflow error");

            if (!reset) 
                ++expected_overflow;
            else
                expected_overflow = 0;   
        end
        $display("Overflow test passed");
        $finish;
    end

    initial begin // test reset during operation
    @(negedge reset);
    
    @(posedge reset);

    assert (count != 0)
        else $error("Counter did not start counting");
    
    @(posedge clk);

    #1;
    assert (count == 0)
        else $error("Mid operation reset failed");
    
    $display("Mid operation reset test passed");
    end
endmodule