// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ps

module core_tb_os;

  parameter bw = 4;
  parameter psum_bw = 16;
  parameter len_kij = 9;
  parameter len_onij = 16;
  parameter col = 8;
  parameter row = 8;
  parameter len_nij = 36;
  parameter ic_dim   = 3; 
  parameter a_pad_ni_dim = 6; 
  parameter o_ni_dim     = 4; 
  parameter ki_dim       = 8;
  parameter act_tile = 2;  
  parameter o_feature_num = 8; 

  reg clk = 0;
  reg reset = 1;

  wire [33:0] inst_q; 
  reg [1:0]  inst_w_q = 0; 

  reg [bw*row-1:0] D_xmem_q = 0;
  reg CEN_xmem = 1;
  reg WEN_xmem = 1;
  reg [10:0] A_xmem = 0;

  reg CEN_xmem_q = 1;
  reg WEN_xmem_q = 1;
  reg [10:0] A_xmem_q = 0;

  reg CEN_pmem = 1;
  reg WEN_pmem = 1;
  reg [10:0] A_pmem = 0;

  reg CEN_pmem_q = 1;
  reg WEN_pmem_q = 1;
  reg [10:0] A_pmem_q = 0;

  reg ofifo_rd_q = 0;
  reg ififo_wr_q = 0;
  reg ififo_rd_q = 0;
  reg l0_rd_q = 0;
  reg l0_wr_q = 0;

  reg execute_q = 0;
  reg load_q = 0;
  reg acc_q = 0;
  reg acc = 0;

  reg [1:0]  inst_w; 
  reg [bw*row-1:0] D_xmem;
  reg [psum_bw*col-1:0] answer;


  reg ofifo_rd;
  reg ififo_wr;
  reg ififo_rd;
  reg l0_rd;
  reg l0_wr;
  reg execute;
  reg load;

  reg [8*30:1] stringvar;
  reg [8*30:1] w_file_name;
  reg [8*32:1] x_file_name;
  reg [col*psum_bw-1:0] data_out;
  reg rd_version_q;
  reg rd_version;
  reg toggle_q;
  reg toggle;

  wire ofifo_valid;
  wire [col*psum_bw-1:0] sfp_out;
  wire [4:0] l0_ofifo_valid;      //4:ofifo o_valid; 3:ofifo o_ready; 2:ofifo o_full; 1:l0 o_full; 0:l0 o_ready;
  wire [2:0] ififo_valid;         //2:ififo o_valid; 1:ififo o_ready; 0:ififo o_full;
  wire OFIFO_valid;               // High if all col_fifo is not empty, all col_fifo can be read out at same time
  wire OFIFO_ready;               // High if all col_fifo are not full
  wire OFIFO_full;                // High if any col_fifo is full
  wire IFIFO_valid;               // High if all col_fifo are not empty
  wire IFIFO_ready;               // High if all col_fifo are empty (ready for new writes)
  wire IFIFO_full;                // High if any col_fifo is full
  wire l0_full;                   // High if any row_fifo is full
  wire l0_ready;                  // High if all row_fifo are empty (ready for new writes)

integer x_file, x_scan_file ;
integer w_file, w_scan_file ; 
integer acc_file, acc_scan_file ; 
integer out_file, out_scan_file ; 
integer captured_data; 
integer t, i, j, k, kij, ic, tile;
integer error;

  assign inst_q[33] = acc_q;
  assign inst_q[32] = CEN_pmem_q;
  assign inst_q[31] = WEN_pmem_q;
  assign inst_q[30:20] = A_pmem_q;
  assign inst_q[19]   = CEN_xmem_q;
  assign inst_q[18]   = WEN_xmem_q;
  assign inst_q[17:7] = A_xmem_q;
  assign inst_q[6]   = ofifo_rd_q;
  assign inst_q[5]   = ififo_wr_q;
  assign inst_q[4]   = ififo_rd_q;
  assign inst_q[3]   = l0_rd_q;
  assign inst_q[2]   = l0_wr_q;
  assign inst_q[1]   = execute_q; 
  assign inst_q[0]   = load_q; 

  assign  OFIFO_valid = l0_ofifo_valid[4];
  assign  OFIFO_ready = l0_ofifo_valid[3];
  assign  OFIFO_full  = l0_ofifo_valid[2];
  assign  IFIFO_valid = ififo_valid[2];
  assign  IFIFO_ready = ififo_valid[1];
  assign  IFIFO_full  = ififo_valid[0];
  assign  l0_full     = l0_ofifo_valid[1];
  assign  l0_ready    = l0_ofifo_valid[0];


