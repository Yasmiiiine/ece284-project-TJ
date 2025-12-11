// Contributed by Da Zhou
// Corelet module 
// Includes all the other blocks l0 PE ififo ofifo sfu

module corelet (clk,
                reset,
                inst,
                l0_in,
                l0_full,
                l0_ready,
                ofifo_full,
                ofifo_ready,
                ofifo_valid,
                ofifo_out,
                data_to_sfu,
                data_out,
                ififo_w_in,
                ififo_full,
                ififo_ready,
                ififo_valid,
                mode,
                toggle);

    parameter row     = 8;   
    parameter col     = 8;  
    parameter bw      = 4;  
    parameter psum_bw = 16;  
    parameter kij_max = 9;
    parameter input_ch= 8;
    parameter cnt_max = kij_max * input_ch;


    input clk;                        
    input reset;                      
    input [33:0] inst;                
    input [row * bw - 1:0] l0_in;        
    input mode;                 
    input [psum_bw * col - 1:0] data_to_sfu;    
    input [col * bw - 1:0] ififo_w_in;       
    input toggle;              


    output l0_full;                 
    output l0_ready;                 
    output ofifo_full;             
    output ofifo_ready;             
    output ofifo_valid;               
    output [col * psum_bw - 1:0] ofifo_out;
    output [psum_bw * col - 1:0] data_out;  
    output ififo_full;              
    output ififo_ready;          
    output ififo_valid;               
  

    wire [psum_bw * col - 1:0] Array_to_ofifo_out; // Data from MAC array to OFIFO
    wire [psum_bw * col - 1:0] Array_to_ofifo_out_WS; // Data from MAC array to OFIFO in Weight Stationary mode
    wire [psum_bw * col - 1:0] Array_to_ofifo_out_OS; // Data from MAC array to OFIFO in Output Stationary mode
    wire [psum_bw * col - 1:0] sfp_out;  // Output data from SFP

    assign data_out = toggle ? ofifo_out : sfp_out;
    assign Array_to_ofifo_out = toggle ? Array_to_ofifo_out_OS : Array_to_ofifo_out_WS;

    wire [row*bw-1:0] l0_to_Array_in_w;        // Data from L0 buffer to MAC array's in_w
    wire [col-1:0] Array_to_ofifo_valid;       // Valid signal from MAC array to OFIFO
    wire [col*bw-1:0] l0_to_Array_in_n;                  // Weight Data from XMEM to ififo in_n
    wire [col*bw-1:0] ififo_to_Array_in_n;               // Weight Data from ififo to MAC array, 4bit weight
    wire [col*psum_bw-1:0] ififo_to_Array_in_n_padded;   // Weight Data from ififo to MAC array, 16bit weight
    wire [col*psum_bw-1:0] Array_in_n;                     // north input data for MAC array
    
    assign ififo_to_Array_in_n_padded = 
    {
        12'b000000000000, ififo_to_Array_in_n[31:28],
        12'b000000000000, ififo_to_Array_in_n[27:24],
        12'b000000000000, ififo_to_Array_in_n[23:20],
        12'b000000000000, ififo_to_Array_in_n[19:16],
        12'b000000000000, ififo_to_Array_in_n[15:12],
        12'b000000000000, ififo_to_Array_in_n[11:8],
        12'b000000000000, ififo_to_Array_in_n[7:4],
        12'b000000000000, ififo_to_Array_in_n[3:0]
    };
    
    assign Array_in_n = toggle ? ififo_to_Array_in_n_padded : 0;

    wire [col - 1:0] ififo_flag;                      // Valid signal from first row in Output Stationary mode

    /////////////// l0 instantiation begin ////////////////

    l0 #(.row(row), .bw(bw)) l0_instance (
        .clk(clk),
        .wr(inst[2]),            
        .rd(inst[3]),             
        .reset(reset),          
        .in(l0_in),              
        .out(l0_to_Array_in_w),      
        .o_full(l0_full),      
        .o_ready(l0_ready),    
        .rd_version(rd_version)  
    );

    ///////////////  l0 instantiation end  ////////////////


    /////////////// mac_array instantiation begin ////////////////    

    mac_array #(.bw(bw), .psum_bw(psum_bw), .col(col), .row(row), .kij_max(kij_max), .input_ch(input_ch)) mac_array_instance (
        .clk(clk),
        .reset(reset),
        .out_s(Array_to_ofifo_out_WS),       // Output partial sums to OFIFO
        .in_w(l0_to_Array_in_w),             // Input weights/activations from L0
        .inst_w(inst[1:0]),               // Instructions for MAC operation
        .in_n(Array_in_n),          // north input is weight data from ififo
        .toggle(toggle),  // 0: weight stationary; 1: output stationsary
        .os_out(Array_to_ofifo_out_OS),       // Output data for Output Stationary mode
        .flag(ififo_flag),       // Valid signal from first row in Output Stationary mode
        .valid(Array_to_ofifo_valid)        // Valid signal for output data, WS -- last row of MAC array, OS -- 
        );

    ///////////////  mac_array instantiation end  ////////////////


    /////////////// ofifo instantiation begin ////////////////    

    ofifo #(.col(col),.bw(psum_bw)) ofifo_instance (
        .clk(clk),
        .wr(Array_to_ofifo_valid),           
        .rd(inst[6]),                     
        .reset(reset),                    
        .in(Array_to_ofifo_out),             
        .out(ofifo_out),                  
        .o_full(ofifo_full),           
        .o_ready(ofifo_ready),          
        .o_valid(ofifo_valid)           
    );

    ///////////////  ofifo instantiation end  ////////////////


    /////////////// ififo instantiation begin ////////////////    

    ififo #(.col(col),.bw(bw)) ififo_instance (
        .clk(clk),
        .wr(inst[5]),                    
        .rd(inst[4]),                    
        .reset(reset),                    
        .in(ififo_in),            
        .out(ififo_to_Array_in_n),                 
        .o_full(ififo_full),            
        .o_ready(ififo_ready),          
        .flag(ififo_flag),
        .o_valid(ififo_valid)            
    );

    ///////////////  ififo instantiation end  ////////////////


    /////////////// sfp instantiation begin //////////////// 

    sfp #(.psum_bw(psum_bw),.col(col)) sfp_instance (
        .clk(clk),
        .reset(reset),
        .acc(inst[33]),                  
        .in(sfp_in),                  
        .out(sfp_out)               
    );

    ///////////////  sfu instantiation end  //////////////// 


endmodule