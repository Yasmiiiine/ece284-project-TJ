// use row*mac_row to build an array
module mac_array (clk, reset, 
                  in_n, out_s, 
                  in_w, 
                  inst_w, 
                  x_zero_in, // input from the west, using for activation zero propagation in WS and OS mode
                  w_zero_in, // input from the north, using for weight zero propagation in OS mode
                  simd, OS, os_output_flg, valid);
    // compare with SIMD WS mac_array, 
    //x_zero_in, w_zero_in, OS, os_output_flg ports added
    parameter bw = 4;
    parameter psum_bw = 16;
    parameter row = 8; // number of rows in an array
    parameter col = 8; // number of columns in a row

    input clk, reset, simd, OS, os_output_flg;
    output [col-1:0] valid;

    input  [col*psum_bw-1:0] in_n; // input partial sum(WS); input weight (OS)
    output [col*psum_bw-1:0] out_s;
    input  [row*bw-1:0] in_w; // input feature
    input  [1:0] inst_w;

    input  [row-1:0] x_zero_in;
    input  [col-1:0] w_zero_in;
    wire [(row+1)*col-1: 0] w_zero_tmp;
    assign w_zero_tmp[col-1: 0] = w_zero_in;

    wire [(row+1)*(psum_bw*col)-1: 0]psum_temp;
    assign psum_temp[psum_bw*col-1: 0] = in_n;
    wire [row * col - 1:0] valid_temp;
    assign valid = valid_temp[row*col-1: (row-1)*col];

    reg [2*row-1: 0] arr_inst;
    reg [row-1: 0] os_output_flg_temp;


    always @ (posedge clk) begin
        arr_inst <= {arr_inst[2*row-3: 0], inst_w};
        if(OS) begin
          os_output_flg_temp <= {row{os_output_flg}};
        end
        else begin
          os_output_flg_temp <= 0;
        end
    end

    genvar i;
    generate
        for (i=1; i < row+1 ; i=i+1) begin : row_num
            mac_row #(
                .bw(bw),
                .psum_bw(psum_bw),
                .col(col)
            ) mac_row_instance (
                .clk(clk),
                .reset(reset),
                .in_w(in_w[bw*i-1: bw*(i-1)]),
                .inst_w(arr_inst[i*2-1: i*2-2]),
                .in_n(psum_temp[i*psum_bw*col-1:(i-1)*psum_bw*col]),
                .out_s(psum_temp[(i+1)*psum_bw*col-1: i*psum_bw*col]),

                .x_zero_in(x_zero_in[i-1]),
                .w_zero_in(w_zero_tmp[i*col-1:(i-1)*col]),
                .w_zero_out(w_zero_tmp[(i+1)*col-1:i*col]),
                .simd(simd),
                .OS(OS),
                .os_output_flg(os_output_flg_temp[i-1]),
                .valid(valid_temp[col*i-1: col*(i-1)])
            );
        end
    endgenerate

    assign out_s = psum_temp[(row+1)*psum_bw*col-1: row*psum_bw*col];
endmodule

    