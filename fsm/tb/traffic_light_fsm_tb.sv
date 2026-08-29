`timescale 1ns / 1ps
module fsm_tb;
    logic clk, reset, ena, red, green, yellow;

    fsm dut (
        .clk(clk),
        .reset(reset),
        .ena(ena),
        .red(red),
        .green(green),
        .yellow(yellow)
    );

    always #5 clk = ~clk; // period of 10 ns


    

    initial begin
        clk = 0;
        reset = 1;
        ena = 1;

        #20;
        reset = 0;
         
        // NB enable is high
        if (!(red && !green && !yellow)) $error("Output after reset isn't red.");

        @(posedge clk);
        #1;
        if (!(!red && green && !yellow)) $error("Output after red isn't green.");

        @(posedge clk);
        #1;
        if (!(!red && !green && yellow)) $error("Output after green isn't yellow.");
  
        // enable deasserted
        ena = 0;

        @(posedge clk);
        #1;
        if (!(!red && !green && yellow)) $error("Output after yellow isn't yellow though enable is low.");

        // test again
        @(posedge clk);
        #1;
        if (!(!red && !green && yellow)) $error("Output after yellow isn't yellow though enable is low.");

        // enable asserted
        ena = 1;

        @(posedge clk);
        #1;
        if (!(red && !green && !yellow)) $error("Output after yellow isn't red.");

        @(posedge clk); // changes to green on this clock edge
        reset = 1; // assert reset
        
        // check state resets to red (mid-operation)
        @(posedge clk);
        #1;
        if (!(red && !green && !yellow)) $error("Output after mid-operation reset isn't red.");

        $finish;
    end
 
endmodule

