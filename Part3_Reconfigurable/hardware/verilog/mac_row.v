// Created by Da Zhou

module mac_row (clk, out_s, in_w, in_n, valid, inst_w, reset, toggle, os_out, ififo_in, os_valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;

  input  clk, reset;
  input  [bw - 1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw * col - 1:0] in_n;
  input  toggle;

  output [psum_bw * col - 1:0] out_s;
  output [col - 1:0] valid;
  output [col - 1:0] ififo_in;
  output [psum_bw * col - 1:0] os_out;
  output [col - 1:0] os_valid;

  // horizontal only need in_w inst_w temp
  wire  [(col + 1) * bw - 1:0] temp;
  wire  [(col + 1) * 2 - 1:0] inst_temp;  // 2-bit instruction

  assign temp[bw - 1:0]      = in_w;
  assign inst_temp[1:0]      = inst_w;

  genvar i;
  for (i = 1; i < col+1; i = i + 1) begin : col_num
      mac_tile #(.bw(bw), .psum_bw(psum_bw)) mac_tile_instance (
         .clk(clk),
         .reset(reset),
	 .in_w(temp[bw * i - 1:bw * (i - 1)]),
	 .out_e(temp[bw * (i + 1) - 1:bw * i]),
	 .inst_w(inst_temp[2 * i - 1:2 * (i - 1)]),
	 .inst_e(inst_temp[2 * (i + 1) - 1:2 * i]),
	 .in_n(in_n[psum_bw * i - 1:psum_bw * (i - 1)]),
	 .out_s(out_s[psum_bw * i - 1:psum_bw * (i - 1)]),
   .toggle(toggle),
   .ififo_in(ififo_in[i - 1]),
   .os_valid(os_valid[i - 1]),
   .os_out(os_out[psum_bw * i - 1: psum_bw * (i - 1)])
   );
    assign valid[i - 1] = inst_temp[2 * i + 1]; //inst_e[1]
  end

endmodule
