// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module l0_fifo (clk, in, out, rd, wr, o_full, reset, o_ready);

  parameter row  = 8;
  parameter bw = 4;

  input  clk;
  input  wr;
  input  rd;
  input  reset;
  input  [row*bw-1:0] in;
  output [row*bw-1:0] out;
  output o_full;
  output o_ready;

  wire [row-1:0] empty;
  wire [row-1:0] full;
  reg [row-1:0] rd_en;
  wire [row-1:0] temp_full;
  wire [row*bw-1:0] temp_out;
  wire [row-1:0] temp_empty;
  integer j;
  
  genvar i;

  assign o_ready = !o_full ;
  assign o_full  = temp_full > 0 ? 1'b1 : 1'b0 ;
  assign out = temp_out;


  generate for (i=0; i<row ; i=i+1) begin : row_num
      fifo_depth16 #(.bw(bw)) fifo_instance (
	 .rd_clk(clk),
	 .wr_clk(clk),
	 .rd(rd_en[i]),
	 .wr(wr),
    .o_empty(temp_empty[i]),
    .o_full(temp_full[i]),
	 .in(in[bw*(i+1)-1 : bw*(i)]),
	 .out(temp_out[bw*(i+1)-1 : bw*(i)]),
         .reset(reset));
  end
   endgenerate

  always @ (posedge clk) begin
   if (reset) begin
      rd_en <= 8'b00000000;
   end
   else

      /////////////// version1: read all row at a time ////////////////
      /*for(j=0; j<row; j=j+1)begin
         rd_en[j] <= rd;
      end*/
      ///////////////////////////////////////////////////////



      //////////////// version2: read 1 row at a time /////////////////
      rd_en[0] <= rd;
      for(j=0; j<row-1; j=j+1)begin
         rd_en[j+1] <= rd_en[j];
      end
      ///////////////////////////////////////////////////////
    end

endmodule
