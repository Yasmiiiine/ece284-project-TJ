module core#(
    parameter bw = 4,
    parameter psum_bw = 16,
    parameter col = 8,
    parameter row = 8
)(
    // clock signal
    input clk,
    input reset,
    // memory interface
    input [bw*row-1:0] D_xmem,
    // instruction signal
    input [34:0] inst,
    // simd control
    input mode,     // 0: normal, 1: simd
    // fifo
    output ofifo_valid,
    // SFP
    output [col*psum_bw-1:0] sfp_out
);

/* instruction format
[34]    relu
[33]    acc
[32]    CEN_pmem
[31]    WEN_pmem
[30:20] A_pmem
[19]    CEN_xmem
[18]    WEN_xmem
[17:7]  A_xmem
[6]     ofifo_rd
[5]     ififo_wr
[4]     ififo_rd
[3]     l0_rd
[2]     l0_wr
[1]     execute
[0]     load
*/

wire [31:0] xmem_Q_w;
wire [col*psum_bw-1:0] pmem_Q_w;
wire [psum_bw*col-1:0] D_pmem_w;

wire [10:0] A_xmem = inst[17:7];
wire [10:0] A_pmem = inst[30:20];
wire WEN_xmem = inst[18];
wire WEN_pmem = inst[31];
wire CEN_xmem = inst[19];
wire CEN_pmem = inst[32];
wire l0_rd = inst[3];
wire l0_wr = inst[2];
wire ofifo_rd = inst[6];
wire acc = inst[33];
wire relu = inst[34];
wire [1:0] inst_w = inst[1:0];


// SRAM
sram_32b_w2048 xmem (
    .CLK(clk),
    .CEN(CEN_xmem),
    .WEN(WEN_xmem),
    .A(A_xmem),
    // sram input
    .D(D_xmem),
    // sram output
    .Q(xmem_Q_w)
);

sram_32b_w2048#(
    .bw(col*psum_bw)
    ) pmem (
    .CLK(clk),
    .CEN(CEN_pmem),
    .WEN(WEN_pmem),
    .A(A_pmem),
    // sram input
    .D(D_pmem_w),
    // sram output
    .Q(pmem_Q_w)
);

// corelet
corelet #(
    .bw(bw), .col(col), .row(row)
    ) corelet_instance (
    .clk(clk),
    .reset(reset),
    .inst(inst_w),
    .data_to_l0(xmem_Q_w),
    .l0_rd(l0_rd),
    .l0_wr(l0_wr),
    .l0_full(),
    .l0_ready(),
    .ofifo_rd(ofifo_rd),
    .ofifo_full(),
    .ofifo_ready(),
    .ofifo_valid(ofifo_valid),
    .ofifo_out(D_pmem_w),
    .data_to_sfu(pmem_Q_w),
    .acc(acc),
    .relu(relu),
    .data_out(sfp_out),
    .mode(mode)
);

endmodule
