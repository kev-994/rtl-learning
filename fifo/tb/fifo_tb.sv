`timescale 1ns / 1ps
module fifo_tb #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
);
    logic clk, reset, wr_en, rd_en, full, empty;
    logic [WIDTH-1:0] wr_data, rd_data, ref_data;
    logic [WIDTH-1:0] ref_fifo [$]; // reference model (queue)
    logic [31:0] wr, random_data;

    fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    // Write transaction
    task write(logic [WIDTH-1:0] value);
        logic valid_write;
        
        wr_data = value;
        wr_en = 1;

        valid_write = ref_fifo.size() < DEPTH;

        if (valid_write) ref_fifo.push_back(wr_data);

        @(posedge clk);
        #1;

        wr_en = 0;
    endtask

    // Read task
    task read();
        logic valid_read;
        
        rd_en = 1;

        valid_read = ref_fifo.size() > 0;

        if (valid_read) ref_data = ref_fifo.pop_front();

        @(posedge clk);
        #1;
        if (valid_read)
            assert (rd_data == ref_data) else $error("Reference date doesn't match read data.");

        rd_en = 0;
    endtask
    

    always #5 clk = ~clk; // clock time period 10 ns

    initial begin
        clk = 0;
        reset = 1;
        wr_en = 0;
        rd_en = 0;
        wr_data = 0;
        
        // TEST RESET
        repeat (2) @(posedge clk); 
        #1;
        assert (empty) else $error("FIFO not empty after reset.");
        assert (!full) else $error("FIFO full after reset.");
        assert (rd_data == 0) else $error("Read data not zero after reset.");

        reset = 0;
        // FIFO should remain empty when neither reading or writing
        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO not empty after reset.");
        assert (!full) else $error("FIFO full after reset.");
        assert (rd_data == 0) else $error("Read data not zero after reset.");

        wr_data = 8'hA5;
        wr_en   = 1;
        // write data, read not enabled yet
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after writing one value.");
        assert (rd_data == 0) else $error("Read not zero though not enabled.");

        // enable read
        rd_en = 1;
        wr_en = 0; // disable writing
        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO not empty after reading only value.");
        assert (!full) else $error("FIFO full after reading only value.");
        assert (rd_data == 8'hA5) else $error("Read operation failed.");
        rd_en = 0; // disable read 

        
        
        // TEST FIFO ORDER
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        
        wr_en = 1;
        wr_data = 8'hFF;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after writing one value.");
        assert (rd_data == 0) else $error("Read not zero though not enabled.");

        wr_data = 8'h18;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after writing two values.");
        assert (rd_data == 0) else $error("Read not zero though not enabled.");

        wr_data = 8'hC0;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after writing three values.");
        assert (rd_data == 0) else $error("Read not zero though not enabled.");

        wr_en = 0;
        // disable write and test FIFO
        rd_en = 1;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after values written.");
        assert (rd_data == 8'hFF) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO empty after writing data.");
        assert (!full)  else $error("FIFO full after values written.");
        assert (rd_data == 8'h18) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO not empty after reading only value.");
        assert (!full)  else $error("FIFO full after reading only value.");
        assert (rd_data == 8'hC0) else $error("Read operation failed.");
        rd_en = 0; // disable read after testing



        // TEST FILLING FIFO
        reset = 1; // reset FIFO
        @(posedge clk);
        #1;
        reset = 0;

        wr_en = 1;
        wr_data = 8'h01;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h02;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");  

        wr_data = 8'h03;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed."); 

        wr_data = 8'h04;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h05;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h06;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h07;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(!full)  else $error("FIFO should not be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h08;
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(full)  else $error("FIFO should be full.");
        assert(rd_data == 0) else $error("Read operation failed.");

        wr_data = 8'h09; // need to check that this value never makes it in
        @(posedge clk);
        #1;
        assert(!empty) else $error("FIFO should not be empty.");
        assert(full)   else $error("FIFO should be full.");
        assert(rd_data == 0) else $error("Read operation failed.");
        wr_en = 0; // disable writing

        // start checking reading follows FIFO order
        rd_en = 1;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h01); else $error("Read operation failed.");
        
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h02); else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h03); else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h04); else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h05); else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h06); else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h07); else $error("Read operation failed.");

        // 8'h09 should never have been accepted; after reading 08, FIFO should be empty
        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO should be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h08); else $error("Read operation failed.");
        rd_en = 0;

        

        // TEST WRAP AROUND (CIRCULAR FIFO)
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;

        // Write in 6 values then read them, pointers will be at location 6
        wr_en = 1;
        wr_data = 8'h01;
        @(posedge clk);
        #1;
        wr_data = 8'h02;
        @(posedge clk);
        #1;
        wr_data = 8'h03;
        @(posedge clk);
        #1;
        wr_data = 8'h04;
        @(posedge clk);
        #1;
        wr_data = 8'h05;
        @(posedge clk);
        #1;
        wr_data = 8'h06;
        @(posedge clk);
        #1;
        wr_en = 0; // disable writing then read all values currently in FIFO

        rd_en = 1;
        repeat (6) @(posedge clk); // should really check all of these reads
        #1
        rd_en = 0;

        // write in 4 values, last two should wrap around to locations 0 and 1
        wr_en = 1;
        wr_data = 8'h07;
        @(posedge clk);
        #1;
        wr_data = 8'h08;
        @(posedge clk);
        #1;
        wr_data = 8'h09;
        @(posedge clk);
        #1;
        wr_data = 8'h10;
        @(posedge clk);
        #1;
        wr_en = 0; // disable write then read values that should wrap around

        rd_en = 1;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h07) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h08) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h09) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO should be empty.");
        assert (!full)  else $error("FIFO should not be full.");
        assert (rd_data == 8'h10) else $error("Read operation failed.");
        rd_en = 0;



        // TEST SIMULTANEOUS R/W
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;

        wr_en = 1;
        wr_data = 8'h01;
        @(posedge clk);
        #1;
        wr_data = 8'h02;
        @(posedge clk);
        #1;
        wr_data = 8'h03;
        @(posedge clk);
        #1;

        rd_en = 1; // now read and write both enabled
        wr_data = 8'h04;
        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty");
        assert (!full)  else $error("FIFO should not be full");
        assert (rd_data == 8'h01) else $error("Read operation failed."); // read should occur
        wr_en = 0; // disable writing and read the rest of the values

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty");
        assert (!full)  else $error("FIFO should not be full");
        assert (rd_data == 8'h02) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (!empty) else $error("FIFO should not be empty");
        assert (!full)  else $error("FIFO should not be full");
        assert (rd_data == 8'h03) else $error("Read operation failed.");

        @(posedge clk);
        #1;
        assert (empty) else $error("FIFO should be empty"); // should now be empty
        assert (!full)  else $error("FIFO should not be full");
        assert (rd_data == 8'h04) else $error("Read operation failed."); // value written in whilst read was high 
        rd_en = 0;
        










        // REFERENCE MODEL

        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        ref_fifo.delete();

        // 1-value test
        wr_en = 1;
        rd_en = 0;
        
        wr_data = 8'hA5;
        if (wr_en && !full) ref_fifo.push_back(8'hA5);
        @(posedge clk);
        #1;
        
        wr_en = 0;
        rd_en = 1;
        
        if (rd_en && !empty) ref_data = ref_fifo.pop_front();
        @(posedge clk);
        #1;
        assert (ref_fifo.size() == 0) else $error("Reference model not empty after reading only value.");
        assert (rd_data == ref_data) else $error("Writing then reading one value failed.");
        
        wr_en = 0;
        rd_en = 0;

        

        // 4-value test
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        ref_fifo.delete();

        write(8'hA5);
        write(8'h18);
        write(8'hC0);
        write(8'h72);

        read();
        read();
        read();
        read();
        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        


        // simultaneous r/w test
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        ref_fifo.delete();

        wr_en = 1;
        rd_en = 0;

        wr_data = 8'hA5;
        if (wr_en && !full) ref_fifo.push_back(8'hA5);
        @(posedge clk);
        #1;

        wr_data = 8'h18;
        if (wr_en && !full) ref_fifo.push_back(8'h18);
        @(posedge clk);
        #1;

        wr_data = 8'hC0;
        if (wr_en && !full) ref_fifo.push_back(8'hC0);
        @(posedge clk);
        #1;

        wr_en = 1;
        rd_en = 1;

        wr_data = 8'h72;
        if (wr_en && !full) ref_fifo.push_back(8'h72);
        if (rd_en && !empty) ref_data = ref_fifo.pop_front();
        @(posedge clk);
        #1;
        assert (rd_data == ref_data) else $error("Reference data doesn't match read data.");

        wr_en = 0;
        rd_en = 1;

        if (rd_en && !empty) ref_data = ref_fifo.pop_front();
        @(posedge clk);
        #1;
        assert (rd_data == ref_data) else $error("Reference data doesn't match read data.");

        if (rd_en && !empty) ref_data = ref_fifo.pop_front();
        @(posedge clk);
        #1;
        assert (rd_data == ref_data) else $error("Reference data doesn't match read data.");

        if (rd_en && !empty) ref_data = ref_fifo.pop_front();
        @(posedge clk);
        #1;
        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        assert (rd_data == ref_data) else $error("Reference data doesn't match read data.");

        wr_en = 0;
        rd_en = 0;




        // test reading while empty
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        ref_fifo.delete();

        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        assert (empty) else $error("FIFO should be empty.");
        assert (!full) else $error("FIFO should not be full.");

        read(); // attempt invalid read

        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        assert (empty) else $error("FIFO should be empty.");
        assert (!full) else $error("FIFO should not be full.");
        assert (rd_data == 0) else $error("Read operation failed.");




        // test writing while full
        reset = 1;
        @(posedge clk);
        #1;
        reset = 0;
        ref_fifo.delete();

        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        assert (empty) else $error("FIFO should be empty.");
        assert (!full) else $error("FIFO should not be full.");

        write(8'h01);
        write(8'h02);
        write(8'h03);
        write(8'h04);
        write(8'h05);
        write(8'h06);
        write(8'h07);
        write(8'h08);

        assert (ref_fifo.size() == DEPTH) else $error("Reference model should be at capacity.");
        assert (!empty) else $error("FIFO should not be empty.");
        assert (full) else $error("FIFO should be full.");

        
        write(8'h09); // invalid write

        assert (ref_fifo.size() == DEPTH) else $error("Reference model should be at capacity.");
        assert (!empty) else $error("FIFO should not be empty.");
        assert (full) else $error("FIFO should be full.");

        read();
        read();
        read();
        read();
        read();
        read();
        read();
        read();

        assert (rd_data == 8'h08) else $error("Read operation failed.");
        assert (ref_fifo.size() == 0) else $error("Reference model should be empty.");
        assert (empty) else $error("FIFO should be empty.");
        assert (!full) else $error("FIFO should not be full.");















        
        // generating randomized tests
        repeat (1000) begin
            wr = $urandom % 2;
            if (wr[0]) begin
                random_data = $urandom;
                write(random_data[WIDTH-1:0]);
            end
            else 
                read();
            
            if (ref_fifo.size() == 0) 
                assert (empty) else $error("Reference model doesn't match FIFO");
            if (ref_fifo.size() == DEPTH) 
                assert (full) else $error("Reference model doesn't match FIFO");
            
        end // would be good to check ref_fifo.size() == occupancy

        // drain contents and check against DUT
        while (ref_fifo.size() != 0)
            read();
        assert (ref_fifo.size() == 0 && empty && !full) else $error("Issue after draining contents following randomized tests.");
        
        $finish;
    end 

endmodule