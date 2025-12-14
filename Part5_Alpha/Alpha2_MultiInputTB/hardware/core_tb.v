// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/10ps

`define WEIGHT_ADDR_START 11'b10000000000
`define WEIGHT_ADDR_OFFSET 11'b00000010000


module core_tb;

parameter bw = 4;
parameter psum_bw = 16;
parameter len_kij = 9;
parameter col = 8;
parameter row = 8;
parameter ki_dim = 3; 

// =================================================================
// DYNAMIC CONFIGURATION VARIABLES
// =================================================================
integer num_layers_var; 
integer num_otiles_var; 

reg [31:0] cfg_len_nij      [0:15];
reg [31:0] cfg_len_onij     [0:15];
reg [31:0] cfg_a_pad_ni_dim [0:15];
reg [31:0] cfg_o_ni_dim     [0:15];

integer cur_len_nij;
integer cur_len_onij;
integer cur_a_pad_ni_dim;
integer cur_o_ni_dim;

integer config_file, config_scan;
integer layer_i, otile_i;
// =================================================================

reg clk = 0;
reg reset = 1;

wire [34:0] inst_q; 

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
reg relu_q = 0;
reg relu = 0;
reg mode_q = 0; 
reg mode = 0; 


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
reg [8*128:1] w_file_name;
reg [8*128:1] x_file_name;
reg [8*128:1] o_file_name;

wire ofifo_valid;
wire [col*psum_bw-1:0] sfp_out;

integer x_file, x_scan_file ; 
integer w_file, w_scan_file ; 
integer acc_file, acc_scan_file ; 
integer out_file, out_scan_file ; 
integer captured_data; 
integer t, i, j, k, kij;
integer error;

assign inst_q[34] = relu_q;
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


core  #(.bw(bw), .col(col), .row(row)) core_instance (
	.clk(clk), 
	.inst(inst_q),
	.ofifo_valid(ofifo_valid),
  .D_xmem(D_xmem_q), 
  .sfp_out(sfp_out), 
	.reset(reset),
  .mode(mode_q)); 


