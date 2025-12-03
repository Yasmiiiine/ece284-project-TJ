// Contributed by Da Zhou
// Special Functional Unit module 
// Accumulation and ReLU

// Modified for Part 2: SIMD Support
module sfu (out, in, acc, relu, clk, reset, mode);
    parameter bw = 4;
    parameter psum_bw = 16;

    input clk;
    input reset;
    input signed [psum_bw - 1:0] in;
    input acc;
    input relu;
    input mode; // New input
    output signed [psum_bw - 1:0] out;

    reg signed [psum_bw - 1:0] psum_q;

    // Helper wires for SIMD processing
    wire signed [7:0] in_lo = in[7:0];
    wire signed [7:0] in_hi = in[15:8];
    
    reg signed [7:0] psum_lo;
    reg signed [7:0] psum_hi;

    always @(posedge clk ) begin
        if(reset) begin
            psum_q <= 0;
        end
        else begin
            //if (mode == 0) begin
            if(1'b1) begin
                // --- 4-bit Mode (Original Logic) ---
                if(acc)
                    psum_q <= psum_q + in;
                else if(relu)
                    psum_q <= (psum_q > 0) ? psum_q : 0;
                else
                    psum_q <= psum_q;
            end
            // else begin
            //     // --- 2-bit SIMD Mode (Split Logic) ---
            //     // We assume psum_q stores {hi, lo}
                
            //     // 1. Accumulation
            //     if(acc) begin
            //         // Note: psum_q logic needs to treat halves separately
            //         // But Verilog + on 16 bits carries over from bit 7 to 8.
            //         // We must prevent carry propagation!
            //         psum_q[7:0]  <= psum_q[7:0] + in[7:0];
            //         psum_q[15:8] <= psum_q[15:8] + in[15:8];
            //     end
            //     // 2. ReLU
            //     else if(relu) begin
            //         psum_q[7:0]  <= (psum_q[7:0] > 0)  ? psum_q[7:0]  : 0;
            //         psum_q[15:8] <= (psum_q[15:8] > 0) ? psum_q[15:8] : 0;
            //     end
            // end
        end
    end

    assign out = psum_q;

endmodule