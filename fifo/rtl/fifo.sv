`timescale 1ns / 1ps
module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 8
)(
    input  logic             clk,
    input  logic             reset,

    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,

    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,

    output logic             full,
    output logic             empty
);

    logic [WIDTH-1:0] mem_arr [0:DEPTH-1]; // mem_arr is an array containing DEPTH elements, where each element is WIDTH bits wide.
    logic [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr; 
    logic [$clog2(DEPTH):0] occupancy; 

    always_ff @(posedge clk) begin
        if (reset) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            occupancy <= 0;
            rd_data   <= 0;
        end
        
        else begin
            if (wr_en && !full) begin
                mem_arr[wr_ptr] <= wr_data;
                wr_ptr          <= wr_ptr + 1; // assuming DEPTH is a power of two, don't need to worry about wrapping around
                if (!(rd_en && !empty)) occupancy <= occupancy + 1; // only updates if not valid read
            end
            
            if (rd_en && !empty) begin
                rd_data   <= mem_arr[rd_ptr];
                rd_ptr    <= rd_ptr + 1; // assuming DEPTH is a power of two, don't need to worry about wrapping around
                if (!(wr_en && !full) ) occupancy <= occupancy - 1; // ony updates if not valid write
            end
        end
    end 
    /*
    NB if wr_en and rd_en are high only read happens
    */

    assign full  = (occupancy == DEPTH);
    assign empty = (occupancy == 0);
endmodule