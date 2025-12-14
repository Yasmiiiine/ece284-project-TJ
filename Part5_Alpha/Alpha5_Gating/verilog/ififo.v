module ififo #(
    parameter bw = 4,
    parameter row = 8
)(
    input wire clk,
    input wire reset,
    input wire [bw*row-1:0] in,
    output wire [bw*row-1:0] out,
    input wire wr,
    input wire rd,
    output wire o_ready,
    output wire o_full
);

    reg [bw*row-1:0] fifo_mem [0:15]; // FIFO buffer
    reg [3:0] rd_ptr = 0;
    reg [3:0] wr_ptr = 0;

    assign out = fifo_mem[rd_ptr];
    assign o_ready = (wr_ptr != rd_ptr);
    assign o_full = ((wr_ptr + 1) % 16) == rd_ptr;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_ptr <= 0;
            wr_ptr <= 0;
        end else begin
            if (wr && !o_full) fifo_mem[wr_ptr] <= in;
            if (rd && !o_ready) rd_ptr <= rd_ptr + 1;
            if (wr && !o_full) wr_ptr <= wr_ptr + 1;
        end
    end

endmodule
