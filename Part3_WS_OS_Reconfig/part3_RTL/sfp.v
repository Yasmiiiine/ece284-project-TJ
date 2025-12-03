// Contributed by Da Zhou
// Special Functional Unit module 
// Accumulation and ReLU

module sfp (out, in, acc, clk, reset);

    parameter bw = 4;
    parameter psum_bw = 16;
    parameter relu = 1;

    input clk;
    input reset;
    input signed [psum_bw - 1:0] in;
    input acc;

    output signed [psum_bw - 1:0] out;

    reg signed [psum_bw - 1:0] psum_q;

    always @(posedge clk ) begin
        if(reset)
            psum_q <= 0;
        else begin
            if(acc)
                psum_q <= psum_q + in;
            else if(relu)
                psum_q <= (psum_q > 0) ? psum_q : 0;
            else
                psum_q <= psum_q;
        end
    end

    assign out = psum_q;

endmodule