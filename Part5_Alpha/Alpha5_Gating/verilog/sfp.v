module sfp #(
    parameter bw = 4,
    parameter col = 8
)(
    input clk,
    input reset,
    input [bw*col-1:0] in,
    output reg [bw*col-1:0] out
);

    reg [bw*col-1:0] acc; 

    genvar i;
    generate
        for (i = 0; i < col; i = i + 1) begin : relu_acc_gen
            always @(posedge clk or posedge reset) begin
                if (reset) begin
                    out[bw*(i+1)-1 : bw*i] <= 0;
                    acc[bw*(i+1)-1 : bw*i] <= 0;
                end else begin
                    acc[bw*(i+1)-1 : bw*i] <= acc[bw*(i+1)-1 : bw*i] + in[bw*(i+1)-1 : bw*i];
                    out[bw*(i+1)-1 : bw*i] <= (acc[bw*(i+1)-1] == 1'b1) ? 16'b0 : acc[bw*(i+1)-1 : bw*i];
                end
            end
        end
    endgenerate

endmodule

