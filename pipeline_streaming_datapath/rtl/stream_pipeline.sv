`timescale 1ns/1ps
module stream_pipeline #(
    parameter DATA_WIDTH = 32
)
(
    input  logic                  clk,
    input  logic                  reset,

    input  logic [DATA_WIDTH-1:0] in_data,
    input  logic                  in_valid,
    output logic                  in_ready,

    output logic [DATA_WIDTH-1:0] out_data,
    output logic                  out_valid,
    input  logic                  out_ready
);
    

    assign in_ready = !out_valid || out_ready; 
    
    always_ff @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0; // empty buffer
            out_data  <= 0;   // not necessary, but deterministic
        end
        else if (in_ready && in_valid) begin // transaction enters
            out_data  <= in_data;
            out_valid <= 1'b1;
        end
        else if (out_ready && out_valid) begin // transaction leaves
            out_valid <= 1'b0;
        end

    end


endmodule

