// organize tile_alpha to a row
module mac_row (clk, reset, 
                in_n, out_s, 
                in_w, 
                inst_w, 
                x_zero_in, 
                w_zero_in, w_zero_out,
                simd, OS, os_output_flg, valid);
    parameter bw = 4;
    parameter psum_bw = 16;
    parameter col = 8; // number of columns in a row

    input clk, reset, simd, OS, os_output_flg;

    input  [col*psum_bw-1:0] in_n; // input partial sum(WS); input weight (OS)
    output [col*psum_bw-1:0] out_s;
    input  [bw-1:0] in_w; // input feature
    input  [1:0] inst_w;
    output [col-1:0] valid;

    input  x_zero_in;
    input  [col-1:0] w_zero_in;
    output [col-1:0] w_zero_out;

    wire  [(col+1)*bw-1:0] temp;
    wire  [(col+1)*2-1: 0] inst_temp;
    assign temp[bw-1:0]   = in_w;
    assign inst_temp[1: 0] = inst_w;

    wire [col: 0] x_zero_tmp;
    assign x_zero_tmp[0] = x_zero_in;

    wire [col-1:0] valid_temp1;
    wire [col-1:0] valid_temp2;
    assign valid = OS ? valid_temp2 : valid_temp1;

    genvar i;
    generate
        for (i = 0; i < col; i = i + 1) begin : mac_tiles
            mac_tile #(
                .bw(bw),
                .psum_bw(psum_bw)
            ) mac_tile_inst (
                .clk(clk),
                .out_s(out_s[(i+1)*psum_bw-1:i*psum_bw]),
                .in_w(temp[(i+1)*bw-1:i*bw]),
                .out_e(temp[(i+2)*bw-1:(i+1)*bw]),
                .in_n(in_n[(i+1)*psum_bw-1:i*psum_bw]),
                .inst_w(inst_temp[2*(i+1)-1:2*i]),
                .inst_e(inst_temp[2*(i+2)-1: 2*(i+1)]),

                .x_zero_in(x_zero_tmp[i]),
                .x_zero_out(x_zero_tmp[i+1]),
                .w_zero_in(w_zero_in[i]),
                .w_zero_out(w_zero_out[i]),
                .reset(reset),
                .simd(simd),
                .OS(OS),
                .os_output_flg(os_output_flg)
            );

            assign valid_temp2[i] = os_output_flg; // when os_output_flg is high, output is valid
            assign valid_temp1[i] = inst_temp[2*(i+2)-1];
        end
    endgenerate
endmodule