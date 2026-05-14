// `timescale 1ns / 1ps
// `include "wasm_defines.vh"
// `include "src/LEB128_uint32_decode.v"

module Decoder(
        input clk,
        input rst_n,
        input [7:0] opcode,
        input function_content_start,
        input code_content_running,
        //to stack
        output push_num_out, //0 or 1
        output [3:0] pop_num_out, //0~15
        //push_select: 0~from ALU; 1~from memory; 2~from instr;
        output reg [1:0] push_select,
        //to ALU     
        output reg [4:0] ALUControl,
        output reg length_mode,
        output reg alu_fpu_select, //0 for int, 1 for float
        //to local memory
        output local_set,
        output local_get,
        //to global memory
        output global_set,
        output global_get,
        //to call stack (control stack)
        output function_call,
        output block_instr,
        output loop_instr,
        output if_instr,
        output br_table_instr,
        output unreachable_instr,
        output end_instr,
        output return_instr,
        output operand_stack_tag_pop,
        output br_related,
        output br_if,
        output else_instr

    );

    reg push_num;
    reg [3:0] pop_num;
    
    //to control stack
    assign end_instr = code_content_running&(opcode==8'h0b);
    assign block_instr = code_content_running&(opcode==8'h02);
    assign loop_instr = code_content_running&(opcode==8'h03);
    assign if_instr = code_content_running&(opcode==8'h04);

    /*all of below needs block valid*/
    //C-Stack
    assign function_call = (code_content_running&(opcode==8'h10))|function_content_start;
    assign return_instr = code_content_running&(opcode==8'h0f);
    //global
    assign global_set = ((opcode==8'h24)&code_content_running);  
    assign global_get = (opcode==8'h23)&code_content_running;    
    // block ctrl
    assign br_table_instr = code_content_running&(opcode==8'h0e);
    assign br_related = code_content_running&((opcode==8'h0c)|(opcode==8'h0e));
    assign br_if = code_content_running&(opcode==8'h0d);
    //memory

    //local
    assign local_set = ((opcode==8'h21)|(opcode==8'h22))&code_content_running;
    assign local_get = (opcode==8'h20)&code_content_running;

    //else
    assign else_instr = code_content_running&(opcode==8'h05);
    assign unreachable_instr = ((opcode==8'h00)&code_content_running);
    //to O-Stack
    assign push_num_out = push_num;
    assign pop_num_out = pop_num;
    assign operand_stack_tag_pop = (end_instr|return_instr);
    //jump_ctrl
    /*all of above needs block valid*/
        
    always@(*) begin
        pop_num = 4'd0;
        push_num = 1'b0;
        push_select = 2'b00;
        ALUControl = 5'b00000;
        length_mode = 1'b0;
        alu_fpu_select = 1'b0;

        if (code_content_running)begin
                                case (opcode) 
                                    8'h01, 8'ha7, 8'hac:begin //nop, wrap
                                        pop_num = 4'd0;
                                        ALUControl = 5'b00000;                                     
                                        push_num = 1'b0;
                                        push_select = 2'b00;       
                                        length_mode = 1'b0;                              
                                    end
                                    8'h02, 8'h03:begin //block, loop
                                        // $display("here in loop");
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;     
                                        length_mode = 1'b0;                                  
                                    end
                                    8'h04:begin //if
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00101;     //eqz  
                                        length_mode = 1'b0;                          
                                    end                                    
                                    8'h0b:begin //end, temp for function end
                                        pop_num = 4'd0;
                                        push_num = 1'b0;    
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;         
                                        length_mode = 1'b0;                                 
                                    end    
                                    8'h0c:begin //br
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                   
                                        ALUControl = 5'b00000;  
                                        length_mode = 1'b0;                                   
                                    end        
                                    8'h0d:begin //br_if
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00101;      //eqz    
                                        length_mode = 1'b0;                              
                                    end                   
                                    8'h0e:begin //br_table
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;    
                                        length_mode = 1'b0;                                 
                                    end
                                    8'h0f:begin //return
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;   
                                        length_mode = 1'b0;                                       
                                    end
                                    8'h10:begin //call
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000;       
                                        length_mode = 1'b0;                                 
                                    end
                                    8'h1a:begin //drop
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;   
                                        length_mode = 1'b0;                                  
                                    end
                                    8'h1b:begin //select
                                        pop_num = 4'd3;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00100;       
                                        length_mode = 1'b1;                          
                                    end
                                    8'h20:begin //local.get
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b11; //local mem
                                        ALUControl = 5'b00000; //add         
                                        length_mode = 1'b0;                                
                                    end                                
                                    8'h21:begin //local.set
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add         
                                        length_mode = 1'b0;                                 
                                    end                                               
                                    8'h22:begin //local.tee
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add
                                        length_mode = 1'b0;                                         
                                    end               
                                    8'h23:begin //global.get
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b01; //global memory
                                        ALUControl = 5'b00000; //add     
                                        length_mode = 1'b0;                                 
                                    end    
                                    8'h24:begin //global.set
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add       
                                        length_mode = 1'b0;                               
                                    end                                                     
                                    8'h28, 8'h29, 8'h2a, 8'h2b, 8'h2d, 8'h2c, 8'h2e, 8'h2f, 8'h30, 8'h31, 8'h32, 8'h33, 8'h34, 8'h35:begin //i32.load or f32.load
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b01; //Memory
                                        ALUControl = 5'b00000; //add   
                                        length_mode = 1'b0;                                      
                                    end                                
                                    8'h36, 8'h37, 8'h38, 8'h39, 8'h3a, 8'h3b, 8'h3c, 8'h3d, 8'h3e:begin //i32.store or f32.store
                                        pop_num = 4'd2;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add       
                                        length_mode = 1'b0;                               
                                    end   
                                    8'h3F:begin //memory.size
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000; //add   
                                        length_mode = 1'b0;                                         
                                    end
                                    8'h40:begin //memory.grow
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000; //add   
                                        length_mode = 1'b0;                                         
                                    end                                    
                                    8'h41:begin //i32.const
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        length_mode = 1'b0; 
                                    end
                                    8'h42:begin //i64.const;
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        length_mode = 1'b1;   
                                    end         
                                    8'h43:begin //f32.const
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;
                                        length_mode = 1'b1;   
                                    end     
                                    8'h44:begin //f64.const
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        length_mode = 1'b1;   
                                    end                      
                                    8'h45:begin //i32.eqz
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00101;   
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h46:begin //i32.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;  
                                        length_mode = 1'b0;                                   
                                    end
                                    8'h47:begin //i32.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;  
                                        length_mode = 1'b0;   
                                    end   
                                    8'h48:begin //i32.lt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        length_mode = 1'b0;                                 
                                    end          
                                    8'h49:begin //i32.lt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00111;     
                                        length_mode = 1'b0;                                    
                                    end  
                                    8'h4a:begin //i32.gt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;   
                                        length_mode = 1'b0;                                   
                                    end        
                                    8'h4b:begin //i32.gt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01000; 
                                        length_mode = 1'b0;                                     
                                    end
                                    8'h4c:begin //i32.le_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        length_mode = 1'b0;                                 
                                    end
                                    8'h4d:begin //i32.le_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;        
                                        length_mode = 1'b0;                               
                                    end
                                    8'h4e:begin //i32.ge_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01110;       
                                        length_mode = 1'b0;                               
                                    end
                                    8'h4f:begin //i32.ge_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;      
                                        length_mode = 1'b0;                                  
                                    end    
                                    8'h50:begin //i64.eqz
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00101;    
                                        length_mode = 1'b1;          
                                    end
                                    8'h51:begin //i64.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;    
                                        length_mode = 1'b1;                           
                                    end
                                    8'h52:begin //i64.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;  
                                        length_mode = 1'b1;   
                                    end  
                                    8'h53:begin //i64.lt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        length_mode = 1'b1;                               
                                    end    
                                    8'h54:begin //i64.lt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00111;    
                                        length_mode = 1'b1;                                
                                    end  
                                    8'h55:begin //i64.gt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;    
                                        length_mode = 1'b1;                                
                                    end        
                                    8'h56:begin //i64.gt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01000;    
                                        length_mode = 1'b1;                                  
                                    end
                                    8'h57:begin //i64.le_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        length_mode = 1'b1;                               
                                    end
                                    8'h58:begin //i64.le_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;    
                                        length_mode = 1'b1;                                  
                                    end
                                    8'h59:begin //i64.ge_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01110;    
                                        length_mode = 1'b1;                                   
                                    end
                                    8'h5a:begin //i64.ge_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        length_mode = 1'b1;  
                                        alu_fpu_select = 1'b0;                              
                                    end    
                                    8'h5b:begin //f32.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;
                                    end
                                    8'h5c:begin //f32.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                        
                                    end
                                    8'h5d:begin //f32.lt
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h5e:begin //f32.gt
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h5f:begin //f32.le
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h60:begin //f32.ge
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h61:begin //f64.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;
                                    end                        
                                    8'h62:begin //f64.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                        
                                    end
                                    8'h63:begin //f64.lt
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h64:begin //f64.gt
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h65:begin //f64.le
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h66:begin //f64.ge
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end            
                                    8'h69:begin //i32.popcnt
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11011;    
                                        length_mode = 1'b0;   
                                    end        
                                    8'h6a:begin //i32.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;  
                                        length_mode = 1'b0;  
                                    end   
                                    8'h6b:begin //i32.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00001;    
                                        length_mode = 1'b0;  
                                    end    
                                    8'h6c:begin //i32.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10101; 
                                        length_mode = 1'b0;    
                                    end
                                    8'h6d:begin //i32.div_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10110;  
                                        length_mode = 1'b0;   
                                    end
                                    8'h6e:begin //i32.div_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10111;   
                                        length_mode = 1'b0;  
                                    end
                                    8'h6f:begin //i32.rem_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11001;   
                                        length_mode = 1'b0;  
                                    end
                                    8'h70:begin //i32.rem_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11010;  
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h71:begin //i32.and
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00010;  
                                        length_mode = 1'b0;                                          
                                    end                 
                                    8'h72:begin //i32.or
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00011; 
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h73:begin //i32.xor
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11000;   
                                        length_mode = 1'b0;                                         
                                    end                                    
                                    8'h74:begin //i32.shl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10000;   
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h75:begin //i32.shr_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10001;     
                                        length_mode = 1'b0;                                       
                                    end
                                    8'h76:begin //i32.shr_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10010;     
                                        length_mode = 1'b0;                                      
                                    end
                                    8'h77:begin //i32.rotl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10011;   
                                        length_mode = 1'b0;                                       
                                    end
                                    8'h78:begin //i32.rotr
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10100;   
                                        length_mode = 1'b0;                                        
                                    end   
                                    8'h7b:begin //i64.popcnt
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11011;    
                                        length_mode = 1'b1;   
                                    end
                                    8'h7c:begin //i64.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;  
                                        length_mode = 1'b1;  
                                    end
                                    8'h7d:begin //i64.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00001;    
                                        length_mode = 1'b1;   
                                    end
                                    8'h7e:begin //i64.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10101; 
                                        length_mode = 1'b1;    
                                    end
                                    8'h7f:begin //i64.div_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10110;  
                                        length_mode = 1'b1;   
                                    end
                                    8'h80:begin //i64.div_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10111;   
                                        length_mode = 1'b1;  
                                    end
                                    8'h81:begin //i64.rem_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11001;   
                                        length_mode = 1'b1;  
                                    end
                                    8'h82:begin //i64.rem_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11010;  
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h83:begin //i64.and
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00010;  
                                        length_mode = 1'b1;                                          
                                    end
                                    8'h84:begin //i64.or
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00011; 
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h85:begin //i64.xor
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11000;   
                                        length_mode = 1'b1;                                         
                                    end
                                    8'h86:begin //i64.shl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10000;   
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h87:begin //i64.shr_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10001;     
                                        length_mode = 1'b1;                                       
                                    end
                                    8'h88:begin //i64.shr_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10010;     
                                        length_mode = 1'b1;                                      
                                    end
                                    8'h89:begin //i64.rotl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10011;   
                                        length_mode = 1'b1;                                       
                                    end
                                    8'h8a:begin //i64.rotr
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10100;   
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h8b:begin //f32.abs
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00010;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h8c:begin //f32.neg
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00011;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h8d:begin //f32.ceil
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b11000;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h8e:begin //f32.floor
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10000;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h8f:begin //f32.trunc
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10001;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h90:begin //f32.nearest
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10010;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h91:begin //f32.sqrt
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10011;    
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h92:begin //f32.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00000;  
                                        length_mode = 1'b0;  
                                        alu_fpu_select = 1'b1;  
                                    end   
                                    8'h93:begin //f32.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00001;    
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1;  
                                    end    
                                    8'h94:begin //f32.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10101; 
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'h95:begin //f32.div
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10110;  
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1;
                                    end
                                    8'h96:begin //f32.min
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10111;   
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'h97:begin //f32.max
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b11001;   
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'h98:begin //f32.copysign
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b11010;   
                                        length_mode = 1'b0;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'h99:begin //f64.abs
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00010;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9a:begin //f64.neg
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00011;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9b:begin //f64.ceil
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b11000;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9c:begin //f64.floor
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10000;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9d:begin //f64.trunc
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10001;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9e:begin //f64.nearest
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10010;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'h9f:begin //f64.sqrt
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10011;    
                                        length_mode = 1'b1; 
                                        alu_fpu_select = 1'b1;                                      
                                    end
                                    8'ha0:begin //f64.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00000;  
                                        length_mode = 1'b1;  
                                        alu_fpu_select = 1'b1;  
                                    end
                                    8'ha1:begin //f64.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b00001;    
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1;  
                                    end
                                    8'ha2:begin //f64.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00;
                                        ALUControl = 5'b10101; 
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'ha3:begin //f64.div
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10110;  
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1;
                                    end 
                                    8'ha4:begin //f64.min
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b10111;   
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'ha5:begin //f64.max
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b11001;   
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    8'ha6:begin //f64.copysign
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; 
                                        ALUControl = 5'b11010;   
                                        length_mode = 1'b1;   
                                        alu_fpu_select = 1'b1; 
                                    end
                                    // 8'hD1:begin //i32.mvm
                                    //     pop_num = 4'd3;
                                    //     push_num = 1'b0;
                                    //     push_select = 2'b00;
                                    //     ALUControl = 5'b00000;   
                                    //     length_mode = 1'b0;  
                                    // end                                          
                                    default:begin
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000;
                                        length_mode = 1'b0; 
                                        alu_fpu_select = 1'b0;
                                    end 
                                endcase                          
                            
        end else begin
            pop_num = 4'd0;
            push_num = 1'b0;
            push_select = 2'b00;
            ALUControl = 5'b00000;
            length_mode = 1'b0;
            alu_fpu_select = 1'b0;
        end
    end

    
    
endmodule
