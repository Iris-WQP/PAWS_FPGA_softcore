// `timescale 1ns / 1ps
// `include "wasm_defines.vh"


module CtrlUnit(
        input clk,
        input rst_n,
        input cu_working,
        input i_exec_mode,
        input [(`log_func_num_max-1):0] i_exec_function_idx,
        //connect instr_mem_ctrl
        input [(`instr_log2_bram_depth-1):0] read_pointer,
        input [`instr_read_width-1:0] Instr,
        // input Instr_vld,
        output reg [7:0] read_pointer_shift_minusone,
        output reg INSTR_ERROR,
        output reg jump_en,
        output reg quasi_jump_en,
        output reg [(`instr_log2_bram_depth-1):0] jump_addr,
        output function_content_start,
        //to decoder
        output code_content_running,
        //to Line Memory
        output store_en,
        output load_en,
        //to global memory
        output global_init,
        output reg [31:0] vector_cnt,
        //instants
        output [63:0] constant,
        //to call stack (control stack)
        output function_retu_num,  //0 or 1 //push C-stack
        output [(`log_pa_re_num_max-1):0] function_para_num, // parameter size
        output [7:0] allocate_local_memory_size, // local memory size
        output [(`instr_log2_bram_depth-1):0] pre_calu_return_addr //push C-stack

        //debug signal
        , output [1:0] instr_pointer_state_out
        , output [7:0] section_type_out
        , output [3:0] LEB128_byte_cnt
    );

    //section head
    reg [7:0] section_type;
    assign section_type_out = section_type;
    reg [31:0] section_length;//(bytes)
    // wire code_content_running;
    wire LEB128_signed_decode;


    reg [1:0] instr_pointer_state;
    assign instr_pointer_state_out = instr_pointer_state;
    parameter   module_head = 2'b00,
                section_head = 2'b01,
                vector_head = 2'b10,
                vector_content = 2'b11;

    //byte count decode
    wire [72:0] LEB128_in;
    wire [63:0] LEB128_decode;
    // wire [2:0] LEB128_byte_cnt;
    
    //vector head
    reg [31:0] vector_num;

    // type section decode
    reg type_decode; //0~decode parameter; 1~decode return


    // function
    // wire function_content_start;
    reg [1:0] code_pre_read_state;
    reg [7:0] local_memory_sizes_list [(`func_num_max-1):0]; //local memory size list
    reg [(`log_pa_re_num_max-1):0] para_num_reg [(`func_num_max-1):0];   //parameter number of the function
    reg [(`func_num_max-1):0] retu_num_reg;   //return number of the function, 0 or 1.
    reg [(`log_func_num_max-1):0] function_num_reg ;     //function number
    wire [(`log_func_num_max-1):0] function_num_left;
    wire [7:0] type_list_addr;
    reg [7:0] function_type_list [127:0]; //function type list
    reg [(`instr_log2_bram_depth-1):0] function_addr_list [(`func_num_max-1):0]; //??????list???????????????
    reg [(`log_func_num_max-1):0] start_function_idx;
    wire function_num_flag;
    reg [5:0] local_decl_num;
    reg [5:0] local_decl_count;
    reg [3:0] function_store_addr;
    wire [(`log_func_num_max-1):0] active_function_idx;
    wire [7:0] active_function_type_addr;
    wire opcode_memarg;
    wire opcode_mem_load;
    wire opcode_mem_store;
    wire opcode_leb_imm;
    wire opcode_fixed1_imm;
    wire opcode_f32_const;
    wire opcode_f64_const;

    //function
    assign active_function_idx = i_exec_mode ? i_exec_function_idx : start_function_idx;
    assign active_function_type_addr = function_type_list[active_function_idx];
    assign allocate_local_memory_size =  function_content_start ? local_memory_sizes_list[active_function_idx] : local_memory_sizes_list[Instr[15:8]];
    assign pre_calu_return_addr = function_content_start? 'd0 : read_pointer+LEB128_byte_cnt+1'd1;
    assign function_content_start = (instr_pointer_state == vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b11)&(local_decl_count==local_decl_num)&(vector_cnt==(vector_num-1));
    assign opcode_mem_load = (Instr[7:0] >= 8'h28) && (Instr[7:0] <= 8'h35);
    assign opcode_mem_store = (Instr[7:0] >= 8'h36) && (Instr[7:0] <= 8'h3e);
    assign opcode_memarg = opcode_mem_load | opcode_mem_store;
    assign opcode_leb_imm = (Instr[7:0] == 8'h0c) || (Instr[7:0] == 8'h0d) || (Instr[7:0] == 8'h10) ||
                            (Instr[7:0] == 8'h20) || (Instr[7:0] == 8'h21) || (Instr[7:0] == 8'h22) ||
                            (Instr[7:0] == 8'h23) || (Instr[7:0] == 8'h24) || (Instr[7:0] == 8'h41) ||
                            (Instr[7:0] == 8'h42);
    assign opcode_fixed1_imm = (Instr[7:0] == 8'h02) || (Instr[7:0] == 8'h03) || (Instr[7:0] == 8'h04) ||
                               (Instr[7:0] == 8'h3f) || (Instr[7:0] == 8'h40);
    assign opcode_f32_const = (Instr[7:0] == 8'h43);
    assign opcode_f64_const = (Instr[7:0] == 8'h44);
    assign LEB128_in = (opcode_memarg & code_content_running) ? Instr[51:16] :
                       (((instr_pointer_state==vector_head)|(|code_pre_read_state)) ? Instr[35:0] : Instr[43:8]);
    assign constant = LEB128_decode;
    assign function_num_left = function_num_reg - `read_window_size*function_store_addr;
    assign function_num_flag = (function_num_left < `read_window_size);
    
    
    //to control stack
    assign type_list_addr = function_type_list[Instr[15:8]];
    assign function_retu_num = function_content_start ? (i_exec_mode ? retu_num_reg[active_function_type_addr] : 1'b0) : retu_num_reg[type_list_addr];
    assign function_para_num = function_content_start ? (i_exec_mode ? para_num_reg[active_function_type_addr] : 'b0) : para_num_reg[type_list_addr];


    assign code_content_running = (section_type==8'h0a)&(instr_pointer_state==vector_content)&(~(|code_pre_read_state));

    assign global_init = ((section_type==8'h06)&(instr_pointer_state==vector_content));
    // assign global_cnt = vector_cnt;

     //memory
    assign load_en = opcode_mem_load & code_content_running;
    assign store_en = opcode_mem_store & code_content_running;

    //jump_ctrl
    /*all of above needs block valid*/

    /*four states of code section: 
     01 ~ read length; 
     10 ~ read local decl count; 
     11 ~ read local type count;
     00 ~ normal-read;
     */

    assign LEB128_signed_decode = (code_content_running&(~(load_en|store_en)))|global_init;
    LEB128_uint_decode u_decode(
            .LEB128_in(LEB128_in),
            .uint_out(LEB128_decode),
            .byte_cnt(LEB128_byte_cnt),
            .LEB128_signed_decode(LEB128_signed_decode)
    );

    //read_pointer_shift logic          
    always@(*) begin
        case (instr_pointer_state)
            module_head: begin
                    read_pointer_shift_minusone = 8'd7;                
                    end
            section_head: begin
                    read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};                                   
            end
            vector_head: begin
                case (section_type)
                    8'h0a, 8'h01, 8'h03:begin
                    // 8'h0a, 8'h01:begin
                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} - 'd1;                       
                    end    
                    8'h06:begin
                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;                          
                    end               
                    default:begin
                        read_pointer_shift_minusone = {section_length - 32'd1};                     
                    end
                endcase
            end
            vector_content: begin
                    case (section_type)
                        8'h01:begin
                            if(type_decode) begin
                                // read_pointer_shift_minusone = Instr[(`log_read_window_size-1):0] + 'd0;
                                read_pointer_shift_minusone = Instr[7:0] + 'd0;                          
                            end
                            else begin
                                // read_pointer_shift_minusone = Instr[(`log_read_window_size+7):8]+ 'd1;
                                read_pointer_shift_minusone = Instr[15:8]+ 'd1;                          
                            end                        
                        end
                        8'h03:begin
                            read_pointer_shift_minusone = (function_num_flag? function_num_left: `read_window_size) - 1'd1;                         
                        end  
                        8'h06:begin
                            if(vector_cnt==(vector_num-1'd1))begin
                                read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;
                            end else begin
                                read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd3;
                            end
                        end                   
                        8'h0a:begin //Code section
                            if(code_pre_read_state==2'b01|code_pre_read_state==2'b10)begin
                                read_pointer_shift_minusone = LEB128_byte_cnt - 'd1;
                            end else if(code_pre_read_state==2'b11)begin
                                read_pointer_shift_minusone = LEB128_byte_cnt + LEB128_decode - 'd1;                                                                                                                            
                            end else begin
                                // Decoder-supported opcode groups:
                                // no extra immediate byte:
                                //   00 unreachable, 01 nop, 05 else, 0b end, 0f return, 1a drop, 1b select,
                                //   a7 i32.wrap_i64, ac i64.extend_i32_u,
                                //   45-7c comparisons/arithmetic/conversions
                                // fixed 1-byte immediate:
                                //   02 block, 03 loop, 04 if, 3f memory.size, 40 memory.grow
                                // LEB128 immediate:
                                //   0c br, 0d br_if, 10 call,
                                //   20 local.get, 21 local.set, 22 local.tee,
                                //   23 global.get, 24 global.set,
                                //   41 i32.const, 42 i64.const
                                // memarg immediate (alignment + offset):
                                //   28-35 loads, 36-3e stores
                                // special immediate encoding:
                                //   0e br_table, 43 f32.const(4B), 44 f64.const(8B)
                                case (Instr[7:0]) 
                                    8'h02, 8'h03, 8'h04, 8'h3F, 8'h40:begin //block, loop, if, memory.size, memory.grow                            
                                        read_pointer_shift_minusone = `log_read_window_size'd1;
                                    end                                                     
                                    8'h0e:begin //br_table                                
                                        read_pointer_shift_minusone = (LEB128_byte_cnt + LEB128_decode + 'd1);
                                    end                                                   
                                    8'h28, 8'h29, 8'h2a, 8'h2b, 8'h2d, 8'h2c, 8'h2e, 8'h2f, 8'h30, 8'h31, 8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38, 8'h39, 8'h3a, 8'h3b, 8'h3c, 8'h3d, 8'h3e:begin //i32/i64/f32/f64 load/store memarg
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;                                         
                                    end   
                                    8'h0c, 8'h0d, 8'h10, 8'h20, 8'h21, 8'h22, 8'h23, 8'h24, 8'h41, 8'h42:begin // br/br_if/call/local/global/i32.const/i64.const
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                    end
                                    8'h43:begin // f32.const
                                        read_pointer_shift_minusone = `log_read_window_size'd4;
                                    end
                                    8'h44:begin // f64.const
                                        read_pointer_shift_minusone = `log_read_window_size'd8;
                                    end
                                    default:begin //nop, end
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                    end                           
                                endcase
                            end
                        end
                        default:begin
                            read_pointer_shift_minusone = `log_read_window_size'b0;
                        end
                    endcase
            end
        endcase
    end

    always@(*)begin
        if((instr_pointer_state==vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b11)&(local_decl_count==local_decl_num))
        begin
            jump_en = 1'b1;
            quasi_jump_en = 1'b0;
            if(vector_cnt==(vector_num-1))begin
                if (active_function_idx == vector_cnt) begin
                    jump_addr = read_pointer;
                end else begin
                    jump_addr = function_addr_list[active_function_idx];
                end
            end else begin
                jump_addr = function_addr_list[vector_cnt + 1'b1];
            end    
        end else if((instr_pointer_state==vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b00))
        begin
            if (Instr[7:0] == 8'h10) begin
                quasi_jump_en = 1'b1;
                jump_en = 1'b0;
                jump_addr = function_addr_list[Instr[15:8]];
            end else begin
                jump_en = 1'b0;
                quasi_jump_en = 1'b0;
                jump_addr = 'd0;
            end
        end else begin
            jump_en = 1'b0;    
            quasi_jump_en = 1'b0;
            jump_addr = 'd0;
        end
    end


    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            instr_pointer_state <= module_head;
            INSTR_ERROR <= 1'd0;
            section_length <= 32'd0;
            section_type <= 8'd0;
            type_decode <= 1'b0;
            vector_cnt <= 'd0;
            vector_num <= 'd0;
            function_store_addr <= 4'd0;
            function_num_reg <= 'd0;
            code_pre_read_state <= 2'd0;
            // jump_en <= 1'b0;
            // jump_addr <= 'd0;
            start_function_idx <= 8'd0;
            // jump_hlt <= 1'b0;
            local_decl_count <= 6'd0;
            local_decl_num <= 6'd0;            
            // un_hlt <= 1'b0;
            retu_num_reg <= 'd0;
        end else if (cu_working) begin
            case(instr_pointer_state)
                module_head: begin
                    if(Instr[63:0] == `WASM_MAGIC_VERSION) instr_pointer_state <= section_head;
                    else INSTR_ERROR <= 'd1;
                end
                section_head: begin
                    section_type <= Instr[7:0];
                    section_length <= LEB128_decode;
                    instr_pointer_state <= vector_head;
                end
                vector_head: begin
                    vector_num <= LEB128_decode;
                    if(section_type==8'h01|section_type==8'h06)begin 
                        instr_pointer_state <= vector_content;
                    end else if (section_type==8'h03) begin 
                        instr_pointer_state <= vector_content;
                        function_num_reg <= Instr[7:0];
                    end else if (section_type==8'h08) begin
                        start_function_idx <= Instr[7:0];
                        instr_pointer_state <= section_head;                        
                    end else if (section_type==8'h0a) begin
                        instr_pointer_state <= vector_content;
                        code_pre_read_state <= 2'b01;
                    end else begin
                        instr_pointer_state <= section_head;
                    end
                end
                vector_content: begin
                    case (section_type)
                        8'h0a:begin //; section "Code" (10)
                            if(code_pre_read_state==2'b01)begin
                                function_addr_list[vector_cnt + 1'b1] <= read_pointer + LEB128_byte_cnt + LEB128_decode;
                                code_pre_read_state <= 2'b10;
                                local_memory_sizes_list[vector_cnt] <= 'd0;
                                // jump_en <= 1'b0;
                            end else if(code_pre_read_state==2'b10)begin
                                local_decl_num <= Instr[5:0];
                                code_pre_read_state <= 2'b11;
                            end else if(code_pre_read_state==2'b11)begin
                                if(local_decl_count==local_decl_num)begin
                                    function_addr_list[vector_cnt] <= read_pointer;
                                    // jump_en <= 1'b1;      
                                    local_decl_count <= 6'd0;                                  
                                    if(vector_cnt==(vector_num-1))begin
                                        vector_cnt <= 'd0;
                                        code_pre_read_state <= 2'b00;
                                    end else begin
                                        vector_cnt <= vector_cnt + 1'b1;
                                        code_pre_read_state <= 2'b01;
                                    end
                                end else begin
                                    local_decl_count <= local_decl_count + 1'b1;
                                    local_memory_sizes_list[vector_cnt] <= local_memory_sizes_list[vector_cnt]+LEB128_decode;
                                end
                            end
                        end
                        8'h01:begin //; section "Type" (1)
                            if(type_decode) begin
                                type_decode <= 1'b0;
                                retu_num_reg[vector_cnt] <= Instr[0];
                                if(vector_cnt==(vector_num-1)) begin
                                    vector_cnt <= 'd0;
                                    instr_pointer_state <= section_head;
                                end
                                else vector_cnt <= vector_cnt + 'd1;
                            end
                            else begin
                                type_decode <= 1'b1;
                                para_num_reg[vector_cnt] <= Instr[15:8];                                    
                            end
                        end
                        8'h03:begin //; section "Function" (3)
                            {function_type_list[function_store_addr*`read_window_size+10]
                            ,function_type_list[function_store_addr*`read_window_size+9]
                            ,function_type_list[function_store_addr*`read_window_size+8]
                            ,function_type_list[function_store_addr*`read_window_size+7]
                            ,function_type_list[function_store_addr*`read_window_size+6]
                            ,function_type_list[function_store_addr*`read_window_size+5]
                            ,function_type_list[function_store_addr*`read_window_size+4]
                            ,function_type_list[function_store_addr*`read_window_size+3]
                            ,function_type_list[function_store_addr*`read_window_size+2]
                            ,function_type_list[function_store_addr*`read_window_size+1]
                            ,function_type_list[function_store_addr*`read_window_size]} <= Instr;
                            if(~((vector_cnt+`read_window_size)<(vector_num-1))) begin
                                vector_cnt <= 'd0;
                                instr_pointer_state <= section_head;
                                function_store_addr <= 4'd0;
                            end
                            else begin
                                vector_cnt <= vector_cnt + `read_window_size;
                                function_store_addr <= function_store_addr + 'd1;
                            end
                        end
                        8'h06:begin //; section "Global" (6)
                            if(vector_cnt==(vector_num-1'd1)) begin
                                vector_cnt <= 'd0;
                                instr_pointer_state <= section_head;
                            end
                            else begin
                                vector_cnt <= vector_cnt + 'd1;
                            end
                        end
                        default:begin
                            instr_pointer_state <= section_head;
                        end
                    endcase                
                end
            endcase
        end
    end
    
    
endmodule