core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
  .l0_ofifo_valid(l0_ofifo_valid),
	.ofifo_valid(ofifo_valid),
  .D_xmem(D_xmem_q), 
  .sfp_out(sfp_out), 
	.reset(reset)),
  .rd_version(rd_version_q),
  .ififo_valid(ififo_valid),
  .toggle(toggle); 


initial begin 

  inst_w     = 0; 
  D_xmem     = 0;
  CEN_xmem   = 1;
  WEN_xmem   = 1;
  A_xmem     = 0;
  ofifo_rd   = 0;
  ififo_wr   = 0;
  ififo_rd   = 0;
  l0_rd      = 0;
  l0_wr      = 0;
  execute    = 0;
  load       = 0;
  rd_version = 1;
  toggle     = 1;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb_os);

  x_file = $fopen("activation_tile0.txt", "r");
  // Following three lines are to remove the first three comment lines of the file
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);
  x_scan_file = $fscanf(x_file,"%s", captured_data);

  //////// Reset /////////
  #0.5 clk = 1'b0;   reset = 1;
  #0.5 clk = 1'b1; 

  for (i=0; i<10 ; i=i+1) begin
    #0.5 clk = 1'b0;
    #0.5 clk = 1'b1;  
  end

  #0.5 clk = 1'b0;   reset = 0;
  #0.5 clk = 1'b1; 

  #0.5 clk = 1'b0;   
  #0.5 clk = 1'b1;   
  /////////////////////////

  w_file_name = "weight.txt";
  w_file = $fopen(w_file_name, "r");

  /////// Weight data writing to high address XMEM ///////

        A_xmem = 11'b10000000000;

        for (t = 0; t<len_kij*3; t = t+1) begin
            #0.5 clk        = 1'b0;
            w_scan_file     = $fscanf(w_file,"%32b", D_xmem);   
            WEN_xmem        = 0;
            CEN_xmem        = 0;
            if (t>0) A_xmem = A_xmem + 1;
            #0.5 clk        = 1'b1;
        end

        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 1;
        A_xmem   = 0;
        #0.5 clk = 1'b1;
        /////////////////////////////////////
        for (i = 0; i<10 ; i = i+1) begin
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
        end

        /////// Weight data writing to ififo ///////
        A_xmem = 11'b10000000000;

        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 0; // xmem read operation
        #0.5 clk = 1'b1;


        for (t = 0; t<len_kij*3; t = t+1) begin
            #0.5 clk        = 1'b0;
            ififo_wr           = 1;
            A_xmem = A_xmem + 1;
            #0.5 clk        = 1'b1;
        end

        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 1;
        A_xmem   = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        ififo_wr    = 0;
        #0.5 clk = 1'b1;

        for (i = 0; ~IFIFO_full && i < 10; i = i+1) begin
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
        end

        /////////////////////////////////////




        /////// Activation data writing to low address XMEM ///////
        x_file_name = "activation.txt";
        x_file = $fopen(x_file_name, "r");
        A_xmem = 0;

        for (t = 0; t<len_kij*3; t = t+1) begin
            #0.5 clk        = 1'b0;
            x_scan_file     = $fscanf(x_file,"%32b", D_xmem);
            WEN_xmem        = 0;
            CEN_xmem        = 0;
            if (t>0) A_xmem = A_xmem + 1;
            #0.5 clk        = 1'b1;
        end

        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 1;
        A_xmem   = 0;
        #0.5 clk = 1'b1;
        $fclose(x_file);
        /////////////////////////////////////////////////


        /////// Activation data writing to L0 ///////
        A_xmem   = 0;
        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 0; 
        #0.5 clk = 1'b1;

        for (t = 0; t<len_kij*3; t = t+1) begin
            #0.5 clk        = 1'b0;
            l0_wr           = 1;
            A_xmem = A_xmem + 1;
            #0.5 clk        = 1'b1;
        end

        #0.5 clk = 1'b0;
        WEN_xmem = 1;
        CEN_xmem = 1;
        A_xmem   = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0;
        l0_wr    = 0;
        #0.5 clk = 1'b1;

        for (i = 0; i<10 ; i = i+1) begin  
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
        end
        /////////////////////////////////////


        /////// Execution, read data from L0 and IFIFO start to array at same time ///////
        #0.5 clk = 1'b0;
        l0_rd    = 1;
        ififo_rd = 1;
        #0.5 clk = 1'b1;




        for (t = 0; t<len_kij*3+row+col; t = t+1) begin   
            
            execute  = 1;
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
        end

        #0.5 clk = 1'b0;
        l0_rd    = 0;
        ififo_rd = 0;
        execute  = 0;
        #0.5 clk = 1'b1;            
        /////////////////////////////////////



        /////////////////////////////////////////////////

        #0.5 clk = 1'b0; reset = 0;
        #0.5 clk = 1'b1;
        #0.5 clk = 1'b0; reset = 0;
        #0.5 clk = 1'b1;

    

        //////// Accumulation has been done while Execution /////////
        #0.5 clk = 1'b0;
        #0.5 clk = 1'b1;

        out_file = $fopen("out.txt", "r");   // need to modify file path

        error = 0;

        $display("############ Verification Start during accumulation #############");
        for (i = 0; i<2; i = i+1) begin

            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;

            ofifo_rd = 1;
        end

        for (i = 0; i<o_feature_num; i = i+1) begin

            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;

            ofifo_rd = 1;
        
            data_out     = sfp_out;
            out_scan_file = $fscanf(out_file,"%128b", answer);
            if (data_out == answer)
                $display("%2d-th output featuremap Data matched! :D", i);

            else begin
                $display("%2d-th output featuremap Data ERROR!!", i);
                $display("output: %128b", data_out);
                $display("answer: %128b", answer);
                error = 1;
            end
            
        end

        ofifo_rd = 0;



        if (error == 0) begin
            $display("############ No error detected ##############");
            $display("########### Project Completed !! ############");

        end

        $fclose(acc_file);
        //////////////////////////////////

        for (t = 0; t<10; t = t+1) begin
            #0.5 clk = 1'b0;
            #0.5 clk = 1'b1;
        end

        #10 $finish;

    end 

    always @ (posedge clk) begin
        inst_w_q     <= inst_w;
        D_xmem_q     <= D_xmem;
        CEN_xmem_q   <= CEN_xmem;
        WEN_xmem_q   <= WEN_xmem;
        A_pmem_q     <= A_pmem;
        CEN_pmem_q   <= CEN_pmem;
        WEN_pmem_q   <= WEN_pmem;
        A_xmem_q     <= A_xmem;
        ofifo_rd_q   <= ofifo_rd;
        acc_q        <= acc;
        ififo_wr_q   <= ififo_wr;
        ififo_rd_q   <= ififo_rd;
        l0_rd_q      <= l0_rd;
        l0_wr_q      <= l0_wr;
        execute_q    <= execute;
        load_q       <= load;
        rd_version_q <= rd_version;
    end


endmodule




