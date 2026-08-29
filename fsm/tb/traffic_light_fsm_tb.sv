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
        $dumpfile("sim/fsm.vcd");
        $dumpvars(0, fsm_tb);
        
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

    // display
    always @(posedge clk) begin
        $display("t=%0t reset=%b ena=%b red=%b green=%b yellow=%b",
             $time, reset, ena, red, green, yellow);
    end

    // exactly one high output at all times
    always @(posedge clk) begin
        assert (red + green + yellow == 1)
            else $error("Exactly one output should be high at each clock edge");
    end

    // FSM state doesn't change if ena is low, note that if reset is high state should change
    assert property (
        @(posedge clk)
        disable iff (reset)
        !ena |=> ($past(red) == red) && ($past(green) == green) && ($past(yellow) == yellow)
    ); else $error("State change occurs when enable is low.");

    // Red to green 
    assert property (
        @(posedge clk)
        disable iff (reset)
        (ena && (red == 1)) |=> green == 1
    ); else $error("Red to green transition failed.");

    // Green to yellow
    assert property (
        @(posedge clk)
        disable iff (reset)
        (ena && (green == 1)) |=> yellow == 1
    ); else $error("Green to yellow transition failed.");

    // Yellow to red
    assert property (
        @(posedge clk)
        disable iff (reset)
        (ena && (yellow == 1)) |=> red == 1
    ); else $error("Yellow to red transition failed.");

    // Reset asserted should result in red
    assert property (
        @(posedge clk)
        reset |=> red == 1
    ); else $error("Output isn't red after reset asserted");
endmodule

