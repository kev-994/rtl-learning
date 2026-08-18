module counter(
    input reset,
    input clk,
    output logic [3:0] count
);  

    always_ff @(posedge clk) begin
        if (reset) count <= 0;
        else count <= count + 1;
    end
endmodule
