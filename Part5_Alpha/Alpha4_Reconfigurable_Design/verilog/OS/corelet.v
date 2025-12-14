module corelet #(
    parameter bw = 4,
    parameter row = 8,
    parameter col = 8,
    parameter psum_bw = 16
)(
    input wire clk,
    input wire reset,
    input wire mode,
    input wire [bw*row-1:0] activation_in,
    input wire [bw*row-1:0] weight_in,
    input wire [psum_bw*col-1:0] sfp_in,
    output wire [psum_bw*col-1:0] corelet_out,
    output wire o_ready,
    output wire o_valid,
    input wire [7:0] inst,
    input wire output_en,
    input wire simd
);

    // Internal signals
    wire [psum_bw*col-1:0] mac_array_out, corelet_out_temp;
    wire [col-1:0] mac_array_valid;
    wire l0_fifo_full, l0_fifo_ready, ififo_full, ififo_ready;
    wire [bw*row-1:0] l0_fifo_out, ififo_out;
    wire [psum_bw*col-1:0] mac_array_in_n, mac_array_in_n_temp;
    wire ofifo_full, ofifo_ready, ofifo_valid;
    wire [psum_bw*col-1:0] ofifo_out, sfp_out;
    wire ofifo_clk;

    // Extract control signals from inst
    wire ofifo_rd ;
    wire ififo_wr ;
    wire ififo_rd;
    wire l0_rd ;
    wire l0_wr ;
    wire acc ;
    
    assign ofifo_clk = !mode && clk;//if we are doing output stationary then clock gate the ofifo
    assign acc = inst[7];
    assign ofifo_rd = inst[6];
    assign ififo_wr = inst[5];
    assign ififo_rd = inst[4];
    assign l0_rd = inst[3];
    assign l0_wr = inst[2];
    assign o_ready = ofifo_ready;
    assign corelet_out_temp = mode ? mac_array_out : ofifo_out;
    assign corelet_out = (acc && !mode) ? sfp_out : corelet_out_temp;// output from sfp only if we are accumulating and if we arent o.s.
    assign mac_array_in_n = mode ? mac_array_in_n_temp : 0;//input from ififo if we are o.s.

    wire [row-1:0] x_zero_in;
    wire [col-1:0] w_zero_in;

    // L0 FIFO for act
    l0_fifo #(.bw(bw), .row(row)) l0_fifo_inst (
        .clk(clk),
        .in(activation_in),
        .out(l0_fifo_out),
        .rd(l0_rd),
        .wr(l0_wr),
        .o_full(l0_fifo_full),
        .reset(reset),
        .o_ready(l0_fifo_ready)
    );
    //IFIFO for weights
    l0_fifo #(.bw(bw), .row(col))   ififo_inst(
        .clk(clk),
        .in(weight_in),
        .out(ififo_out),
        .rd(ififo_rd),
        .wr(ififo_wr),
        .o_full(ififo_full),
        .reset(reset),
        .o_ready(ififo_ready)
    );

    // OFIFO
    ofifo #(.bw(psum_bw), .col(col)) ofifo_inst (
        .clk(ofifo_clk),
        .in(mac_array_out),
        .out(ofifo_out),
        .rd(ofifo_rd),
        .wr(mac_array_valid),
        .o_full(ofifo_full),
        .reset(reset),
        .o_ready(ofifo_ready),
        .o_valid(o_valid)
    );

    // MAC Array
    mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row)) mac_array_inst (
        .clk(clk),
        .reset(reset),
        .out_s(mac_array_out),
        .in_w(l0_fifo_out),
        .in_n(mac_array_in_n),
        .inst_w(inst[1:0]),

        .x_zero_in(x_zero_in),
        .w_zero_in(w_zero_in),
        .simd(simd),
        .valid(mac_array_valid),
        .OS(mode),
        .os_output_flg(output_en)
    );

    sfp #(.bw(psum_bw), .col(col)) sfp_row  (
        .clk(clk),
        .reset(reset),
        .in(sfp_in),
        .out(sfp_out)
    );
    genvar i;
    generate for(i=0;i<col;i=i+1) begin : weight_sign_ext//pass sign extended input into our mac_array
        assign mac_array_in_n_temp[(i+1)*psum_bw-1:i*psum_bw] = { {psum_bw-bw{ififo_out[bw*(i+1)-1]}}, ififo_out[bw*(i+1)-1:bw*i] };
    end
    endgenerate

    // generate x_zero_in and w_zero_in based on ififo and l0 fifo outputs
    generate
    for(i=0;i<row;i=i+1) begin : zero_signals
        assign x_zero_in[i] = (l0_fifo_out[bw*(i+1)-1:bw*i] == 0);
    end
    endgenerate

    generate
    for(i=0;i<col;i=i+1) begin : zero_signals_w
        assign w_zero_in[i] = simd ? (ififo_out[psum_bw*i+2*bw-1:psum_bw*i] == 0): 
                                     (ififo_out[bw*i+bw-1:bw*i] == 0);
    end
    endgenerate

    // Output
    //assign psum_out = ofifo_out;
    //assign o_ready = l0_fifo_ready;

endmodule
