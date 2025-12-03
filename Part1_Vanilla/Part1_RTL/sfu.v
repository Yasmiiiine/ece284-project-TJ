// Contributed by Da Zhou
// Special Functional Unit module 
// Accumulation and ReLU

module sfu (out, in, acc, relu, clk, reset);

    parameter bw = 4;
    parameter psum_bw = 16;

    input clk;
    input reset;
    input signed [psum_bw - 1:0] in;
    input acc;
    input relu;
    output signed [psum_bw - 1:0] out;

    reg signed [psum_bw - 1:0] psum_q;

    always @(posedge clk) begin
        if(reset)
            psum_q <= 0;
        else begin
            if(acc)
                psum_q <= psum_q + in;
            else if(relu)
                // psum_q <= (psum_q > 0) ? psum_q : 0;
                psum_q <= psum_q[psum_bw-1] ? 0 : psum_q;
            else
                psum_q <= psum_q;
        end
    end

    assign out = psum_q;

endmodule