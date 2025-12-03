// Contributed by Da Zhou
// Corelet module 
// Includes all the other blocks l0 PE ofifo sfu

module corelet (clk, reset, inst, data_to_l0, l0_rd, l0_wr, l0_full, l0_ready, ofifo_rd, ofifo_full, ofifo_ready, ofifo_valid, ofifo_out, data_to_sfu, acc, relu, data_out);

    parameter bw = 4;
    parameter psum_bw = 16;
    parameter row = 8;
    parameter col = 8;

    input clk, reset;
    input [1:0] inst; //inst_w[1:0] kernel loading/execute
    input [bw * row - 1:0] data_to_l0; // data to l0
    input l0_rd, l0_wr;
    output l0_full, l0_ready;

    input ofifo_rd;
    // input [col - 1:0] ofifo_wr; equal to mac_valid
    output ofifo_full, ofifo_ready, ofifo_valid;
    output [psum_bw * col - 1:0] ofifo_out; // data from ofifo to sram

    input [psum_bw * col - 1:0] data_to_sfu; // data from sram to sfu
    input acc, relu;
    output [psum_bw * col - 1:0] data_out; // data from sfu

    wire [bw * row - 1:0] data_to_mac; // data from l0 to mac_array
    wire [psum_bw * col - 1:0] mac_out; // data from mac to ofifo <=> out_s
    wire [col - 1:0] mac_valid; // valid signal from mac
    wire [psum_bw * col - 1:0] mac_in; // mac input from north, decided by ififo (not l0)

    assign mac_in = {{psum_bw * col}{1'b0}}; // assign 128 bits zero


    /////////////// l0 instantiation begin ////////////////

    l0 #(.bw(bw)) l0_instance (
        .clk(clk),
        .in(data_to_l0), 
        .out(data_to_mac), 
        .rd(l0_rd),
        .wr(l0_wr), 
        .o_full(l0_full), 
        .reset(reset), 
        .o_ready(l0_ready)
    );

    ///////////////  l0 instantiation end  ////////////////


    /////////////// mac_array instantiation begin ////////////////    

    mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_instance (
        .clk(clk),
        .reset(reset),
        .in_w(data_to_mac),
        .in_n(mac_in),
        .inst_w(inst),
        .out_s(mac_out),
        .valid(mac_valid)
    );

    ///////////////  mac_array instantiation end  ////////////////


    /////////////// ofifo instantiation begin ////////////////    

    ofifo #(.col(col), .bw(psum_bw)) ofifo_instance (
        .clk(clk),
        .wr(mac_valid),
        .rd(ofifo_rd),
        .reset(reset),
        .in(mac_out),
        .out(ofifo_out),
        .o_full(ofifo_full),
        .o_ready(ofifo_ready),
        .o_valid(ofifo_valid)
    );

    ///////////////  ofifo instantiation end  ////////////////


    /////////////// sfu instantiation begin //////////////// 

    genvar i;
    generate
    for (i = 0; i < col; i = i + 1) begin : sfu_num
        sfu #(.bw(bw), .psum_bw(psum_bw)) sfu_instance (
            .clk(clk),
            .acc(acc),
            .relu(relu),
            .reset(reset),
            .in(data_to_sfu[psum_bw * (i + 1) - 1:psum_bw * i]),
            .out(data_out[psum_bw * (i + 1) - 1:psum_bw * i])
        );
    end
    endgenerate

    ///////////////  sfu instantiation end  //////////////// 


endmodule