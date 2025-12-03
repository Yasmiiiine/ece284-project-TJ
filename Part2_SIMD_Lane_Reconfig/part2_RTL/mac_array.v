// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, mode);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  input mode;
  output [psum_bw*col-1:0] out_s;
  input  [row*bw-1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  [psum_bw*col-1:0] in_n;
  output [col-1:0] valid;

  // vertical only need valid in_n temp
  wire [row * col - 1:0] valid_temp;
  wire [(row + 1) * col * psum_bw - 1:0] in_n_temp;
  reg [2 * row - 1:0] inst_temp;

  assign valid = valid_temp[row * col - 1:(row - 1) * col];
  assign in_n_temp[col * psum_bw - 1:0]  = in_n;

  assign out_s = in_n_temp[(row + 1) * col * psum_bw - 1:row * col * psum_bw];

  genvar i;
  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw), .col(col)) mac_row_instance (
      .clk(clk),
      .reset(reset),
      .mode(mode),
      .valid(valid_temp[col * i - 1:col * (i - 1)]),
      .in_w(in_w[bw * i - 1:bw * (i - 1)]),
      .inst_w(inst_temp[2 * i - 1:2 * (i - 1)]),
      .in_n(in_n_temp[col * psum_bw * i - 1:col * psum_bw * (i - 1)]),
      .out_s(in_n_temp[col * psum_bw * (i + 1) - 1:col * psum_bw * i])
      );
  end

  always @ (posedge clk) begin // row inst_temp
    inst_temp[1:0] <= inst_w;
    inst_temp[3:2] <= inst_temp[1:0];
    inst_temp[5:4] <= inst_temp[3:2];
    inst_temp[7:6] <= inst_temp[5:4];
    inst_temp[9:8] <= inst_temp[7:6];
    inst_temp[11:10] <= inst_temp[9:8];
    inst_temp[13:12] <= inst_temp[11:10];  
    inst_temp[15:14] <= inst_temp[13:12];
   // inst_w flows to row0 to row7
 
  end



endmodule
