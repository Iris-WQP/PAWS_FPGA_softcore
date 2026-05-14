module WASM_TOP(
    
        input i_clk,
        input i_rst_n,
        input i_exec_mode,
        input [(`log_func_num_max-1):0] i_exec_func_idx,
        input i_exec_param_vld,
        input [63:0] i_exec_param_data,

        output reg [2:0] o_ERROR,
        output [1:0] o_work_state,
        output [63:0] o_exec_result,
        output o_exec_result_vld,

        //line memory read channel
        input i_line_mem_rd_rdy,    //or you can call it request
        // output o_line_mem_rd_vld,
        input [8:0] i_line_mem_rd_addr,
        output [63:0] o_line_mem_rd_data,

        //instruction memory write channel
        output reg o_instr_mem_wr_rdy,
        input i_instr_mem_wr_vld,
        input [9:0] i_instr_mem_wr_addr,
        input [`instr_read_width-1:0] i_instr_mem_wr_data,
        input i_instr_mem_wr_finish  //new
        
        ,    

        //debug signals
        input i_scl,
        input i_sda,
        output o_sda,
        input i_debug_ena

    );

    //top state control
    reg [1:0] top_state;
    wire instr_finish;
    wire operand_stack_exceed;
    wire operand_stack_empty_pop;
    wire ctrl_shift_vld;
    wire multi_cycle_vld;
    reg bubble;
    wire o_INSTR_ERROR;
    wire shift_vld;
    wire flush;
    wire alu_busy;
    wire alu_result_vld;
    wire [63:0] FPUResult;
    wire fpu_result_vld;
    wire exec_result_vld;
    wire [63:0] exec_result;
    wire int_multi_cycle_vld;
    wire fpu_multi_cycle_vld;
    parameter   instr_mem_in = 2'b00,
                working = 2'b01,
                finish_executing = 2'b11;

    //ctrl unit
    wire [63:0] ALUResult;
    wire stack_empty;
    wire quasi_jump_en;
    wire function_content_start;
    wire code_content_running;
    wire [`instr_read_width-1:0] Instr;
    wire Instr_vld;
    wire [7:0] read_pointer_shift_minusone;
    wire [3:0] pop_num;
    wire [1:0] push_select;
    wire [4:0] ALUControl;
    wire store_en;
    wire load_en;
    wire local_set;
    wire local_get;
    wire global_get;
    wire global_set;
    wire global_init;
    wire [31:0] vector_cnt;
    // wire [7:0]global_offset_13_8;
    // wire [7:0]global_offset_7_0;
    // wire [7:0]EMA_EMAW;
    wire [31:0] global_offset;
    wire [63:0] constant;
    wire [(`instr_log2_bram_depth-1):0] read_pointer;
    wire jump_en;
    wire jump_en_final;
    wire [`instr_log2_bram_depth-1:0] jump_addr;
    wire [`instr_log2_bram_depth-1:0] jump_addr_final;

    //operand stack window
    wire [`st_width-1:0] A_pop_window;
    wire [`st_width-1:0] B_pop_window;
    wire [`st_width-1:0] C_pop_window;

    //line memory
    wire [`bram_in_width-1:0] load_data;
    wire [`st_width-1:0] local_mem_data;

    //stack
    
    wire push_num; //D-stage
    reg [`st_width-1:0] push_data;
    wire [`pop_num_max*`st_width-1:0] pop_window;

    //control stack
    wire control_stack_left_one;   //judge if the module is about to finish
    wire function_call; //instruction is call, jump, call stack push
    wire end_instr; 
    wire true_end; //a function is finished, jump back, call stack pop
    wire operand_stack_tag_pop; //operand stack pop
    wire function_retu_num; //return parameter number, 0 or 1
    wire control_stack_push;
    reg [`call_stack_width-1:0] control_stack_push_data;
    wire [`call_stack_width-1:0] control_stack_top_data;
    wire [1:0] control_stack_top_type;
    wire [`st_log2_depth:0] operand_stack_top_pointer;
    wire [(`st_log2_depth-1):0] stack_pointer_tag;
    wire [(`st_log2_depth-1):0] stack_pointer_tag_block;
    wire [(`log_pa_re_num_max-1):0] function_para_num;
    wire [7:0] allocate_local_memory_size;
    wire [`st_log2_depth-1:0] function_stack_tag;
    wire [`st_log2_depth-1:0] control_stack_tag;
    wire read_control_endjump;    
    wire [`instr_log2_bram_depth-1:0] return_addr_tag;
    wire read_retu_num;
    wire [3:0] LEB128_byte_cnt;
    wire [`instr_log2_bram_depth-1:0] pre_calu_return_addr;
    wire block_instr;
    wire block_hold;
    wire loop_instr;
    wire loop_fault_end;
    wire if_instr;
    wire br_table_instr;
    wire return_instr;
    wire control_retu_num;
    wire [1:0] instr_pointer_state_out;
    //write, depends on instr write method, useless for now.
    wire  wr_req_vld = 0;   
    wire [`log_write_window_size-1:0] write_pointer_shift_minusone;
    wire [`instr_write_width-1:0] wr_data;

    //ALU operands 
    wire [`st_width-1:0] A_ALU;
    wire [`st_width-1:0] B_ALU;
    wire [`st_width-1:0] operand_stack_bottom;
    wire blocktype_is_void;
    wire blocktype_has_result;

    //branch table support
    wire [2:0] read_specific_addr;
    wire [2:0] br_table_offset;
    wire [`instr_bram_width-1:0] read_specific_data;
    assign br_table_offset = (A_pop_window < constant)? A_pop_window:constant;
    assign read_specific_addr = br_table_offset+3'd2;

    //debugs
    wire [7:0] debug_reg_14 = {function_call, block_instr, loop_instr, if_instr, return_instr, control_retu_num, instr_pointer_state_out};
    wire [7:0] debug_reg_15 = control_stack_push_data[7:0];
    wire [7:0] debug_reg_16 = control_stack_push_data[15:8];
    wire [7:0] debug_reg_17 = control_stack_push_data[23:16];
    wire [7:0] debug_reg_18 = {LEB128_byte_cnt, block_hold, read_control_endjump, control_stack_push_data[26:24]};
    wire [7:0] debug_reg_20 = {pop_num[1:0],push_num,control_stack_push,true_end,control_stack_top_data[26:24]};
    wire [7:0] debug_reg_21;

