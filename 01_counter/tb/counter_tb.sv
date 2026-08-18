module counter_tb;
    logic clk, reset; 
    logic [3:0] count, expected_count;

    counter dut (
        .clk(clk),
        .reset(reset),
        .count(count)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;

        #15 reset = 0;
        #50 $finish;
    end

    initial begin
        repeat (10) begin
            @(posedge clk);
            if (!reset) begin
                $display(count);
                 
            end
        end
    end
endmodule