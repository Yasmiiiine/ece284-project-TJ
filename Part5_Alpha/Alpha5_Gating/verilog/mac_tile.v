// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
// Modified for Part 2: Dual Weight Loading
module mac_tile (clk, reset, 
                 in_n, out_s, 
                 in_w, out_e, 
                 inst_w, inst_e, 
                 x_zero_in, x_zero_out,
                 w_zero_in, w_zero_out,
                 simd, OS, os_output_flg);
    parameter bw = 4;
    parameter psum_bw = 16;

    output [psum_bw-1:0] out_s;
    input  [bw-1:0] in_w; // input feature
    output [bw-1:0] out_e; 
    input  [1:0] inst_w; // [1]:execute, [0]:kernel loading
    output [1:0] inst_e;
    input  [psum_bw-1:0] in_n; // input partial sum(WS); input weight (OS)
    input  clk;
    input  reset;
    input  simd, OS; // control signals

    input os_output_flg; // get output passed to ofifo sequentially, externally controlled

    input x_zero_in, w_zero_in;
    output x_zero_out, w_zero_out;

    reg [1:0] inst_q;
    reg [bw-1:0] a_q;
    reg [bw-1:0] b_q0; // Weight 0
    reg [bw-1:0] b_q1; // Weight 1
    reg x_zero_q, w_zero_q; // registered zero indicator passed to next tile
    reg [psum_bw-1:0] c_q;
    
    // Weight Loading Control: 0=Done, 1=Load W0, 2=Load W1 (SIMD only)
    reg [1:0] load_state; 

    // input preprocessing
    wire [bw-1: 0] activation;
    wire [bw-1: 0] weight0, weight1;
    assign activation = in_w;
    assign weight0 = OS ? in_n[bw-1:0] : in_w;
    assign weight1 = OS ? in_n[2*bw-1:bw] : in_w;

    wire [psum_bw-1:0] mac_out;

    // output assignments
    assign out_e = a_q;
    assign inst_e = inst_q;
    // OS mode pass weight or output value to south
    assign out_s = (OS && !os_output_flg) ? {8'b0, b_q1, b_q0} : mac_out;

    // ====== Merged Sequential Block: All registers update on posedge ======
    always @(posedge clk) begin
        if (reset) begin
            // Instruction pipeline
            inst_q <= 0;
            // Activation
            a_q <= 0;
            // Weights
            b_q0 <= 0;
            b_q1 <= 0;
            load_state <= 0;
            // Partial sum
            c_q <= 0;
            // Zero propagation
            x_zero_q <= 1'b0;
            w_zero_q <= 1'b0;
        end
        else begin
            inst_q[1] <= inst_w[1];  // Execute instruction always propagates
            

            // ===== Single case for OS-dependent behaviors =====
            case (OS)
            0: begin // WS Mode
                if (inst_w[0] || inst_w[1]) begin
                    a_q <= activation;
                end
                c_q <= in_n;
                if (inst_w[0] && load_state == 0) begin
                    inst_q[0] <= 1'b0;
                    b_q0 <= weight0;
                    if (simd) begin
                        load_state <= 1;  // Need second weight
                    end
                    else begin
                        load_state <= 2;  // Done with single weight
                    end
                end
                else if (inst_w[0] && load_state == 1) begin
                    inst_q[0] <= 1'b0;
                    b_q1 <= weight1;
                    load_state <= 2;
                end
                else begin
                    inst_q[0] <= inst_w[0];  // Forward instruction when ready
                end
            end
            1: begin // OS Mode
                if(inst_w[0] || inst_w[1]) begin
                    if(!x_zero_in)
                        a_q <= activation;
                    else begin
                        a_q <= a_q; // hold previous activation
                    end
                    if(!w_zero_in) begin
                        b_q0 <= weight0;
                        b_q1 <= weight1;
                    end
                    else begin
                        b_q0 <= b_q0; // hold previous weights
                        b_q1 <= b_q1;
                    end
                    
                end
                else if(os_output_flg) begin
                    {a_q, b_q0, b_q1} <= 0;
                    c_q <= in_n;
                end
                else begin
                    a_q <= 0;
                    b_q0 <= 0;
                    b_q1 <= 0;
                    c_q <= c_q; // hold previous psum
                end
                if(inst_q[0] || inst_q[1]) begin//
                    if(!x_zero_q && !w_zero_q) begin
                        c_q <= mac_out;
                    end else begin
                        c_q <= c_q; // hold previous psum
                    end
                end
            end
            default: begin
                b_q0 <= 0;
                b_q1 <= 0;
                load_state <= 0;
            end
            endcase

            w_zero_q <= w_zero_in;
            x_zero_q <= x_zero_in;
        end
    end

    assign x_zero_out = x_zero_q;
    assign w_zero_out = w_zero_q;

    mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b0(b_q0),
        .b1(b_q1),
        .c(c_q),
        .simd(simd),
        .out(mac_out)
    );
endmodule