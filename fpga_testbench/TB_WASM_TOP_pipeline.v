`timescale 1ns / 1ps
// `include "src/wasm_defines.vh"
// `include "src/WASM_TOP.v"
//`include "wasm_defines.vh"
// `include "src/WASM_TOP_pipeline1.v"
//`include "src/i2c_master.v"
`define T 10
module TB_WASM_TOP;


    // clk & rst
    reg clk=1;
    always #(`T/2) clk = ~clk; // Generate clock signal    
    reg rst_n;
    initial begin
    rst_n = 0;
    # 3;
    rst_n = 1;
    end 

    //outputs
    wire [2:0] o_ERROR;
    wire [1:0] o_work_state;
    reg [1:0] pipe1_work_state;
    reg [1:0] pipe2_work_state;
    wire o_instr_mem_wr_rdy;
    // wire o_line_mem_rd_vld;
    wire [31:0] o_line_mem_rd_data;
    // signed wire [31:0] output_line_mem = o_line_mem_rd_data;
    //inputs
    reg i_instr_mem_wr_vld;
    reg [`log_instr_mem_depth-1:0] i_instr_mem_wr_addr;
    reg [`instr_read_width-1:0] i_instr_mem_wr_data;
    reg i_instr_mem_write_finish;

    reg i_line_mem_rd_rdy;
    reg [8:0] i_line_mem_rd_addr;

    reg [`instr_bram_width-1:0] bram [0:22941];
    reg [31:0] cnt;
    wire [31:0] cnttt;
    reg [31:0] cnt_max;
    assign cnttt = cnt*11;
    reg i_debug_enable;
//    wire block_vaild;
//    wire [14:0] line_memory_addr;
//    wire [`log_call_stack_depth:0] w_top_pointer;

