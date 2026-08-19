module counter_tb;
    logic clk, reset; 
    logic [3:0] count, expected;

    counter dut (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;

        #12 reset = 0;
    end

    initial begin
        expected = 0;
        
        @(negedge reset);
        
        repeat (10) begin
            @(posedge clk);
            
            assert (count == expected)
                else $error("Count does not match expected");

            ++expected;
            
    end

    $finish;
end
endmodule