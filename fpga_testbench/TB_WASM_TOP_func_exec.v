`timescale 1ns / 1ps
`include "../fpga_rtl_src/wasm_defines.vh"

module TB_WASM_TOP_func_exec;

    localparam CLK_PERIOD = 10;
    localparam HEX_BYTE_COUNT = 708;
    localparam WORD_COUNT = (HEX_BYTE_COUNT + `read_window_size - 1) / `read_window_size;
    localparam TEST_FUNC_IDX = 6'd1;
    localparam TEST_PARAM = 64'd5;
    localparam EXPECTED_RESULT = 64'd120;

    reg clk;
    reg rst_n;

    reg i_exec_mode;
    reg [(`log_func_num_max-1):0] i_exec_func_idx;
    reg i_exec_param_vld;
    reg [63:0] i_exec_param_data;

    wire [2:0] o_ERROR;
    wire [1:0] o_work_state;
    wire [63:0] o_exec_result;
    wire o_exec_result_vld;

    reg i_line_mem_rd_rdy;
    reg [8:0] i_line_mem_rd_addr;
    wire [63:0] o_line_mem_rd_data;

    wire o_instr_mem_wr_rdy;
    reg i_instr_mem_wr_vld;
    reg [9:0] i_instr_mem_wr_addr;
    reg [`instr_read_width-1:0] i_instr_mem_wr_data;
    reg i_instr_mem_wr_finish;

    reg [7:0] bram [0:HEX_BYTE_COUNT-1];
    integer word_idx;
    integer base_idx;

    always #(CLK_PERIOD/2) clk = ~clk;

    WASM_TOP dut (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_exec_mode(i_exec_mode),
        .i_exec_func_idx(i_exec_func_idx),
        .i_exec_param_vld(i_exec_param_vld),
        .i_exec_param_data(i_exec_param_data),
        .o_ERROR(o_ERROR),
        .o_work_state(o_work_state),
        .o_exec_result(o_exec_result),
        .o_exec_result_vld(o_exec_result_vld),
        .i_line_mem_rd_rdy(i_line_mem_rd_rdy),
        .i_line_mem_rd_addr(i_line_mem_rd_addr),
        .o_line_mem_rd_data(o_line_mem_rd_data),
        .o_instr_mem_wr_rdy(o_instr_mem_wr_rdy),
        .i_instr_mem_wr_vld(i_instr_mem_wr_vld),
        .i_instr_mem_wr_addr(i_instr_mem_wr_addr),
        .i_instr_mem_wr_data(i_instr_mem_wr_data),
        .i_instr_mem_wr_finish(i_instr_mem_wr_finish),
        .i_scl(1'b1),
        .i_sda(1'b1),
        .o_sda(),
        .i_debug_ena(1'b0)
    );

    task automatic drive_instr_word(input integer idx);
        integer byte_addr;
        reg [87:0] assembled_word;
        begin
            assembled_word = 88'd0;
            base_idx = idx * `read_window_size;
            for (byte_addr = 0; byte_addr < `read_window_size; byte_addr = byte_addr + 1) begin
                if ((base_idx + byte_addr) < HEX_BYTE_COUNT) begin
                    assembled_word[byte_addr*8 +: 8] = bram[base_idx + byte_addr];
                end else begin
                    assembled_word[byte_addr*8 +: 8] = 8'd0;
                end
            end

            @(posedge clk);
            i_instr_mem_wr_vld <= 1'b1;
            i_instr_mem_wr_addr <= idx[9:0];
            i_instr_mem_wr_data <= assembled_word;
        end
    endtask

    initial begin
        $readmemh("user_code/factorial.hex", bram);

        clk = 1'b0;
        rst_n = 1'b0;
        i_exec_mode = 1'b0;
        i_exec_func_idx = {`log_func_num_max{1'b0}};
        i_exec_param_vld = 1'b0;
        i_exec_param_data = 64'd0;
        i_line_mem_rd_rdy = 1'b0;
        i_line_mem_rd_addr = 9'd0;
        i_instr_mem_wr_vld = 1'b0;
        i_instr_mem_wr_addr = 10'd0;
        i_instr_mem_wr_data = {`instr_read_width{1'b0}};
        i_instr_mem_wr_finish = 1'b0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        for (word_idx = 0; word_idx < WORD_COUNT; word_idx = word_idx + 1) begin
            drive_instr_word(word_idx);
        end

        @(posedge clk);
        i_instr_mem_wr_vld <= 1'b0;
        i_instr_mem_wr_data <= {`instr_read_width{1'b0}};
        i_instr_mem_wr_finish <= 1'b1;

        repeat (8) @(posedge clk);

        i_exec_mode <= 1'b1;
        i_exec_func_idx <= TEST_FUNC_IDX;
        rst_n <= 1'b0;
        repeat (4) @(posedge clk);
        rst_n <= 1'b1;

        repeat (4) @(posedge clk);
        i_exec_param_data <= TEST_PARAM;
        i_exec_param_vld <= 1'b1;
        @(posedge clk);
        i_exec_param_vld <= 1'b0;

        wait (o_exec_result_vld == 1'b1);
        @(posedge clk);

        $display("Function mode result = %0d", o_exec_result);
        if (o_exec_result !== EXPECTED_RESULT) begin
            $display("TEST FAILED: expected %0d, got %0d", EXPECTED_RESULT, o_exec_result);
            $stop;
        end

        if (o_ERROR !== 3'b000) begin
            $display("TEST FAILED: o_ERROR = %b", o_ERROR);
            $stop;
        end

        $display("TEST PASSED: func %0d(%0d) = %0d", TEST_FUNC_IDX, TEST_PARAM, o_exec_result);
        $finish;
    end

endmodule