/*--------------------i2c signals----------------------*/
    reg i2cclk;
    wire sda, scl;
    wire	sda_m;
    wire	o_sda;
    reg err_flag;

    reg	[6:0]	dev_adr;
    reg	[7:0]	reg_adr;
    reg	[7:0]	wr_data;
    reg	[7:0]	rd_data;
    reg i2creg_read;
    reg i2creg_write = 0;

    initial begin
    i2cclk = 0;
    err_flag = 0;
    wr_data = $random;
    forever #8 i2cclk <= !i2cclk;
    end


    initial begin
        i_debug_enable = 1'b0;
        dev_adr = 7'h6C;
        reg_adr = 8'h02;
    end

    pullup	( sda );		// Enternal Pull-high in SDA
    bufif0  ( sda, 1'b0, o_sda );	// Slave's SDA IO
    bufif0  ( sda, 1'b0, sda_m );	// Master's SDA IO

/*--------------------hex files-----------------------*/   

    initial begin
        $display("Loading test data");
/*--------------------original hex-----------------------*/         
        // $readmemh("./test/hex_files/br_table_hex.txt", bram);
        // $readmemh("./test/hex_files/br_table_wat_hex.txt", bram);
        // $readmemh("./test/hex_files/mem_if_global_hex.txt", bram);
        // $readmemh("./test/hex_files/ifelse_nest2_hex.txt", bram);
        $readmemh("/data/home2/qiupingw/Softcore/PAWS_softcore_ax7325b_pipeline/hex_files/factorial.txt", bram);
        // $readmemh("./test/hex_files/sign_shift_hex.txt", bram);
        // $readmemh("./test/hex_files/sign_shift2_hex.txt", bram);
        // $readmemh("./test/hex_files/vmv3_hex.txt", bram);
        // $readmemh("./test/hex_files/vmv10_hex.txt", bram);
        // $readmemh("./test/hex_files/hex_files/simple_test.hex", bram);
        // $readmemh("./test/hex_files/vmm_20_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_30_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm10_s_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_40_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_100_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_10000_hex.txt", bram);
        // $readmemh("./factor/factor_152.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_64_t64.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_6_t32.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_122_t128.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/3mm_inserted_stack_38_t32.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/3mm_46_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/atax_42_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_43_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_inserted_stack_36_t32.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/symm_44_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_inserted_stack_36_t32.hex", bram);
        // $readmemh("./new_stack_file/gcd_max_82.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_23_t32.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_61_t64.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_61_t64.hex", bram);
        // $readmemh("./new_stack_file/fib_inserted_stack_37_t64.hex", bram);
        // $readmemh("./new_stack_file/fib_inserted_stack_9_t32.hex", bram);
        // $readmemh("./new_stack_file/fib_max_94.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/atax_inserted_stack_34_t32.hex", bram);
        // $readmemh("./test/wat_files/2mm1.hex", bram);
        // $readmemh("./test/wat_files/covariance.hex", bram);
        // $readmemh("/home/wu/wasm_cpu/clean_version/test/polybench_hardware/wasm_processor_hardware/atax_.hex", bram);
        // $readmemh("comparison/example.hex", bram);
        // $readmemh("/home/wu/wasm_cpu/clean_version/test/polybench_hardware/wasm_processor_hardware/3mm.hex", bram);
        // $readmemh("/home/wu/wasm_cpu/clean_version/test/polybench_hardware/wasm_processor_hardware/gemvar_.hex", bram);
        // $readmemh("/home/wu/wasm_cpu/clean_version/test/polybench_hardware/wasm_processor_hardware/convariance_.hex", bram);

/*-------------------polybench hex-----------------------*/ 
        // $readmemh("./test/polybench_hardware/wasm_processor_hardware/2mm1.hex", bram);
        // $readmemh("./test/polybench_hardware/wasm_processor_hardware/mvt_.hex", bram);
        // $readmemh("./test/polybench_hardware/wasm_processor_hardware/cholesky.hex", bram);
        // $readmemh("./test/polybench_hardware/wasm_processor_hardware/gemm_.hex", bram);
        // $readmemh("./test/polybench_hardware/wasm_processor_hardware/bicg_.hex", bram);
        // $display("Test data loaded: %0h %0h %0h %0h", bram[0], bram[1], bram[2], bram[3]);
    end


/*--------------------testbench control-----------------------*/   
    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            pipe1_work_state <= #2 'd0;
            pipe2_work_state <= #2 'd0;
        end else begin
            pipe1_work_state <= #2 o_work_state;
            pipe2_work_state <= #2 pipe1_work_state;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            i_instr_mem_write_finish <= #2 'd0;
            i_instr_mem_wr_data <= #2 'd0;
            i_instr_mem_wr_addr <= #2 'd0;
            i_instr_mem_wr_vld <= #2 'd1;
            i_line_mem_rd_rdy <= #2 'd0;
            i_line_mem_rd_addr <= #2 'd0;

            cnt <= #2 'd0;
            cnt_max <= #2 32'd1000; // 22941/11 = 2094
        end
        else begin
            if(cnt == cnt_max)begin
                i_instr_mem_write_finish <= #2 'd1;
                i_instr_mem_wr_vld <= #2 'd0;
            end else begin
                if(i_instr_mem_wr_vld)begin
                    i_instr_mem_wr_data <= #2 {bram[cnttt+'d10],bram[cnttt+'d9],bram[cnttt+'d8], bram[cnttt+'d7], bram[cnttt+'d6], bram[cnttt+'d5], bram[cnttt+'d4], bram[cnttt+'d3], bram[cnttt+'d2], bram[cnttt+'d1], bram[cnttt]};
                    i_instr_mem_wr_addr <= #2 i_instr_mem_wr_addr + 'd1;
                    cnt <= #2 cnt + 'd1;
                end
            end
            // if (i_instr_mem_write_finish) i_instr_mem_write_finish <= #2 'd0;
            if(o_work_state == 2'b11) begin
                i_line_mem_rd_rdy <= #2 'd1;
            end
        end
    end



    // generate .vcd
        // initial begin
        //     $fsdbDumpfile("TB_WASM_TOP.fsdb");
        //     $fsdbDumpvars(0, "+mda");   // mda = multiple dimension array
        // end
    
    // initial begin
        //     $dumpfile("wave.vcd"); 
        //     $dumpvars(0);
        // end
        // initial begin
        //     $fsdbDumpfile("TB_WASM_TOP.fsdb");
        //     $fsdbDumpvars(0, "+mda");   // mda = multiple dimension array
        // end
//    `ifdef POST_LAYOUT_SIM
//        initial $sdf_annotate("../../../APR/WASM_TOP/Results/Final/WASM_TOP.max.sdf", u_WASM_TOP, , , "MAXIMUM");
//    `else
//        `ifdef POST_SYN_SIM
//            initial $sdf_annotate("../../../Syn/WASM_TOP/Results/Mapped/WASM_TOP.sdf", u_WASM_TOP, , , "MAXIMUM");
//        `endif
//    `endif

//    reg [`st_log2_depth:0] max_stack_depth;

//    wire[`st_log2_depth:0] o_stack_depth;
//    wire [1:0] pre_read_state;
//    wire [(`instr_log2_bram_depth-1):0] read_pointer;
//    wire push_pop_c;
//    wire push_pop_o;
//    wire memory_fetch;
//    wire local_set_get;
    // Instantiate the Unit Under Test (UUT)
    WASM_TOP u_WASM_TOP (
        .i_clk(clk), 
        .i_rst_n(rst_n), 
        .o_ERROR(o_ERROR), 
        .o_work_state(o_work_state), 
        .i_line_mem_rd_rdy(i_line_mem_rd_rdy),    //or you can call it request
        // o_line_mem_rd_vld,
        .i_line_mem_rd_addr(i_line_mem_rd_addr), 
        .o_line_mem_rd_data(o_line_mem_rd_data),
        .o_instr_mem_wr_rdy(o_instr_mem_wr_rdy), 
        .i_instr_mem_wr_vld(i_instr_mem_wr_vld),
        .i_instr_mem_wr_addr((i_instr_mem_wr_addr-1'b1)), 
        .i_instr_mem_wr_data(i_instr_mem_wr_data), 
        .i_instr_mem_wr_finish(i_instr_mem_write_finish),
        .i_scl(scl),
        .i_sda(sda),
        .o_sda(o_sda),
        .i_debug_ena(i_debug_enable)
        // .read_pointer(read_pointer), 
        // .operand_stack_top_pointer(o_stack_depth),
        // .pre_read_state(pre_read_state),
        // .block_vaild(block_vaild),
        // .line_memory_addr(line_memory_addr),
        // .w_top_pointer(w_top_pointer),
        // .push_pop_c(push_pop_c),
        // .push_pop_o(push_pop_o),
        // .memory_fetch(memory_fetch),
        // .local_set_get(local_set_get)
        );

   
//    write the o_stack_depth into a xls file every clk
//    integer fd;
//    initial begin
//        max_stack_depth = 0;
//        fd = $fopen("stack_depth.txt", "w");
//        if (fd == 0) begin
//            $display("Error opening file");
//            $finish;
//        end
//    end
//    always @(posedge clk or negedge rst_n) begin
//        if (rst_n&o_work_state == 2'b01&pre_read_state==2'b00) begin
//            $fwrite(fd, "%0d\n", o_stack_depth);
//            if (o_stack_depth > max_stack_depth) begin
//                max_stack_depth <= o_stack_depth;
//            end
//        end
//    end

//    //write the read_pointer into a txt file every clk, when rst_n&o_work_state == 2'b01&pre_read_state==2'b00
//    reg [31:0] count_block;
//    reg [31:0] count_total;
//    integer fd_read_pointer;
//    initial begin
//        count_block = 0;
//        count_total = 0;
//        fd_read_pointer = $fopen("read_pointer.txt", "w");
//        if (fd_read_pointer == 0) begin
//            $display("Error opening file");
//            $finish;
//        end
//    end
//    always @(posedge clk or negedge rst_n) begin
//        if (rst_n&o_work_state == 2'b01&pre_read_state==2'b00) begin
//            if(~block_vaild) begin
//                $fwrite(fd_read_pointer, "blocked %0h\n", read_pointer);
//                count_block = count_block + 1;
//            end else begin
//                $fwrite(fd_read_pointer, "%0h\n", read_pointer);
//            end
//            count_total = count_total + 1;
//        end
//    end

    reg [31:0] clk_cnt;
//    reg [31:0] read_line_cnt;

//    count clk from reset to instr_finish==1
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end

////------------------------------Compare------------------------------------------
//    wire [141:0] comp_MMS1;
//    wire [141:0] comp_MMS2;
//    wire [141:0] comp_MMS3;
//    reg [9:0] higher_CCDS_pointer;
//    reg [9:0] lower_CCDS_pointer;
//    reg [9:0] higher_JVS_pointer;
//    reg [9:0] lower_JVS_pointer;
//    reg [6:0] higher_C_pointer;
//    reg [6:0] lower_C_pointer; 
//    // wire [141:0] comp_JVS;
//    // reg [9:0] JVS_cache [141:0];
//    reg [(25+`log_call_stack_depth):0] MMS_cache [141:0];
//    wire MMS_cache_hit1;
//    wire MMS_cache_hit2;
//    wire MMS_cache_hit3;
//    // wire JVS_cache_hit;
//    wire [(25+`log_call_stack_depth):0] MMS_cache_addr1;
//    wire [(25+`log_call_stack_depth):0] MMS_cache_addr2;
//    wire [(25+`log_call_stack_depth):0] MMS_cache_addr3;
//    reg [31:0] MMS_O_Stack_delay;
//    reg [31:0] MMS_C_Stack_delay;
//    reg [31:0] MMS_memory_delay;
//    reg [31:0] JVS_C_Stack_delay;
//    reg [31:0] JVS_O_Stack_delay;
//    reg [31:0] JVS_CCDS_memory_delay;
//    reg [31:0] CCDS_O_Stack_delay;
//    reg [31:0] MMS_O_Stack_miss;
//    reg [31:0] MMS_C_Stack_miss;
//    reg [31:0] JVM_O_Stack_miss;
//    reg [31:0] JVM_C_Stack_miss;
//    reg [31:0] DSC_O_Stack_miss;
//    reg [31:0] DSC_C_Stack_miss;
//    assign MMS_cache_addr1 = {15'd0, `log_call_stack_depth'd0, o_stack_depth};
//    assign MMS_cache_addr2 = {15'd0, w_top_pointer, 10'd0};
//    assign MMS_cache_addr3 = {line_memory_addr, `log_call_stack_depth'd0, 10'd0};
//    reg [7:0] MMS_cache_write_addr;
//    wire [7:0] MMS_cache_write_addr1;
//    wire [7:0] MMS_cache_write_addr2;
//    reg [31:0] CCDS_C_Stack_delay;
//    integer idx;
//    initial begin
//        // Initialize the MMS_cache with zeros
        
//        for (idx = 0; idx < 142; idx = idx + 1) begin
//            MMS_cache[idx] = 0;
//        end
//    end

//    genvar i,j,k;
//    generate
//        for (i = 0; i < 142; i = i + 1) begin : GEN_COMP
//            assign comp_MMS1[i] = (MMS_cache[i] == MMS_cache_addr1); // ????????????
//        end
//    endgenerate
//    assign MMS_cache_hit1 = |comp_MMS1; // ????????????????????????1????????????
//    generate
//        for (j = 0; j < 142; j = j + 1) begin : GEN_COMP2
//            assign comp_MMS2[j] = (MMS_cache[j] == MMS_cache_addr2); // ????????????
//        end
//    endgenerate
//    assign MMS_cache_hit2 = |comp_MMS2; // ????????????????????????1????????????
//    generate
//        for (k = 0; k < 142; k = k + 1) begin : GEN_COMP3
//            assign comp_MMS3[k] = (MMS_cache[k] == MMS_cache_addr3); // ????????????
//        end
//    endgenerate
//    assign MMS_cache_hit3 = |comp_MMS3; // ????????????????????????1????????????

//    assign MMS_cache_write_addr1 = (MMS_cache_hit1)? MMS_cache_write_addr : MMS_cache_write_addr + 1'b1;
//    assign MMS_cache_write_addr2 = (MMS_cache_hit2)? MMS_cache_write_addr1 : MMS_cache_write_addr1 + 1'b1;


//    always @(posedge clk or negedge rst_n) begin
//        if (~rst_n) begin
//            MMS_O_Stack_delay <= 0;
//            MMS_C_Stack_delay <= 0;
//            MMS_memory_delay <= 0;
//            JVS_C_Stack_delay <= 0;
//            JVS_O_Stack_delay <= 0;
//            JVS_CCDS_memory_delay <= 0;
//            CCDS_O_Stack_delay <= 0;
//            CCDS_C_Stack_delay <= 0;
//            higher_CCDS_pointer <= 'd128;
//            lower_CCDS_pointer <= 0;
//            higher_JVS_pointer <= 142;
//            lower_JVS_pointer <= 0;
//            higher_C_pointer <= 32;
//            lower_C_pointer <= 0;
//            MMS_cache_write_addr <= 0;
//            MMS_O_Stack_miss <= 0;
//            MMS_C_Stack_miss <= 0;
//            JVM_O_Stack_miss <= 0;
//            JVM_C_Stack_miss <= 0;
//            DSC_O_Stack_miss <= 0;
//            DSC_C_Stack_miss <= 0;
//        end else if (o_work_state == 2'b01 & pre_read_state == 2'b00) begin
//            MMS_cache_write_addr <= MMS_cache_write_addr2;
//            if(push_pop_o) begin
//                if (~MMS_cache_hit1) begin
//                    MMS_O_Stack_delay <= MMS_O_Stack_delay+'d10;
//                    MMS_O_Stack_miss <= MMS_O_Stack_miss+'d1;
//                    MMS_cache[MMS_cache_write_addr] <= {15'd0, `log_call_stack_depth'd0, o_stack_depth};
//                end
//                if (o_stack_depth> higher_CCDS_pointer) begin
//                    higher_CCDS_pointer <= higher_CCDS_pointer+16;
//                    lower_CCDS_pointer <= lower_CCDS_pointer+16;
//                    CCDS_O_Stack_delay <= CCDS_O_Stack_delay+'d26;
//                    DSC_O_Stack_miss <= DSC_O_Stack_miss+'d1;
//                end else if (o_stack_depth < lower_CCDS_pointer) begin
//                    higher_CCDS_pointer <= higher_CCDS_pointer-16;
//                    lower_CCDS_pointer <= lower_CCDS_pointer-16;
//                    CCDS_O_Stack_delay <= CCDS_O_Stack_delay+'d26;
//                    DSC_O_Stack_miss <= DSC_O_Stack_miss+'d1;
//                end
//                if (o_stack_depth> higher_JVS_pointer) begin
//                    higher_JVS_pointer <= higher_JVS_pointer+16;
//                    lower_JVS_pointer <= lower_JVS_pointer+16;
//                    JVS_O_Stack_delay <= JVS_O_Stack_delay+'d26;
//                    JVM_O_Stack_miss <= JVM_O_Stack_miss+'d1;
//                end else if (o_stack_depth < lower_JVS_pointer) begin
//                    higher_JVS_pointer <= higher_JVS_pointer-16;
//                    lower_JVS_pointer <= lower_JVS_pointer-16;
//                    JVS_O_Stack_delay <= JVS_O_Stack_delay+'d26;
//                    JVM_O_Stack_miss <= JVM_O_Stack_miss+'d1;
//                end                
//            end
//            if (push_pop_c) begin
//                if(~MMS_cache_hit2)begin
//                    MMS_C_Stack_delay <= MMS_C_Stack_delay+'d10;
//                    MMS_cache[MMS_cache_write_addr1] <= {15'd0, w_top_pointer, 10'd0};
//                    MMS_C_Stack_miss <= MMS_C_Stack_miss+'d1;
//                end
//                if (w_top_pointer > higher_C_pointer) begin
//                    higher_C_pointer <= w_top_pointer+16;
//                    lower_C_pointer <= lower_C_pointer+16;
//                    CCDS_C_Stack_delay <= CCDS_C_Stack_delay+'d26;
//                    DSC_C_Stack_miss <= DSC_C_Stack_miss+'d1;
//                end else if (w_top_pointer < lower_C_pointer) begin
//                    higher_C_pointer <= higher_C_pointer-16;
//                    lower_C_pointer <= lower_C_pointer-16;
//                    CCDS_C_Stack_delay <= CCDS_C_Stack_delay+'d26;
//                    DSC_C_Stack_miss <= DSC_C_Stack_miss+'d1;
//                end
//                JVS_C_Stack_delay <= JVS_C_Stack_delay+'d10;
//                JVM_C_Stack_miss <= JVM_C_Stack_miss+'d1;
//            end
//            if (memory_fetch) begin
//                if (~MMS_cache_hit3) begin
//                    MMS_memory_delay <= MMS_memory_delay+'d10;
//                    MMS_cache[MMS_cache_write_addr2] <= {line_memory_addr, `log_call_stack_depth'd0, 10'd0};
//                end
//                JVS_CCDS_memory_delay <= JVS_CCDS_memory_delay+'d10;
//            end
//        end
//    end

    always @(*) begin
        if (pipe1_work_state == 2'b11) begin
//            $display("count block = %0d, count total = %0d", count_block, count_total);
//            $display("clk_cnt = %0d", clk_cnt);
//            $display("max_pointer = %0d", max_stack_depth);
//            $display("MMS_O_Stack_delay = %0d", MMS_O_Stack_delay);
//            $display("MMS_C_Stack_delay = %0d", MMS_C_Stack_delay);
//            $display("MMS_O_Stack_miss = %0d", MMS_O_Stack_miss);
//            $display("MMS_C_Stack_miss = %0d", MMS_C_Stack_miss);
//            $display("MMS_Memory_delay = %0d", MMS_memory_delay);
//            $display("JVS_O_Stack_delay = %0d", JVS_O_Stack_delay);
//            $display("JVS_C_Stack_delay = %0d", JVS_C_Stack_delay);
//            $display("JVS_O_Stack_miss = %0d", JVM_O_Stack_miss);
//            $display("JVS_C_Stack_miss = %0d", JVM_C_Stack_miss);
//            $display("JVS_CCDS_memory_delay = %0d", JVS_CCDS_memory_delay);
//            $display("CCDS_O_Stack_delay = %0d", CCDS_O_Stack_delay);
//            $display("CCDS_C_Stack_delay = %0d", CCDS_C_Stack_delay);
//            $display("CCDS_O_Stack_miss = %0d", DSC_O_Stack_miss);
//            $display("CCDS_C_Stack_miss = %0d", DSC_C_Stack_miss);

            #5 i_line_mem_rd_addr = 9'h100;
            #2 $display("global[0] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);
                i_line_mem_rd_addr = 9'h101;
            #2 $display("global[1] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h102;     
            #2 $display("global[2] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h103;     
            #2 $display("global[3] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h104;     
            #2 $display("global[4] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h105;     
            #2 $display("global[5] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h106;     
            #2 $display("global[6] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h107;     
            #2 $display("global[7] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h108;     
            #2 $display("global[8] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h109;     
            #2 $display("global[9] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h000;     
            #2 $display("out_mem[0] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);      
                i_line_mem_rd_addr = 9'h001;     
            #2 $display("out_mem[1] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);         
                i_line_mem_rd_addr = 9'h002;     
            #2 $display("out_mem[2] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);  
                i_line_mem_rd_addr = 9'h003;     
            #2 $display("out_mem[3] = %0d", $signed(o_line_mem_rd_data));      
                i_line_mem_rd_addr = 9'h004;     
            #2 $display("out_mem[4] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h005;     
            #2 $display("out_mem[5] = %0d", $signed(o_line_mem_rd_data));    
                i_line_mem_rd_addr = 9'h006;     
            #2 $display("out_mem[6] = %0d", $signed(o_line_mem_rd_data));     
                i_line_mem_rd_addr = 9'h007;     
            #2 $display("out_mem[7] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h008;     
            #2 $display("out_mem[8] = %0d", $signed(o_line_mem_rd_data));         
                i_line_mem_rd_addr = 9'h009;     
            #2 $display("out_mem[9] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h00a;     
            #2 $display("out_mem[10] = %0d", $signed(o_line_mem_rd_data));       
            #8 $display("out_mem[11] = %0d", $signed(o_line_mem_rd_data));  
               i_line_mem_rd_addr = 9'h00c;   
            #8 $display("out_mem[12] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h00d;
            #8 $display("out_mem[13] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h00e;     
            #8 $display("out_mem[14] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h00f;     
            #8 $display("out_mem[15] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h010;   
            #8 $display("out_mem[16] = %0d", $signed(o_line_mem_rd_data));
               i_line_mem_rd_addr = 9'h011;   
            #8 $display("out_mem[17] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h012;
            #8 $display("out_mem[18] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h013;
            #8 $display("out_mem[19] = %0d", $signed(o_line_mem_rd_data));
            i_line_mem_rd_addr = 9'h014;
            #8 $display("out_mem[20] = %0d", $signed(o_line_mem_rd_data));
            i_line_mem_rd_addr = 9'h015;
            #8 $display("out_mem[21] = %0d", $signed(o_line_mem_rd_data));
            i_line_mem_rd_addr = 9'h016;
            #8 $display("out_mem[22] = %0d", $signed(o_line_mem_rd_data));
            i_line_mem_rd_addr = 9'h017;
            #8 $display("out_mem[23] = %0d", $signed(o_line_mem_rd_data));
            
            #10 $finish;


            #10 $finish;
        end
    end        
    initial begin
        #1000000;
        $display("Time expired, 1000000");
        $finish;
    end
            
endmodule



// #20 $display("memory read out = %d", o_line_mem_rd_data);