// Created by Da Zhou

module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset, toggle, os_out, os_valid, ififo_in);

parameter bw = 4;
parameter psum_bw = 16;
parameter k_size = 9;
parameter input_ch = 3;

input clk;
input reset;
input [bw - 1:0] in_w;
input [1:0] inst_w; //inst[0] kernel loading inst[1] execute
input [psum_bw - 1:0] in_n;
input toggle; // 0 = WS, 1 = OS

output [bw - 1:0] out_e;
output [1:0] inst_e;
output [psum_bw - 1:0] out_s;
output ififo_in; // if previous 9 accumulation end, pull high to load new weight
output [psum_bw - 1:0] os_out; // OS out data to ofifo
output os_valid; // os valid signal


wire [psum_bw - 1:0] mac_out;
reg  [bw - 1:0] a_q;
reg  [bw - 1:0] b_q;
reg  [psum_bw - 1:0] c_q;
reg  [1:0] inst_q;
reg  load_ready_q;

reg [4:0] acc_counter;  // accumulation counter
reg ififo_in_q;
reg [psum_bw - 1:0] os_tile; //store the psum of OS tile
reg tile_valid;  // if previous 3 input channel accumulation end, pull high


assign out_e = a_q;
assign inst_e = inst_q;
assign out_s = toggle ? {{12{1'b0}}, {b_q}} : mac_out; // 0 = WS south output is psum, 1 = OS south output is weight
assign ififo_in = ififo_in_q;
assign os_out = os_tile * tile_valid;
assign os_valid = tile_valid;

always @(posedge clk) begin
    if (reset) begin
        inst_q       <= 2'b00;
        a_q          <= 0;
        b_q          <= 0;
        c_q          <= 0;
        load_ready_q <= 1'b1;
        acc_counter  <= 0;
        ififo_in_q   <= 0;
        os_tile      <= 0;
        tile_valid  <= 0;
    end

    else begin
        case(toggle)
            0: begin // WS
                if (inst_w[0] || inst_w[1])
                    a_q <= in_w;

                if (inst_w[0] && load_ready_q) begin
                    b_q <= in_w;
                    load_ready_q <= 1'b0;
                end
                if (!load_ready_q)
                        inst_q[0] <= inst_w[0];

                c_q <= in_n;
                inst_q[1] <= inst_w[1];
            end

            1: begin // OS
                inst_q[1] <= inst_w[1];
                if (inst_w[0] || inst_w[1]) begin
                    b_q <= in_n[3:0];  // weights are passed through ififo instead of L0
                    a_q <= in_w;  // same as WS
                end

                if (inst_w[1]) begin
                    if ((acc_counter != 5'b11011)) begin  // 27 <=> all 3 input channels finish 9 accumulations
                        acc_counter <= acc_counter + 1; 
                        ififo_in_q <= 0; // disable new input from ififo
                        c_q <= mac_out; // mac_out will be signed in mac module
                        tile_valid <= 0;
                    end

                    else if (acc_counter == 5'b11011) begin
                        acc_counter <= 0;
                        os_tile <= $signed(mac_out) > 0 ? mac_out : 0; // relu
                        tile_valid <= 1;
                    end
                end
            end
        endcase
    end
end

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .toggle(toggle),
        .a(a_q), 
        .b(b_q),
        .c(c_q),
	.out(mac_out)
); 

endmodule