initial begin 

  // ============================================================
  // LOAD CONFIGURATION
  // ============================================================
  config_file = $fopen("../datafiles/config.txt", "r");
  if (config_file == 0) begin
      $display("Error: Could not open config.txt in ../datafiles/");
      $finish;
  end

  config_scan = $fscanf(config_file, "%d %d", num_layers_var, num_otiles_var);
  
  $display("------------------------------------------------");
  $display("System Config Loaded:");
  $display("Total Layers: %0d", num_layers_var);
  $display("Total Otiles: %0d", num_otiles_var);

  for (i = 0; i < num_layers_var; i = i + 1) begin
      config_scan = $fscanf(config_file, "%d %d %d %d", 
                            cfg_len_nij[i], cfg_len_onij[i], cfg_a_pad_ni_dim[i], cfg_o_ni_dim[i]);
      $display("Layer %0d Config: InLen=%0d, OutLen=%0d", i, cfg_len_nij[i], cfg_len_onij[i]);
  end
  $fclose(config_file);
  $display("------------------------------------------------");

  inst_w   = 0; 
  D_xmem   = 0;
  CEN_xmem = 1;
  WEN_xmem = 1;
  A_xmem   = 0;
  ofifo_rd = 0;
  ififo_wr = 0;
  ififo_rd = 0;
  l0_rd    = 0;
  l0_wr    = 0;
  execute  = 0;
  load     = 0;

  $dumpfile("core_tb.vcd");
  $dumpvars(0,core_tb);

  // ************************************************************
  // 2-BIT DATA TEST
  // ************************************************************
  $display("\n#################################");
  $display("###      2_bit data test      ###");
  $display("#################################");
  mode = 1;

  for (layer_i = 0; layer_i < num_layers_var; layer_i = layer_i + 1) begin
    
    cur_len_nij      = cfg_len_nij[layer_i];
    cur_len_onij     = cfg_len_onij[layer_i];
    cur_a_pad_ni_dim = cfg_a_pad_ni_dim[layer_i];
    cur_o_ni_dim     = cfg_o_ni_dim[layer_i];

    $display("\n>> Processing Layer %0d", layer_i);

    // [MODIFIED] Activation File Naming Logic
    if (num_layers_var == 1 && num_otiles_var == 1)
        x_file_name = "../datafiles/2bit/activation.txt";
    else
        $sformat(x_file_name, "../datafiles/2bit/activation_L%0d.txt", layer_i);

    x_file = $fopen(x_file_name, "r");
    if (x_file == 0) begin $display("Error opening %s", x_file_name); $finish; end

    x_scan_file = $fscanf(x_file,"%s", captured_data); 
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    // Reset Core
    #0.5 clk = 1'b0;   reset = 1; #0.5 clk = 1'b1; 
    for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
    #0.5 clk = 1'b0;   reset = 0; #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;              #0.5 clk = 1'b1;   
    
    A_xmem = 11'b00000000000;
    
    // Activation Write
    for (t=0; t < cur_len_nij; t=t+1) begin  
      #0.5 clk = 1'b0;  
      x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
      WEN_xmem = 0; CEN_xmem = 0; 
      if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;   
    end
    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0; #0.5 clk = 1'b1; 
    $fclose(x_file);


    for (otile_i = 0; otile_i < num_otiles_var; otile_i = otile_i + 1) begin
        $display("   > Processing Output Tile %0d", otile_i);
        A_pmem = 0; 

        for (kij=0; kij<9; kij=kij+1) begin 

            // [MODIFIED] Weight File Naming Logic
            if (num_layers_var == 1 && num_otiles_var == 1)
                $sformat(w_file_name, "../datafiles/2bit/weight_kij%0d.txt", kij);
            else
                $sformat(w_file_name, "../datafiles/2bit/weight_L%0d_otile%0d_kij%0d.txt", layer_i, otile_i, kij);

            w_file = $fopen(w_file_name, "r");
            if (w_file == 0) begin $display("Error opening %s", w_file_name); $finish; end

            w_scan_file = $fscanf(w_file,"%s", captured_data); 
            w_scan_file = $fscanf(w_file,"%s", captured_data);
            w_scan_file = $fscanf(w_file,"%s", captured_data);

            #0.5 clk = 1'b0; reset = 1; #0.5 clk = 1'b1; 
            for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
            #0.5 clk = 1'b0; reset = 0; #0.5 clk = 1'b1; 
            #0.5 clk = 1'b0;            #0.5 clk = 1'b1;   

            // Kernel Write
            A_xmem = `WEIGHT_ADDR_START + kij*`WEIGHT_ADDR_OFFSET;
            for (t=0; t<col*2; t=t+1) begin  
              #0.5 clk = 1'b0;  
              w_scan_file = $fscanf(w_file,"%32b", D_xmem); 
              WEN_xmem = 0; CEN_xmem = 0; 
              if (t>0) A_xmem = A_xmem + 1; 
              #0.5 clk = 1'b1;  
            end
            #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; #0.5 clk = 1'b1; 

            // Kernel to L0
            A_xmem = `WEIGHT_ADDR_START + kij*`WEIGHT_ADDR_OFFSET;
            #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; #0.5 clk = 1'b1;
            for (i=0; i<col*2-1; i=i+1) begin
              #0.5 clk = 1'b0; 
              l0_rd = 0; l0_wr = 1; WEN_xmem = 1; CEN_xmem = 0;  
              A_xmem = A_xmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; CEN_xmem = 1; l0_wr = 1; #0.5 clk = 1'b1;
            #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0; l0_wr = 0; #0.5 clk = 1'b1;

            // Load to PEs
            for (j=0; j<col*2; j=j+1) begin
              #0.5 clk = 1'b0; l0_rd = 1; load = 1; #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; load = 0; l0_rd = 0; #0.5 clk = 1'b1;  
            for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end

            // Activation to L0
            A_xmem = 11'b00000000000;
            #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 0; #0.5 clk = 1'b1;
            for (k=0; k < cur_len_nij-1; k=k+1) begin
              #0.5 clk = 1'b0; 
              l0_wr = 1; WEN_xmem = 1; CEN_xmem = 0; 
              A_xmem = A_xmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0; l0_wr = 1; #0.5 clk = 1'b1;
            #0.5 clk = 1'b0; l0_wr = 0; #0.5 clk = 1'b1;

            // Execution
            for (i=0; i < cur_len_nij; i=i+1) begin
              #0.5 clk = 1'b0; l0_rd = 1; execute = 1; #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; l0_rd = 0; execute = 0; #0.5 clk = 1'b1;

            for (i=0; i < cur_len_nij; i=i+1) begin
              #0.5 clk = 1'b0; #0.5 clk = 1'b1;
            end 

            // OFIFO READ
            #0.5 clk = 1'b0; ofifo_rd = 1; #0.5 clk = 1'b1;
            for (i=0; (i < cur_len_nij-1); i=i+1) begin
              #0.5 clk = 1'b0; ofifo_rd = 1; WEN_pmem = 0; CEN_pmem = 0; if(i>0) A_pmem = A_pmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; ofifo_rd = 0; WEN_pmem = 0; CEN_pmem = 0; A_pmem = A_pmem + 1; #0.5 clk = 1'b1; 
            #0.5 clk = 1'b0; WEN_pmem = 1; CEN_pmem = 1; A_pmem = A_pmem + 1; #0.5 clk = 1'b1;

            $fclose(w_file);
        end  // end of kij loop

        // Verification
        // [MODIFIED] Output File Naming Logic
        if (num_layers_var == 1 && num_otiles_var == 1)
            o_file_name = "../datafiles/2bit/psum.txt";
        else
            $sformat(o_file_name, "../datafiles/2bit/psum_L%0d_otile%0d.txt", layer_i, otile_i);

        out_file = $fopen(o_file_name, "r"); 
        if (out_file == 0) begin $display("Error opening %s", o_file_name); $finish; end

        out_scan_file = $fscanf(out_file,"%s", answer); 
        out_scan_file = $fscanf(out_file,"%s", answer); 
        out_scan_file = $fscanf(out_file,"%s", answer); 

        error = 0;

        for (i=0; i < cur_len_onij+1; i=i+1) begin 

          #0.5 clk = 1'b0; #0.5 clk = 1'b1; 

          if (i>0) begin
             out_scan_file = $fscanf(out_file,"%128b", answer); 
             if (sfp_out == answer)
               $display("    Match at %0d", i); 
             else begin
               $display("    ERROR at %0d: sfp_out=%h != answer=%h", i, sfp_out, answer); 
               error = 1;
             end
          end
         
          #0.5 clk = 1'b0; reset = 1; #0.5 clk = 1'b1;  
          #0.5 clk = 1'b0; reset = 0; #0.5 clk = 1'b1;  

          for (j=0; j<len_kij+1; j=j+1) begin 
            #0.5 clk = 1'b0;   
              if (j<len_kij) begin CEN_pmem = 0; WEN_pmem = 1;
                A_pmem = (i / cur_o_ni_dim) * cur_a_pad_ni_dim + 
                         (i % cur_o_ni_dim) + 
                         (j / ki_dim) * cur_a_pad_ni_dim + 
                         (j % ki_dim) + 
                         (j * cur_len_nij);
              end
              else  begin CEN_pmem = 1; WEN_pmem = 1; end

              if (j>0)  acc = 1;  
            #0.5 clk = 1'b1;   
          end

          #0.5 clk = 1'b0; acc = 0; relu = 1; #0.5 clk = 1'b1; 
          #0.5 clk = 1'b0; relu = 0; #0.5 clk = 1'b1;
        end

        if (error == 0) 
            $display("    L%0d Otile%0d: SUCCESS", layer_i, otile_i); 
        else 
            $display("    L%0d Otile%0d: FAILED", layer_i, otile_i); 

        $fclose(out_file);
        A_pmem = 0;
    end // End otile loop
  end // End layer loop
  
  
  for (t=0; t<10; t=t+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
  CEN_xmem = 1; WEN_xmem = 1; A_xmem = 0;
  CEN_pmem = 1; WEN_pmem = 1; A_pmem = 0;
  acc = 0; relu = 0;


  // ************************************************************
  // 4-BIT DATA TEST
  // ************************************************************
  $display("\n#################################");
  $display("###      4_bit data test      ###");
  $display("#################################");
  mode = 0;

  for (layer_i = 0; layer_i < num_layers_var; layer_i = layer_i + 1) begin
    
    cur_len_nij      = cfg_len_nij[layer_i];
    cur_len_onij     = cfg_len_onij[layer_i];
    cur_a_pad_ni_dim = cfg_a_pad_ni_dim[layer_i];
    cur_o_ni_dim     = cfg_o_ni_dim[layer_i];

    $display("\n>> Processing Layer %0d", layer_i);

    // [MODIFIED] Activation File Naming Logic
    if (num_layers_var == 1 && num_otiles_var == 1)
        x_file_name = "../datafiles/4bit/activation.txt";
    else
        $sformat(x_file_name, "../datafiles/4bit/activation_L%0d.txt", layer_i);

    x_file = $fopen(x_file_name, "r");
    if (x_file == 0) begin $display("Error opening %s", x_file_name); $finish; end

    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    // Reset
    #0.5 clk = 1'b0; reset = 1; #0.5 clk = 1'b1; 
    for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
    #0.5 clk = 1'b0; reset = 0; #0.5 clk = 1'b1; 
    #0.5 clk = 1'b0;            #0.5 clk = 1'b1;   
    
    A_xmem = 11'b00000000000;
    
    for (t=0; t < cur_len_nij; t=t+1) begin  
      #0.5 clk = 1'b0;  
      x_scan_file = $fscanf(x_file,"%32b", D_xmem); 
      WEN_xmem = 0; CEN_xmem = 0; 
      if (t>0) A_xmem = A_xmem + 1;
      #0.5 clk = 1'b1;   
    end
    #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; A_xmem = 0; #0.5 clk = 1'b1; 
    $fclose(x_file);


    for (otile_i = 0; otile_i < num_otiles_var; otile_i = otile_i + 1) begin
        $display("   > Processing Output Tile %0d", otile_i);
        A_pmem = 0;

        for (kij=0; kij<9; kij=kij+1) begin

            // [MODIFIED] Weight File Naming Logic
            if (num_layers_var == 1 && num_otiles_var == 1)
                $sformat(w_file_name, "../datafiles/4bit/weight_kij%0d.txt", kij);
            else
                $sformat(w_file_name, "../datafiles/4bit/weight_L%0d_otile%0d_kij%0d.txt", layer_i, otile_i, kij);

            w_file = $fopen(w_file_name, "r");
            if (w_file == 0) begin $display("Error opening %s", w_file_name); $finish; end
            
            w_scan_file = $fscanf(w_file,"%s", captured_data);
            w_scan_file = $fscanf(w_file,"%s", captured_data);
            w_scan_file = $fscanf(w_file,"%s", captured_data);

            #0.5 clk = 1'b0; reset = 1; #0.5 clk = 1'b1; 
            for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end
            #0.5 clk = 1'b0; reset = 0; #0.5 clk = 1'b1; 
            #0.5 clk = 1'b0;            #0.5 clk = 1'b1;   

            // Kernel Write
            A_xmem = `WEIGHT_ADDR_START + kij*`WEIGHT_ADDR_OFFSET;
            for (t=0; t<col; t=t+1) begin  
              #0.5 clk = 1'b0;  
              w_scan_file = $fscanf(w_file,"%32b", D_xmem); 
              WEN_xmem = 0; CEN_xmem = 0; 
              if (t>0) A_xmem = A_xmem + 1; 
              #0.5 clk = 1'b1;  
            end
            #0.5 clk = 1'b0;  WEN_xmem = 1;  CEN_xmem = 1; #0.5 clk = 1'b1; 

            // Kernel to L0
            A_xmem = `WEIGHT_ADDR_START + kij*`WEIGHT_ADDR_OFFSET;
            #0.5 clk = 1'b0; CEN_xmem = 0; WEN_xmem = 1; #0.5 clk = 1'b1;
            for (i=0; i<col-1; i=i+1) begin
              #0.5 clk = 1'b0; 
              l0_rd = 0; l0_wr = 1; WEN_xmem = 1; CEN_xmem = 0;  
              A_xmem = A_xmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; CEN_xmem = 1; l0_wr = 1; #0.5 clk = 1'b1;
            #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0; l0_wr = 0; #0.5 clk = 1'b1;

            // Load to PE
            for (j=0; j<col; j=j+1) begin
              #0.5 clk = 1'b0; l0_rd = 1; load = 1; #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; load = 0; l0_rd = 0; #0.5 clk = 1'b1;  
            for (i=0; i<10 ; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end

            // Activation to L0
            A_xmem = 11'b00000000000;
            #0.5 clk = 1'b0; WEN_xmem = 1; CEN_xmem = 0; #0.5 clk = 1'b1;
            for (k=0; k < cur_len_nij-1; k=k+1) begin
              #0.5 clk = 1'b0; 
              l0_wr = 1; WEN_xmem = 1; CEN_xmem = 0; 
              A_xmem = A_xmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; CEN_xmem = 1; A_xmem = 0; l0_wr = 1; #0.5 clk = 1'b1;
            #0.5 clk = 1'b0; l0_wr = 0; #0.5 clk = 1'b1;

            // Execution
            for (i=0; i < cur_len_nij; i=i+1) begin
              #0.5 clk = 1'b0; l0_rd = 1; execute = 1; #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; l0_rd = 0; execute = 0; #0.5 clk = 1'b1;
            for (i=0; i < cur_len_nij; i=i+1) begin #0.5 clk = 1'b0; #0.5 clk = 1'b1; end 

            // OFIFO Read
            #0.5 clk = 1'b0; ofifo_rd = 1; #0.5 clk = 1'b1;
            for (i=0; (i < cur_len_nij-1); i=i+1) begin
              #0.5 clk = 1'b0; ofifo_rd = 1; WEN_pmem = 0; CEN_pmem = 0; if(i>0) A_pmem = A_pmem + 1;
              #0.5 clk = 1'b1;
            end
            #0.5 clk = 1'b0; ofifo_rd = 0; WEN_pmem = 0; CEN_pmem = 0; A_pmem = A_pmem + 1; #0.5 clk = 1'b1; 
            #0.5 clk = 1'b0; WEN_pmem = 1; CEN_pmem = 1; A_pmem = A_pmem + 1; #0.5 clk = 1'b1;

            $fclose(w_file);
        end  // end of kij loop

        // Verification
        // [MODIFIED] Output File Naming Logic
        if (num_layers_var == 1 && num_otiles_var == 1)
            o_file_name = "../datafiles/4bit/psum.txt";
        else
            $sformat(o_file_name, "../datafiles/4bit/psum_L%0d_otile%0d.txt", layer_i, otile_i);

        out_file = $fopen(o_file_name, "r"); 
        if (out_file == 0) begin $display("Error opening %s", o_file_name); $finish; end

        out_scan_file = $fscanf(out_file,"%s", answer); 
        out_scan_file = $fscanf(out_file,"%s", answer); 
        out_scan_file = $fscanf(out_file,"%s", answer); 

        error = 0;
        
        for (i=0; i < cur_len_onij+1; i=i+1) begin 

          #0.5 clk = 1'b0; #0.5 clk = 1'b1; 

          if (i>0) begin
           out_scan_file = $fscanf(out_file,"%128b", answer); 
             if (sfp_out == answer)
               $display("    Match at %0d", i); 
             else begin
               $display("    ERROR at %0d: sfp_out=%h != answer=%h", i, sfp_out, answer); 
               error = 1;
             end
          end
         
          #0.5 clk = 1'b0; reset = 1; #0.5 clk = 1'b1;  
          #0.5 clk = 1'b0; reset = 0; #0.5 clk = 1'b1;  

          for (j=0; j<len_kij+1; j=j+1) begin 
            #0.5 clk = 1'b0;   
              if (j<len_kij) begin CEN_pmem = 0; WEN_pmem = 1;
                A_pmem = (i / cur_o_ni_dim) * cur_a_pad_ni_dim + 
                         (i % cur_o_ni_dim) + 
                         (j / ki_dim) * cur_a_pad_ni_dim + 
                         (j % ki_dim) + 
                         (j * cur_len_nij);
              end
              else  begin CEN_pmem = 1; WEN_pmem = 1; end
              if (j>0)  acc = 1;  
            #0.5 clk = 1'b1;   
          end
          #0.5 clk = 1'b0; acc = 0; relu = 1; #0.5 clk = 1'b1; 
          #0.5 clk = 1'b0; relu = 0; #0.5 clk = 1'b1;
        end

        if (error == 0) 
            $display("    L%0d Otile%0d: SUCCESS", layer_i, otile_i); 
        else 
            $display("    L%0d Otile%0d: FAILED", layer_i, otile_i); 

        $fclose(out_file);
        A_pmem = 0;

    end // end of otile loop
  end // end of layer loop
  
  $display("\n#################################");
  $display("###      ALL TESTS DONE       ###");
  $display("#################################");

  #10 $finish;

end

always @ (posedge clk) begin
   inst_w_q   <= inst_w; 
   D_xmem_q   <= D_xmem;
   CEN_xmem_q <= CEN_xmem;
   WEN_xmem_q <= WEN_xmem;
   A_pmem_q   <= A_pmem;
   CEN_pmem_q <= CEN_pmem;
   WEN_pmem_q <= WEN_pmem;
   A_xmem_q   <= A_xmem;
   ofifo_rd_q <= ofifo_rd;
   acc_q      <= acc;
   ififo_wr_q <= ififo_wr;
   ififo_rd_q <= ififo_rd;
   l0_rd_q    <= l0_rd;
   l0_wr_q    <= l0_wr ;
   execute_q  <= execute;
   load_q     <= load;
   relu_q     <= relu;
   mode_q     <= mode;
end

endmodule