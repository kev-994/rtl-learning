module counter_tb;
    logic clk, reset; 
    logic [3:0] count, expected;

    counter dut (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin // stimulus
        clk = 0;
        reset = 1;

        #12 reset = 0;

        #20 reset = 1;
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
    
    $finish;
end
endmodule