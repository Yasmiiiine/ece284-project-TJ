module core #(
    parameter bw = 4,           //  act/weight Bit width
    parameter psum_bw = 16,     // PSUM Bit width
    parameter row = 8,          // Number of rows
    parameter col = 8          // Number of columns
)(
    input wire clk,
    input wire reset,
    input wire [row*bw-1:0] D_xmem,
    input wire [35:0] inst,
    input wire simd,
    output wire [col*psum_bw-1:0] sfp_out,
    output wire  ofifo_valid
);

    // SRAM connections for storing activations and weights
    wire [row*bw-1:0] xmem_out;
    wire CEN_xmem, CEN_pmem;
    wire WEN_xmem, WEN_pmem;
    wire [10:0] xmem_addr, pmem_addr;
    wire mode, acc, ififo_wr, o_valid;

    wire [row*bw-1:0] act_in,weight_in; // weight_in not used for weight stationary// dummy variable rn
    wire [col*psum_bw-1:0] corelet_out, pmem_in, pmem_out, sfp_in;

    assign mode = inst[34];//w.s. if 0 and o.s. if 1
    assign acc = inst[33];//accumulate
    assign xmem_addr = inst[17:7];
    assign pmem_addr = inst[30:20];
    assign CEN_xmem = inst[19];
    assign WEN_xmem = inst[18];
    assign CEN_pmem = inst[32];
    assign WEN_pmem = inst[31];
    assign ififo_wr = inst[5];


    //assign xmem_out = (ififo_wr && mode) ? weight_in : act_in;//if ififo is writing instead send xmem output to the ififo
    assign act_in = (~ififo_wr) ? xmem_out : 0;
    assign weight_in = (ififo_wr && mode) ? xmem_out : 0; 
    //assign corelet_in = xmem_out;
    assign pmem_in =  corelet_out;  // if accumulation sfp goes to pmem else corelet goes to pmem
    assign sfp_out = acc ? corelet_out : pmem_out;
    assign ofifo_valid = o_valid;
    assign sfp_in = (acc && !mode) ? pmem_out : 0;//sfp_in is only used when accumulating in w.s.

    // SRAM for activations and weights
    sram #(.bw(row*bw)) xmem_sram (
        .CLK(clk),
        .D(D_xmem),
        .Q(xmem_out),
        .CEN(CEN_xmem),
        .WEN(WEN_xmem),
        .A(xmem_addr)
    );

    // SRAM for outputs
    sram #(.bw(col*psum_bw)) pmem_sram (
        .CLK(clk),
        .D(pmem_in),
        .Q(pmem_out),
        .CEN(CEN_pmem),
        .WEN(WEN_pmem),
        .A(pmem_addr)
    );

    // Instantiate corelet
    corelet #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) corelet_inst (
        .clk(clk),
        .reset(reset),
        .inst({inst[33],inst[6:0]}),
        .activation_in(act_in),
        .weight_in(weight_in),
        .sfp_in(sfp_in),
        .corelet_out(corelet_out),
        .o_valid(o_valid),
        .mode(inst[34]),
        .output_en(inst[35]),
        .simd(simd)
    );




endmodule