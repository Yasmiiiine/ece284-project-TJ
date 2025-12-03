// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
// Modified by handsome Owen X
// Modified for Part 2: SIMD & Reconfigurable MAC
module mac (out, a, b0, b1, c, mode);
    parameter bw = 4;
    parameter psum_bw = 16;

    output signed [psum_bw-1:0] out;
    input signed [bw-1:0] a;      // Activation
    input signed [bw-1:0] b0;     // Weight 0
    input signed [bw-1:0] b1;     // Weight 1 (Used in SIMD mode)
    input signed [psum_bw-1:0] c; // Partial Sum In
    input mode;                   // 0: 4-bit mode, 1: 2-bit SIMD mode

    // 内部乘法器操作数
    wire signed [1:0] mult1_op_a;
    wire signed [bw-1:0] mult1_op_b;
    wire signed [1:0] mult2_op_a;
    wire signed [bw-1:0] mult2_op_b;

    // 乘法结果
    wire signed [bw+1:0] product1; // 2-bit * 4-bit = 6-bit (max)
    wire signed [bw+1:0] product2;

    // 最终计算结果
    wire signed [psum_bw-1:0] psum_simd;
    wire signed [psum_bw-1:0] psum_4b;

    // ---------------------------------------------------------
    // 乘法器资源复用逻辑
    // ---------------------------------------------------------
    
    // Multiplier 1: 总是计算 A[1:0] * W0
    assign mult1_op_a = a[1:0];
    assign mult1_op_b = b0;
    assign product1 = mult1_op_a * mult1_op_b;

    // Multiplier 2: 
    //   4-bit 模式: 计算 A[3:2] * W0 (高位部分)
    //   2-bit 模式: 计算 A[1:0] * W1 (第二个通道)
    assign mult2_op_a = (mode) ? a[1:0] : a[3:2];
    assign mult2_op_b = (mode) ? b1     : b0;
    assign product2 = mult2_op_a * mult2_op_b;

    // ---------------------------------------------------------
    // 结果合并与累加
    // ---------------------------------------------------------

    // 4-bit Mode: Result = (High_part << 2) + Low_part + C
    // 注意：shift 需要正确处理符号扩展，但这里我们简化处理，通常 MAC 内部是加法树
    wire signed [2*bw-1:0] product_4b;
    assign product_4b = (product2 << 2) + product1; 
    assign psum_4b = product_4b + c;

    // 2-bit SIMD Mode: 
    //   Low Lane (psum[7:0]): product1 + c[7:0]
    //   High Lane (psum[15:8]): product2 + c[15:8]
    wire signed [7:0] psum_simd_lo;
    wire signed [7:0] psum_simd_hi;
    
    // 分别累加，注意防止溢出（这里假设位宽足够）
    assign psum_simd_lo = product1 + c[7:0];
    assign psum_simd_hi = product2 + c[15:8];
    assign psum_simd = {psum_simd_hi, psum_simd_lo};

    // 最终输出选择
    assign out = (mode) ? psum_simd : psum_4b;

endmodule
