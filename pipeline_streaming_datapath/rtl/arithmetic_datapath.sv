`timescale 1ns / 1ps
module arithmetic_datapath #(
    parameter DATA_WIDTH = 32,
    parameter logic [DATA_WIDTH-1:0] A = 2,
    parameter logic [DATA_WIDTH-1:0] B = 3,
    parameter logic [DATA_WIDTH-1:0] C = 4
)(
    input  logic                    clk,
    input  logic                    reset,

    input  logic [DATA_WIDTH-1:0]   in_data,
    input  logic                    in_valid,
    output logic                    in_ready,

    output logic [2*DATA_WIDTH+1:0] out_data,
    output logic                    out_valid,
    input  logic                    out_ready
);
    logic valid0, ready0, valid1, ready1;
    logic [DATA_WIDTH:0] data_reg0;
    logic [2*DATA_WIDTH:0] data_reg1;
    
    assign in_ready = !valid0 || ready0;
    assign ready0   = !valid1 || ready1;
    assign ready1   = !out_valid || out_ready;
    // could use more signals for the 3rd stage but they're not strictly necessary

    always_ff @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            valid1    <= 1'b0;
            valid0    <= 1'b0;
        end
        else begin
            // stage 0
            if (in_ready && in_valid) begin 
                data_reg0 <= {1'b0, in_data} + {1'b0, A}; // make operands wider before operation
                valid0    <= 1'b1;
            end
            else if (ready0 && valid0) begin
                valid0 <= 1'b0; 
            end

            // stage 1
            if (ready0 && valid0) begin 
                data_reg1 <= {{DATA_WIDTH{1'b0}}, data_reg0} * B; // explicitly extend one operand to 2W+1 bits
                valid1    <= 1'b1;
            end
            else if (valid1 && ready1) begin
                valid1 <= 1'b0; 
            end

            // stage 2
            if (ready1 && valid1) begin 
                out_data <= {1'b0, data_reg1} + {{(DATA_WIDTH+1){1'b0}}, C}; // make operands wider before operation
                out_valid    <= 1'b1;
            end
            else if (out_valid && out_ready) begin
                out_valid <= 1'b0; 
            end
        end
    end

endmodule