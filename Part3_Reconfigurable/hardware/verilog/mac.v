// Created by Da Zhou

module mac (out, a, b, c, toggle);

parameter bw = 4;
parameter psum_bw = 16;
parameter k_size = 9;

output signed [psum_bw-1:0] out;
input signed  [bw-1:0] a;  // activation
input signed  [bw-1:0] b;  // weight
input signed  [psum_bw-1:0] c; // psum
input toggle; // toggle between weight stationary and output stationary


wire signed [psum_bw-1:0] out_WS;
wire signed [psum_bw-1:0] out_OS;
wire signed [bw:0]   a_pad;

// WS
assign a_pad = {1'b0, a}; // force to be unsigned number
assign out_WS = a_pad * b + c;

// OS
assign out_OS = $signed(a) * $signed(b) + $signed(c); // force to be signed number

assign out = toggle ? out_OS : out_WS; // 0 = WS, 1 = OS

endmodule
