// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_array (clk, reset, out_s, in_w, in_n, inst_w, valid, toggle, os_out, ififo_in, os_valid);

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter col = 8;
  parameter row = 8;

  input  clk, reset;
  input  [row * bw - 1:0] in_w; // inst[1]:execute, inst[0]: kernel loading
  input  [1:0] inst_w;
  input  toggle;
  input  [psum_bw * col-1:0] in_n;

  output [psum_bw * col-1:0] out_s;
  output [col - 1:0] valid; // valid signal for OFIFO in WS mode
  output [psum_bw * col - 1:0] os_out;
  output [col - 1:0] ififo_in;
  output reg [col - 1:0] os_valid;

  // vertical only need valid in_n temp
  reg [2 * row - 1:0] inst_temp;
  wire [psum_bw * col * row - 1:0] os_out_temp;
  wire [row * col - 1:0] valid_temp;
  wire [(row + 1) * col * psum_bw - 1:0] in_n_temp;
  wire [row * col - 1:0] ififo_in_temp;
  wire [row * col - 1:0] os_valid_temp;

  reg [psum_bw - 1:0] os_out_col0;
  reg [psum_bw - 1:0] os_out_col1;
  reg [psum_bw - 1:0] os_out_col2;
  reg [psum_bw - 1:0] os_out_col3;
  reg [psum_bw - 1:0] os_out_col4;
  reg [psum_bw - 1:0] os_out_col5;
  reg [psum_bw - 1:0] os_out_col6;
  reg [psum_bw - 1:0] os_out_col7;

  assign os_out = {os_out_col7, os_out_col6, os_out_col5, os_out_col4, os_out_col3, os_out_col2, os_out_col1, os_out_col0};

  wire [row - 1:0] os_valid_col0;
  wire [row - 1:0] os_valid_col1;
  wire [row - 1:0] os_valid_col2;
  wire [row - 1:0] os_valid_col3;
  wire [row - 1:0] os_valid_col4;
  wire [row - 1:0] os_valid_col5;
  wire [row - 1:0] os_valid_col6;
  wire [row - 1:0] os_valid_col7;

  assign os_valid_col0 = {os_valid_temp[56], os_valid_temp[48], os_valid_temp[40], os_valid_temp[32], os_valid_temp[24], os_valid_temp[16], os_valid_temp[8], os_valid_temp[0]};
  assign os_valid_col1 = {os_valid_temp[57], os_valid_temp[49], os_valid_temp[41], os_valid_temp[33], os_valid_temp[25], os_valid_temp[17], os_valid_temp[9], os_valid_temp[1]};
  assign os_valid_col2 = {os_valid_temp[58], os_valid_temp[50], os_valid_temp[42], os_valid_temp[34], os_valid_temp[26], os_valid_temp[18], os_valid_temp[10], os_valid_temp[2]};
  assign os_valid_col3 = {os_valid_temp[59], os_valid_temp[51], os_valid_temp[43], os_valid_temp[35], os_valid_temp[27], os_valid_temp[19], os_valid_temp[11], os_valid_temp[3]};
  assign os_valid_col4 = {os_valid_temp[60], os_valid_temp[52], os_valid_temp[44], os_valid_temp[36], os_valid_temp[28], os_valid_temp[20], os_valid_temp[12], os_valid_temp[4]};
  assign os_valid_col5 = {os_valid_temp[61], os_valid_temp[53], os_valid_temp[45], os_valid_temp[37], os_valid_temp[29], os_valid_temp[21], os_valid_temp[13], os_valid_temp[5]};
  assign os_valid_col6 = {os_valid_temp[62], os_valid_temp[54], os_valid_temp[46], os_valid_temp[38], os_valid_temp[30], os_valid_temp[22], os_valid_temp[14], os_valid_temp[6]};
  assign os_valid_col7 = {os_valid_temp[63], os_valid_temp[55], os_valid_temp[47], os_valid_temp[39], os_valid_temp[31], os_valid_temp[23], os_valid_temp[15], os_valid_temp[7]};
  

  assign valid = toggle ? os_valid : valid_temp[row * col - 1: (row - 1) * col];
  assign in_n_temp[col * psum_bw - 1:0]  = in_n;
  assign out_s = in_n_temp[psum_bw * (row + 1) * col - 1:psum_bw * row * col];
  assign ififo_in = ififo_in_temp[col - 1:0]; // ififo is decided by first row

  always @(posedge clk) begin
    os_valid <= {(|os_valid_col7), (|os_valid_col6), (|os_valid_col5), (|os_valid_col4), (|os_valid_col3), (|os_valid_col2), (|os_valid_col1), (|os_valid_col0)};
    case(os_valid_col0)
      8'b00000001: os_out_col0 = os_out_temp[15:0];
      8'b00000010: os_out_col0 = os_out_temp[143:128]; // 128 = psum_bw * row(h)
      8'b00000100: os_out_col0 = os_out_temp[271:256];
      8'b00001000: os_out_col0 = os_out_temp[399:384];
      8'b00010000: os_out_col0 = os_out_temp[527:512];
      8'b00100000: os_out_col0 = os_out_temp[655:640];
      8'b01000000: os_out_col0 = os_out_temp[783:768];
      8'b10000000: os_out_col0 = os_out_temp[911:896];
    endcase

    case(os_valid_col1)
      8'b00000001: os_out_col1 = os_out_temp[31:16];
      8'b00000010: os_out_col1 = os_out_temp[159:144];
      8'b00000100: os_out_col1 = os_out_temp[287:272];
      8'b00001000: os_out_col1 = os_out_temp[415:400];
      8'b00010000: os_out_col1 = os_out_temp[543:528];
      8'b00100000: os_out_col1 = os_out_temp[671:656];
      8'b01000000: os_out_col1 = os_out_temp[799:784];
      8'b10000000: os_out_col1 = os_out_temp[927:912];
    endcase

    case(os_valid_col2)
      8'b00000001: os_out_col2 = os_out_temp[47:32];
      8'b00000010: os_out_col2 = os_out_temp[175:160];
      8'b00000100: os_out_col2 = os_out_temp[303:288];
      8'b00001000: os_out_col2 = os_out_temp[431:416];
      8'b00010000: os_out_col2 = os_out_temp[559:544];
      8'b00100000: os_out_col2 = os_out_temp[687:672];
      8'b01000000: os_out_col2 = os_out_temp[815:800];
      8'b10000000: os_out_col2 = os_out_temp[943:928];
    endcase

    case(os_valid_col3)
      8'b00000001: os_out_col3 = os_out_temp[63:48];
      8'b00000010: os_out_col3 = os_out_temp[191:176];
      8'b00000100: os_out_col3 = os_out_temp[319:304];
      8'b00001000: os_out_col3 = os_out_temp[447:432];
      8'b00010000: os_out_col3 = os_out_temp[575:560];
      8'b00100000: os_out_col3 = os_out_temp[703:688];
      8'b01000000: os_out_col3 = os_out_temp[831:816];
      8'b10000000: os_out_col3 = os_out_temp[959:944];
    endcase

    case(os_valid_col4)
      8'b00000001: os_out_col4 = os_out_temp[79:64];
      8'b00000010: os_out_col4 = os_out_temp[207:192];
      8'b00000100: os_out_col4 = os_out_temp[335:320];
      8'b00001000: os_out_col4 = os_out_temp[463:448];
      8'b00010000: os_out_col4 = os_out_temp[591:576];
      8'b00100000: os_out_col4 = os_out_temp[719:704];
      8'b01000000: os_out_col4 = os_out_temp[847:832];
      8'b10000000: os_out_col4 = os_out_temp[975:960];
    endcase

    case(os_valid_col5)
      8'b00000001: os_out_col5 = os_out_temp[95:80];
      8'b00000010: os_out_col5 = os_out_temp[223:208];
      8'b00000100: os_out_col5 = os_out_temp[351:336];
      8'b00001000: os_out_col5 = os_out_temp[479:464];
      8'b00010000: os_out_col5 = os_out_temp[607:592];
      8'b00100000: os_out_col5 = os_out_temp[735:720];
      8'b01000000: os_out_col5 = os_out_temp[863:848];
      8'b10000000: os_out_col5 = os_out_temp[991:976];
    endcase

    case(os_valid_col6)
      8'b00000001: os_out_col6 = os_out_temp[111:96];
      8'b00000010: os_out_col6 = os_out_temp[239:224];
      8'b00000100: os_out_col6 = os_out_temp[367:352];
      8'b00001000: os_out_col6 = os_out_temp[495:480];
      8'b00010000: os_out_col6 = os_out_temp[623:608];
      8'b00100000: os_out_col6 = os_out_temp[751:736];
      8'b01000000: os_out_col6 = os_out_temp[879:864];
      8'b10000000: os_out_col6 = os_out_temp[1007:992];
    endcase

    case(os_valid_col7)
      8'b00000001: os_out_col7 = os_out_temp[127:112];
      8'b00000010: os_out_col7 = os_out_temp[255:240];
      8'b00000100: os_out_col7 = os_out_temp[383:368];
      8'b00001000: os_out_col7 = os_out_temp[511:496];
      8'b00010000: os_out_col7 = os_out_temp[639:624];
      8'b00100000: os_out_col7 = os_out_temp[767:752];
      8'b01000000: os_out_col7 = os_out_temp[895:880];
      8'b10000000: os_out_col7 = os_out_temp[1023:1008];
    endcase

  end

  genvar i;
  for (i=1; i < row+1 ; i=i+1) begin : row_num
      mac_row #(.bw(bw), .psum_bw(psum_bw), .col(col)) mac_row_instance (
      .clk(clk),
      .out_s(in_n_temp[col * psum_bw * (i + 1) - 1:col * psum_bw * i]),
      .in_w(in_w[bw * i - 1:bw * (i - 1)]),
      .in_n(in_n_temp[col * psum_bw * i - 1:col * psum_bw * (i - 1)]),
      .valid(valid_temp[col * i - 1:col * (i - 1)]),
      .inst_w(inst_temp[2 * i - 1:2 * (i - 1)]),
      .reset(reset),
      .toggle(toggle),
      .ififo_in(ififo_in_temp[col * i - 1:col * (i - 1)]),
      .os_valid(os_valid_temp[col * i - 1:col * (i - 1)]),
      .os_out(os_out_temp[psum_bw * col * i - 1:psum_bw * col * (i - 1)])
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
