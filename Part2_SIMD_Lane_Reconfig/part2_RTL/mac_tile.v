// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
// Modified for Part 2: Dual Weight Loading
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, mode);
    parameter bw = 4;
    parameter psum_bw = 16;

    output [psum_bw-1:0] out_s;
    input  [bw-1:0] in_w;
    output [bw-1:0] out_e; 
    input  [1:0] inst_w; // [1]:execute, [0]:kernel loading
    output [1:0] inst_e;
    input  [psum_bw-1:0] in_n;
    input  clk;
    input  reset;
    input  mode; // New input

    reg [1:0] inst_q;
    reg [bw-1:0] a_q;
    reg [bw-1:0] b_q0; // Weight 0
    reg [bw-1:0] b_q1; // Weight 1
    reg [psum_bw-1:0] c_q;
    
    // Weight Loading Control: 0=Done, 1=Load W0, 2=Load W1 (SIMD only)
    reg [1:0] load_state; 

    wire [psum_bw-1:0] mac_out;

    assign out_e = a_q;
    assign inst_e = inst_q;
    assign out_s = mac_out;

    always @(posedge clk) begin
        if (reset) begin
            inst_q     <= 2'b00;
            a_q        <= 0;
            b_q0       <= 0;
            b_q1       <= 0;
            c_q        <= 0;
            // Reset logic: In 4-bit mode (mode=0), we need to load 1 weight.
            // In 2-bit mode (mode=1), we need to load 2 weights.
            // Let's use a counter: 0 means ready to load.
            load_state <= 2'b00; 
        end
        else begin
            // 1. Data Pass-through & Execute Latching
            if (inst_w[0] || inst_w[1])
                a_q <= in_w;
            
            inst_q[1] <= inst_w[1];
            c_q       <= in_n;

            // 2. Weight Loading Logic
            // State 0: Waiting for first weight
            if (inst_w[0] && load_state == 0) begin
                b_q0 <= in_w;
                // If mode is SIMD (1), we need another weight -> State 1
                // If mode is Normal (0), we are done -> State 2 (Done)
                // However, original design used 'load_ready_q' boolean.
                // Let's adapt:
                if (mode) begin 
                   load_state <= 1; // Need one more
                   inst_q[0]  <= 0; // Don't pass instruction yet
                end else begin
                   load_state <= 2; // Done
                   b_q1       <= in_w; // Optional: Broadcast to W1 for safety
                   inst_q[0]  <= 0; // Don't pass yet (standard logic eats one cycle?)
                   // Wait, original logic: if (load_ready) {load; ready=0;} if (!load_ready) pass inst.
                   // So the instruction is passed ONLY after this tile is full.
                end
            end
            // State 1: Waiting for second weight (SIMD only)
            else if (inst_w[0] && load_state == 1) begin
                b_q1 <= in_w;
                load_state <= 2; // Done
                inst_q[0] <= 0;
            end
            // State 2: Fully Loaded, just pass instruction
            else begin
                 inst_q[0] <= inst_w[0];
            end
        end
    end

    mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b0(b_q0),
        .b1(b_q1),
        .c(c_q),
        .mode(mode),
        .out(mac_out)
    );
endmodule