/*----------------------------- D stage signals -----------------------------*/
reg quasi_jump_en_d;
// reg jump_en_d;
wire unreachable_instr;
reg [(`instr_log2_bram_depth-1):0] jump_addr_d;
reg function_content_start_d;
reg code_content_running_d;
reg store_en_d;
reg load_en_d;
reg global_init_d;
reg [31:0] vector_cnt_d;
reg [63:0] constant_d;
reg [(`log_pa_re_num_max-1):0] function_para_num_d;
reg function_retu_num_d;
reg [7:0] allocate_local_memory_size_d;
reg [`instr_log2_bram_depth-1:0] pre_calu_return_addr_d;
reg [7:0] opcode_d;
wire br_related;
wire br_if;
wire else_instr;
wire length_mode_d;
wire alu_fpu_select_d;
reg [7:0] instr_15_8_d;
reg [(`instr_log2_bram_depth-1):0] read_pointer_d;

/*----------------------------- E stage signals -----------------------------*/
reg [31:0] vector_cnt_e;
reg [63:0] constant_e;
reg end_instr_e;
reg unreachable_instr_e;
reg [(`log_pa_re_num_max-1):0] function_para_num_e;
reg function_retu_num_e;
reg push_num_e;
reg [3:0] pop_num_e;
reg [4:0] ALUControl_e;
reg [1:0] push_select_e;
reg [7:0] allocate_local_memory_size_e;
reg [`instr_log2_bram_depth-1:0] pre_calu_return_addr_e;
reg [(`instr_log2_bram_depth-1):0] jump_addr_e;
reg store_en_e;
reg load_en_e;
reg local_set_e;
reg local_get_e;
reg global_get_e;
reg global_set_e;
reg global_init_e;
reg function_call_e;
reg block_instr_e;
reg loop_instr_e;
reg if_instr_e;
reg br_table_instr_e;
reg return_instr_e;
reg operand_stack_tag_pop_e;
reg br_related_e;
reg quasi_jump_en_e;
reg br_if_e;
reg else_instr_e;
reg [7:0] instr_15_8_e;
wire block_valid;
wire control_stack_end;
wire unreachable_instr_v;
wire push_num_v;
wire [3:0] pop_num_v;
wire function_call_v;
wire return_instr_v;
wire global_set_v;
wire global_get_v;
wire br_table_instr_v;
wire br_related_v;
wire br_if_v;
wire local_set_v;
wire local_get_v;
wire operand_stack_tag_pop_v;
wire quasi_jump_en_v;
wire global_init_v;
wire load_en_v;
wire store_en_v;
reg alu_start_pending;
reg fpu_start_pending;
reg length_mode_e;
reg alu_fpu_select_e;
reg [(`instr_log2_bram_depth-1):0] read_pointer_e;

/*----------------------------- F stage  -----------------------------*/
    //top state control
    always@(*)begin
        o_ERROR = {o_INSTR_ERROR, operand_stack_exceed, operand_stack_empty_pop};
    end

    assign shift_vld = ctrl_shift_vld & (top_state == working) & (~i_debug_ena);
    assign o_work_state = top_state;
    assign o_exec_result = operand_stack_bottom;
    assign o_exec_result_vld = (top_state == finish_executing);

    always@(posedge i_clk or negedge i_rst_n)begin
        if (~i_rst_n) begin
            top_state <= instr_mem_in;
            o_instr_mem_wr_rdy <= 1'b1;
        end else begin
            case(top_state)
                instr_mem_in:begin
                    if(i_instr_mem_wr_finish)begin
                        top_state <= working;
                        o_instr_mem_wr_rdy <= 1'b0;
                    end
                end
                working:begin
                    if(instr_finish)begin
                        top_state <= finish_executing;
                    end
                end
            endcase
        end
    end

    CtrlUnit u_ctrl_unit (
        .clk(i_clk),
        .rst_n(i_rst_n),
        .cu_working(shift_vld),
        .i_exec_mode(i_exec_mode),
        .i_exec_function_idx(i_exec_func_idx),
        .read_pointer(read_pointer),
        .Instr(Instr),
        .read_pointer_shift_minusone(read_pointer_shift_minusone),
        .INSTR_ERROR(o_INSTR_ERROR),
        .jump_en(jump_en),
        .quasi_jump_en(quasi_jump_en),
        .jump_addr(jump_addr),
        .function_content_start(function_content_start),
        .code_content_running(code_content_running),
        .store_en(store_en),
        .load_en(load_en),
        .global_init(global_init),
        .vector_cnt(vector_cnt),
        .constant(constant),
        .function_retu_num(function_retu_num),
        .function_para_num(function_para_num),
        .allocate_local_memory_size(allocate_local_memory_size),
        .LEB128_byte_cnt(LEB128_byte_cnt),
        .pre_calu_return_addr(pre_calu_return_addr),
        .instr_pointer_state_out (instr_pointer_state_out),
        .section_type_out(debug_reg_21)
    );

    InstrMemCtrl #
             (   .ADDR_WIDTH (`instr_log2_bram_depth),
                 .DATA_WIDTH (`instr_bram_width),
                 .DEPTH (`instr_bram_depth))
                 u_instr_mem_ctrl
             (
                .clk(i_clk),
                .rst_n(i_rst_n),
                // .EMA_EMAW(EMA_EMAW),
                .shift_vld(shift_vld),
                .read_pointer_shift_minusone(read_pointer_shift_minusone),
                .rd_data_out(Instr),
                // //write port
                .wr_vld(i_instr_mem_wr_vld&o_instr_mem_wr_rdy),     //wr_req_vld
                .i_instr_mem_wr_addr(i_instr_mem_wr_addr),
                .i_instr_mem_wr_data(i_instr_mem_wr_data),
                //jump
                .jump_en(jump_en_final),
                .jump_addr(jump_addr_final),
                .read_pointer_out(read_pointer),
                //read specific addr
                .read_specific_addr(read_specific_addr),
                .read_specific_data(read_specific_data)

                );  
    //global
    // assign global_offset = {18'd0,global_offset_13_8[5:0], global_offset_7_0};
    assign global_offset = 31'h100;


/*------------------------------- D Stage -------------------------------------*/ 
    always@(posedge i_clk or negedge i_rst_n)begin
    if (~i_rst_n|flush) begin
        quasi_jump_en_d <= 1'b0;
        // jump_en_d <= 1'b0;
        jump_addr_d <= {(`instr_log2_bram_depth){1'b0}};
        function_content_start_d <= 1'b0;
        code_content_running_d <= 1'b0;
        store_en_d<= 1'b0;
        load_en_d<= 1'b0;
        global_init_d<= 1'b0;
        vector_cnt_d<= 32'd0;
        constant_d<= 32'd0;
        function_para_num_d <= {(`log_pa_re_num_max){1'b0}};
        function_retu_num_d <= 1'b0;
        allocate_local_memory_size_d <= 8'd0;
        pre_calu_return_addr_d <= {(`instr_log2_bram_depth){1'b0}};
        opcode_d <= 8'd0;
        instr_15_8_d <= 8'd0;
        read_pointer_d <= {(`instr_log2_bram_depth){1'b0}};
    end else begin
        if (shift_vld) begin
            quasi_jump_en_d <= quasi_jump_en;
            // jump_en_d <= jump_en;
            jump_addr_d <= jump_addr;
            function_content_start_d <= function_content_start;
            code_content_running_d <= code_content_running;
            store_en_d <= store_en;
            load_en_d <= load_en;
            global_init_d <= global_init;
            vector_cnt_d <= vector_cnt;
            constant_d <= constant;
            function_para_num_d <= function_para_num;
            function_retu_num_d <= function_retu_num;
            allocate_local_memory_size_d <= allocate_local_memory_size;
            pre_calu_return_addr_d <= pre_calu_return_addr;
            opcode_d <= Instr[7:0];
            instr_15_8_d <= Instr[15:8];
            read_pointer_d <= read_pointer;
        end
    end
    end


    Decoder u_decoder(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .opcode(opcode_d),
        .function_content_start(function_content_start_d),
        .code_content_running(code_content_running_d),
        //to stack
        .push_num_out(push_num), //0 or 1
        .pop_num_out(pop_num), //0~15
        //push_select: 0~from ALU; 1~from memory; 2~from instr;
        .push_select(push_select),
        //to ALU     
        .ALUControl(ALUControl),
        .length_mode(length_mode_d),
        .alu_fpu_select(alu_fpu_select_d),
        //to local memory
        .local_set(local_set),
        .local_get(local_get),
        //to global memory
        .global_set(global_set),
        .global_get(global_get),
        //to call stack (control stack)
        .function_call(function_call),
        .block_instr(block_instr),
        .loop_instr(loop_instr),
        .if_instr(if_instr),
        .br_table_instr(br_table_instr),
        .unreachable_instr(unreachable_instr),
        .end_instr(end_instr),
        .return_instr(return_instr),
        .operand_stack_tag_pop(operand_stack_tag_pop),
        .br_related(br_related),
        .br_if(br_if),
        .else_instr(else_instr)
    );


/*------------------------------------ E stage -----------------------------*/
    assign flush = quasi_jump_en_v | (read_control_endjump&end_instr_e);
    assign jump_en_final = jump_en | flush;
    assign jump_addr_final = jump_en? jump_addr : (quasi_jump_en_v? jump_addr_e:return_addr_tag);
    always@(posedge i_clk or negedge i_rst_n)begin
        if (~i_rst_n | flush) begin
            vector_cnt_e <= 32'd0;
            constant_e <= 32'd0;
            end_instr_e <= 1'b0;
            unreachable_instr_e <= 1'b0;
            function_para_num_e <= {(`log_pa_re_num_max){1'b0}};
            function_retu_num_e <= 1'b0;
            push_num_e <= 1'b0;
            pop_num_e <= 4'b0;
            ALUControl_e <= 5'd0;
            push_select_e <= 2'b00;
            allocate_local_memory_size_e <= 8'd0;
            pre_calu_return_addr_e <= {(`instr_log2_bram_depth){1'b0}};
            store_en_e<= 1'b0;
            load_en_e<= 1'b0;
            local_set_e<= 1'b0;
            local_get_e<= 1'b0;
            global_get_e<= 1'b0;
            global_set_e<= 1'b0;
            global_init_e<= 1'b0;
            function_call_e<= 1'b0;
            block_instr_e<= 1'b0;
            loop_instr_e<= 1'b0;
            if_instr_e<= 1'b0;
            br_table_instr_e<= 1'b0;
            return_instr_e<= 1'b0;
            operand_stack_tag_pop_e<= 1'b0;
            br_related_e <= 1'b0;
            br_if_e <= 1'b0;
            instr_15_8_e <= 8'd0;
            read_pointer_e <= {(`instr_log2_bram_depth){1'b0}};
            else_instr_e <= 1'b0;
            quasi_jump_en_e <= 1'b0;
            jump_addr_e <= {(`instr_log2_bram_depth){1'b0}};
            length_mode_e <= 1'b0;
            alu_fpu_select_e <= 1'b0;
        end else begin
            if (shift_vld) begin
                vector_cnt_e <= vector_cnt_d; 
                constant_e <= constant_d; 
                end_instr_e <= end_instr; 
                unreachable_instr_e <= unreachable_instr; 
                function_para_num_e <= function_para_num_d; 
                function_retu_num_e <= function_retu_num_d; 
                push_num_e <= flush? 1'b0: push_num; 
                pop_num_e <= pop_num; 
                ALUControl_e <= ALUControl; 
                push_select_e <= push_select; 
                allocate_local_memory_size_e <= allocate_local_memory_size_d; 
                pre_calu_return_addr_e <= pre_calu_return_addr_d; 
                store_en_e<= store_en_d; 
                load_en_e<= load_en_d; 
                local_set_e<= local_set; 
                local_get_e<= local_get; 
                global_get_e <= global_get;
                global_set_e <= global_set;
                global_init_e<= global_init_d;
                function_call_e<= function_call;
                block_instr_e<= block_instr;
                loop_instr_e<= loop_instr;
                if_instr_e <= if_instr;
                br_table_instr_e <= br_table_instr;
                return_instr_e <= return_instr;
                operand_stack_tag_pop_e <= operand_stack_tag_pop;
                br_related_e <= br_related;
                br_if_e <= br_if;
                instr_15_8_e <= instr_15_8_d;
                read_pointer_e <= read_pointer_d;
                else_instr_e <= else_instr;
                quasi_jump_en_e <= quasi_jump_en_d;
                jump_addr_e <= jump_addr_d;
                length_mode_e <= length_mode_d;
                alu_fpu_select_e <= alu_fpu_select_d;
            end
        end
    end

    assign control_stack_end = control_stack_left_one & end_instr_e;
    assign unreachable_instr_v = unreachable_instr_e & block_valid;
    assign instr_finish = unreachable_instr_v | control_stack_end;
    assign int_multi_cycle_vld = (~alu_fpu_select_e) & ((ALUControl_e == 5'b10101) |
                                                         (ALUControl_e == 5'b10110) |
                                                         (ALUControl_e == 5'b10111) |
                                                         (ALUControl_e == 5'b11001) |
                                                         (ALUControl_e == 5'b11010));
    assign fpu_multi_cycle_vld = alu_fpu_select_e & ((ALUControl_e == 5'b00000) |
                                                     (ALUControl_e == 5'b00001) |
                                                     (ALUControl_e == 5'b10101) |
                                                     (ALUControl_e == 5'b10110) |
                                                     (ALUControl_e == 5'b10011));
    assign multi_cycle_vld = int_multi_cycle_vld | fpu_multi_cycle_vld;
    assign exec_result_vld = alu_fpu_select_e ? fpu_result_vld : alu_result_vld;
    assign exec_result = alu_fpu_select_e ? FPUResult : ALUResult;

    assign push_num_v = (block_valid & ((~multi_cycle_vld) | exec_result_vld)) ?
                        (((end_instr_e & loop_fault_end) ? 1'b0 : ((end_instr_e | return_instr_v) ? read_retu_num : push_num_e))) :
                        1'b0;
    assign pop_num_v = (block_valid & ((~multi_cycle_vld) | exec_result_vld)) ? pop_num_e : 4'b0;
    assign function_call_v = function_call_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign return_instr_v = return_instr_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign global_set_v = global_set_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign global_get_v = global_get_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign br_table_instr_v = br_table_instr_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign br_related_v = br_related_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign br_if_v = br_if_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign local_set_v = local_set_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign local_get_v = local_get_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign operand_stack_tag_pop_v = operand_stack_tag_pop_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign quasi_jump_en_v = quasi_jump_en_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign store_en_v = store_en_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign load_en_v = load_en_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);
    assign global_init_v = global_init_e & block_valid & ((~multi_cycle_vld) | exec_result_vld);

    //ALU operands 
    assign A_ALU = (store_en_v|load_en_v|local_set_v|local_get_v|global_get_v|global_set_v)? constant_e : (global_init_v? vector_cnt_e:A_pop_window);    
    assign B_ALU = (global_get_v|global_set_v|global_init_v)?global_offset:(((local_set_v|local_get_v)? function_stack_tag:(load_en_v? A_pop_window:B_pop_window)));

    //control stack
    assign blocktype_is_void = (instr_15_8_e == 8'h40);
    assign blocktype_has_result = (instr_15_8_e == 8'h7f) | // i32
                                  (instr_15_8_e == 8'h7e) | // i64
                                  (instr_15_8_e == 8'h7d) | // f32
                                  (instr_15_8_e == 8'h7c);  // f64
    assign control_retu_num = blocktype_is_void ? 1'b0 : (blocktype_has_result ? 1'b1 : function_retu_num_e);
    assign control_stack_top_type = control_stack_top_data[`st_log2_depth+`instr_log2_bram_depth+2:`st_log2_depth+`instr_log2_bram_depth+1];
    assign control_stack_tag = control_stack_top_data[(`st_log2_depth+`instr_log2_bram_depth-1):`instr_log2_bram_depth];
    assign return_addr_tag = control_stack_top_data[`instr_log2_bram_depth-1:0];
    assign read_retu_num = control_stack_top_data[`st_log2_depth+`instr_log2_bram_depth];
    assign read_control_endjump = (control_stack_top_type==2'b01)|((control_stack_top_type==2'b11)&block_hold);
    assign loop_fault_end = ((control_stack_top_type==2'b11)&block_hold);
    assign true_end = end_instr_e&(~loop_fault_end);
    assign control_stack_push = function_call_v|block_instr_e|loop_instr_e|if_instr_e;
    assign stack_pointer_tag = operand_stack_top_pointer - function_para_num_e;
    assign stack_pointer_tag_block = (blocktype_is_void | blocktype_has_result) ? operand_stack_top_pointer : (operand_stack_top_pointer - function_para_num_e);
    always@(*)begin
        if(function_call_v)begin
            control_stack_push_data = {2'b01, function_retu_num_e, stack_pointer_tag, pre_calu_return_addr_e};
        end else if (block_instr_e)begin
            control_stack_push_data = {2'b00, control_retu_num, stack_pointer_tag_block, `instr_log2_bram_depth'd0};
        end else if (loop_instr_e)begin
            control_stack_push_data = {2'b11, control_retu_num, stack_pointer_tag_block, (read_pointer_e+`instr_log2_bram_depth'd2)};
        end else if (if_instr_e)begin
            control_stack_push_data = {2'b10, control_retu_num, {stack_pointer_tag_block-`st_log2_depth'd1}, `instr_log2_bram_depth'd0};
        end else begin
            control_stack_push_data = 'd0;
        end
    end

    always@(*)begin
        case({(end_instr_e|return_instr_v), push_select_e})
            3'b100: push_data = A_pop_window;
            3'b001: push_data = load_data;//for line memory or global memory
            3'b010: push_data = constant_e;
            3'b011: push_data = local_mem_data;//for local memory
            default: push_data = exec_result;  //3'b000
        endcase
    end
    assign ctrl_shift_vld = ~(((load_en_v|store_en_v|global_get_v|global_set_v|global_init_v)&(~bubble)) |
                              (multi_cycle_vld & (~exec_result_vld)));
    reg bubble0;
    always@(posedge i_clk or negedge i_rst_n) begin
        if(~i_rst_n) begin
            bubble <= 1'b0;
            bubble0 <= 1'b0;
            alu_start_pending <= 1'b0;
            fpu_start_pending <= 1'b0;
        end else begin
            if(bubble) bubble <= 1'b0;
            else if (bubble0) begin bubble0 <= 1'b0; bubble <= 1'b1; end
            else if (load_en_v|store_en_v|global_get_v|global_set_v|global_init_v) bubble0 <= 1'b1;

            alu_start_pending <= shift_vld & (~alu_fpu_select_d) & ((ALUControl == 5'b10101) |
                                                                     (ALUControl == 5'b10110) |
                                                                     (ALUControl == 5'b10111) |
                                                                     (ALUControl == 5'b11001) |
                                                                     (ALUControl == 5'b11010));
            fpu_start_pending <= shift_vld & alu_fpu_select_d & ((ALUControl == 5'b00000) |
                                                                  (ALUControl == 5'b00001) |
                                                                  (ALUControl == 5'b10101) |
                                                                  (ALUControl == 5'b10110) |
                                                                  (ALUControl == 5'b10011));

            if(flush) begin
                alu_start_pending <= 1'b0;
                fpu_start_pending <= 1'b0;
            end
        end
    end

    ALU u_alu(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .start(alu_start_pending),
        .A(A_ALU),
        .B(B_ALU),
        .C(C_pop_window),
        .length_mode(length_mode_e),
        .ALUControl(ALUControl_e),
        .ALUResult(ALUResult),
        .busy(alu_busy),
        .result_vld(alu_result_vld)
    );

    FPU u_fpu(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .start(fpu_start_pending),
        .A(A_ALU),
        .B(B_ALU),
        .ALUControl(ALUControl_e),
        .length_mode(length_mode_e),
        .FPUResult(FPUResult),
        .result_vld(fpu_result_vld)
    );      

    ControlStack u_control_stack(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .shift_vld(shift_vld),
        .push(control_stack_push),
        .pop(true_end),
        .retu(return_instr_v),
        .function_call(function_call_v),
        .function_stack_tag(function_stack_tag),
        .push_data(control_stack_push_data),
        .top_data(control_stack_top_data),
        .control_stack_left_one(control_stack_left_one)
    );

    OperandStack u_operand_stack (
        .clk(i_clk),
        .rst_n(i_rst_n),
        .shift_vld(shift_vld),
        .init_vld(i_exec_param_vld),
        .init_data(i_exec_param_data),
        .push_num(push_num_v),
        .push_data(push_data),
        .pop_num(pop_num_v),
        .stack_exceed_push(operand_stack_exceed),
        .stack_exceed_pop(operand_stack_empty_pop),
        .pop_window_A(A_pop_window),
        .pop_window_B(B_pop_window),
        .pop_window_C(C_pop_window),
        .call(function_call_v),
        .retu(operand_stack_tag_pop_v),
        .function_stack_tag(control_stack_tag),
        .w_top_pointer(operand_stack_top_pointer),
        .allocate_local_memory_size(allocate_local_memory_size_e),

        .l_addr(ALUResult[`st_log2_depth:0]),
        .local_set(local_set_v),
        // .local_set_data(A_pop_window),
        .local_get_data(local_mem_data),
        .bottom_data(operand_stack_bottom)
    );

    wire line_memory_read_en = ((load_en_v|global_get_v)&(top_state==working))|(i_line_mem_rd_rdy&(top_state==finish_executing));
    wire line_memory_write_en = ((store_en_v|global_set_v|global_init_v)&(top_state==working));
    wire [13:0] line_memory_addr = (top_state==working)? ((load_en_v|store_en_v)? ALUResult[15:2]:ALUResult[13:0]) : {5'b11111, i_line_mem_rd_addr};
    wire [63:0] line_memory_write_data = global_init_v? constant_e : A_pop_window;
    assign o_line_mem_rd_data = (top_state==finish_executing)?load_data:'d0;

    LineMemory u_line_memory (
        .clk(i_clk),
        .addr(line_memory_addr),
        // .EMA_EMAW(EMA_EMAW),
        .en((line_memory_read_en|line_memory_write_en)),
        .rdata(load_data),
        .we(line_memory_write_en&(top_state==working)&(~i_debug_ena)),
        .wdata(line_memory_write_data)
    );

    BlockCtrl u_block_ctrl(
        .clk(i_clk),
        .rst_n(i_rst_n),
        .ALUResult_0(ALUResult[0]),
        .br_table_instr(br_table_instr_v),
        .br_table_depth(instr_15_8_e), //emm
        .end_instr(end_instr_e),
        .br_if(br_if_v),
        .else_instr(else_instr_e),
        .br_related(br_related_v),
        .function_call(function_call_v),
        .block_instr(block_instr_e),
        .loop_instr(loop_instr_e),
        .if_instr(if_instr_e),
        .cu_working(shift_vld),
        .constant(constant_e),
        .block_valid(block_valid),
        .block_hold(block_hold)
      );   

endmodule
