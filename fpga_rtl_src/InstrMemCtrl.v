 `timescale 1ns / 1ps

module InstrMemCtrl #  
             (   parameter ADDR_WIDTH = `instr_log2_bram_depth,
                 parameter DATA_WIDTH = `instr_bram_width,
                 parameter      DEPTH = `instr_bram_depth)
             (
                input clk,
                input rst_n,
                input shift_vld, //stop one cycle after shift vld = 0 
                // input hlt,
                
                // input re,
                input [7:0] read_pointer_shift_minusone,
                output [`instr_read_width-1:0] rd_data_out,
                // //write port
                input wr_vld,     //wr_req_vld
                input [`log_instr_mem_depth-1:0] i_instr_mem_wr_addr,
                input [`instr_read_width-1:0] i_instr_mem_wr_data,

                //jump
                input jump_en,
                input [`instr_log2_bram_depth-1:0] jump_addr,
                output [ADDR_WIDTH-1:0] read_pointer_out,

                input [2:0] read_specific_addr,
                output [`instr_bram_width-1:0] read_specific_data   
            );

    reg [ADDR_WIDTH-1:0] read_pointer;
    wire [ADDR_WIDTH-1:0] next_read_pointer;
    reg [`instr_read_width-1:0] rd_data;
    reg Instr_Mem_working;
    assign read_specific_data = rd_data[8*read_specific_addr+:8];

    assign read_pointer_out = read_pointer;
    assign rd_data_out = rd_data;

    assign next_read_pointer =  (Instr_Mem_working)?
                                            ((shift_vld)? 
                                            ((jump_en)? jump_addr : (read_pointer + {2'b0, read_pointer_shift_minusone} + 'b1))
                                            : read_pointer)
                                            :'d0;
    

    //read pointer change in the cycle when shift_vld is high
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin  
            read_pointer <= 0;
        end else begin
            read_pointer <= next_read_pointer;
        end
    end

    //map virtual addr pointer to physic addr

    wire [`log_read_window_size-1:0] col_addr;  //column addr 0~10
    wire [`log_instr_mem_depth-1:0] row_addr;  //row addr 0~511
    reg [`log_read_window_size-1:0] reg_col_addr;
    wire [7:0] s_rdata [`read_window_size-1:0];
    reg [`log_instr_mem_depth-1:0] s_raddr [`read_window_size-1:0];
    reg [`log_instr_mem_depth-1:0] s_addr [`read_window_size-1:0];
    reg [7:0] s_wdata [`read_window_size-1:0];
    wire GWEN = ~wr_vld;
    assign row_addr = next_read_pointer/`read_window_size;
    assign col_addr = next_read_pointer%`read_window_size;

    always @(posedge clk) reg_col_addr <= col_addr;
    always @(posedge clk) Instr_Mem_working <= GWEN;

    integer j; 
    generate           
        always @(*) begin
            for(j=0;j<`read_window_size;j=j+1)
            begin:tp_wt 
                s_addr[j] = wr_vld? i_instr_mem_wr_addr:s_raddr[j];
                s_wdata[j] = i_instr_mem_wr_data[j*8+:8];
            end 
        end 
    endgenerate 


    always @(*) begin
            case (reg_col_addr)
                4'd0:begin rd_data = {s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0]}; end
                4'd1:begin rd_data = {s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1]}; end
                4'd2:begin rd_data = {s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2]}; end
                4'd3:begin rd_data = {s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3]}; end
                4'd4:begin rd_data = {s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4]}; end
                4'd5:begin rd_data = {s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5]}; end
                4'd6:begin rd_data = {s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6]}; end
                4'd7:begin rd_data = {s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8],s_rdata[7]}; end
                4'd8:begin rd_data = {s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9],s_rdata[8]}; end
                4'd9:begin rd_data = {s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10],s_rdata[9]}; end
                4'd10:begin rd_data = {s_rdata[9],s_rdata[8],s_rdata[7],s_rdata[6],s_rdata[5],s_rdata[4],s_rdata[3],s_rdata[2],s_rdata[1],s_rdata[0],s_rdata[10]}; end
            endcase
            case(col_addr)
                4'd0: begin
                    s_raddr[0] = row_addr;
                    s_raddr[1] = row_addr;
                    s_raddr[2] = row_addr;
                    s_raddr[3] = row_addr;
                    s_raddr[4] = row_addr;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;
                end
                4'd1: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr;
                    s_raddr[2] = row_addr;
                    s_raddr[3] = row_addr;
                    s_raddr[4] = row_addr;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;
                end           
                4'd2: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr;
                    s_raddr[3] = row_addr;
                    s_raddr[4] = row_addr;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd3: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr;
                    s_raddr[4] = row_addr;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end     
                4'd4: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd5: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd6: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr+'b1;
                    s_raddr[6] = row_addr;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd7: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr+'b1;
                    s_raddr[6] = row_addr+'b1;
                    s_raddr[7] = row_addr;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd8: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr+'b1;
                    s_raddr[6] = row_addr+'b1;
                    s_raddr[7] = row_addr+'b1;
                    s_raddr[8] = row_addr;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd9: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr+'b1;
                    s_raddr[6] = row_addr+'b1;
                    s_raddr[7] = row_addr+'b1;
                    s_raddr[8] = row_addr+'b1;
                    s_raddr[9] = row_addr;
                    s_raddr[10] = row_addr;                    
                end
                4'd10: begin
                    s_raddr[0] = row_addr+'b1;
                    s_raddr[1] = row_addr+'b1;
                    s_raddr[2] = row_addr+'b1;
                    s_raddr[3] = row_addr+'b1;
                    s_raddr[4] = row_addr+'b1;
                    s_raddr[5] = row_addr+'b1;
                    s_raddr[6] = row_addr+'b1;
                    s_raddr[7] = row_addr+'b1;
                    s_raddr[8] = row_addr+'b1;
                    s_raddr[9] = row_addr+'b1;
                    s_raddr[10] = row_addr;                    
                end
            endcase             
    end

    reg CEN; // low enable

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n) CEN <= 1'b1;
        else CEN <= 1'b0;
    end

    blk_mem blk_mem_gen_1_0 (
        .douta(s_rdata[0]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[0]), 
        .dina(s_wdata[0])
        );    
        
    blk_mem blk_mem_gen_1_1 (
        .douta(s_rdata[1]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[1]), 
        .dina(s_wdata[1])
        );    
    blk_mem blk_mem_gen_1_2 (
        .douta(s_rdata[2]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[2]), 
        .dina(s_wdata[2])
        );  
    blk_mem blk_mem_gen_1_3 (
        .douta(s_rdata[3]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[3]), 
        .dina(s_wdata[3])
        );  
    blk_mem blk_mem_gen_1_4 (
        .douta(s_rdata[4]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[4]), 
        .dina(s_wdata[4])
        );
    blk_mem blk_mem_gen_1_5 (
        .douta(s_rdata[5]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN),        
        .addra(s_addr[5]), 
        .dina(s_wdata[5])
        );
    blk_mem blk_mem_gen_1_6 (
        .douta(s_rdata[6]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[6]),      
        .dina(s_wdata[6])
        );
    blk_mem blk_mem_gen_1_7 (
        .douta(s_rdata[7]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[7]), 
        .dina(s_wdata[7])
    );
    blk_mem blk_mem_gen_1_8 (
        .douta(s_rdata[8]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[8]), 
        .dina(s_wdata[8])
        );
    blk_mem blk_mem_gen_1_9 (
        .douta(s_rdata[9]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[9]), 
        .dina(s_wdata[9])
        );
    blk_mem blk_mem_gen_1_10 (
        .douta(s_rdata[10]), 
        .clka(clk), 
        .ena(~CEN), 
        .wea(~GWEN), 
        .addra(s_addr[10]), 
        .dina(s_wdata[10])
        );        
endmodule