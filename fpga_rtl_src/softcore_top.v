`timescale 1ns / 1ps
`include "wasm_defines.vh"

module softcore_top(
        input        i_sys_clk_p,
        input        i_sys_clk_n,
        input        i_sys_rst,
        output [3:0] o_led,
        input        i_uart_rx,
        output       o_uart_tx
    );

        localparam UART_CLK_FREQ_MHz = 50;
        localparam BAUD_RATE = 115200;

        localparam DEBUG_IDLE   = 2'd0;
        localparam DEBUG_SEND   = 2'd1;
        localparam DEBUG_DONE   = 2'd2;

        localparam RX_IDLE      = 2'd0;
        localparam RX_FUNC      = 2'd1;
        localparam RX_PARAM     = 2'd2;

        localparam TX_IDLE      = 2'd0;
        localparam TX_ACK       = 2'd1;
        localparam TX_RESULT    = 2'd2;
        localparam TX_GLOBAL    = 2'd3;

        localparam CMD_EXEC_I64 = 8'hF1;
        localparam CMD_SEND_GLOBAL = 8'hF2;
        localparam ACK_READY    = 8'hA5;
        localparam ACK_BUSY     = 8'h5A;
        localparam ACK_SEND_GLOBAL = 8'hA6;

        wire clk;
        wire rst_n;
        wire sys_rstn;

        wire [1:0] comm_state;
        wire [7:0] rx_data;
        wire rx_data_valid;
        wire rx_data_ready;
        reg [7:0] tx_data;
        reg tx_data_valid;
        wire tx_data_ready;

        wire [`instr_read_width-1:0] instr_wr;
        wire instr_wr_valid;
        reg [`instr_read_width-1:0] instr_record [0:1023];
        reg [31:0] instr_count;

        wire [2:0] o_ERROR;
        wire [1:0] o_work_state;
        wire o_instr_mem_wr_rdy;
        reg i_instr_mem_write_finish;
        reg i_line_mem_rd_rdy;
        reg [`log_instr_mem_depth-1:0] i_line_mem_rd_addr;
        wire [`WIDTH-1:0] o_line_mem_rd_data;

        reg [31:0] global_record [9:0];
        reg [1:0] read_enable;

        reg [3:0] debug_state;
        reg [7:0] tx_cnt;
        reg [7:0] tx_debug_byte;

        reg wasm_rst_n;
        reg wasm_exec_mode;
        reg [(`log_func_num_max-1):0] exec_func_idx;
        reg exec_param_vld;
        reg [63:0] exec_param_data;
        wire [63:0] exec_result_data;
        wire exec_result_vld;

        reg [1:0] cmd_rx_state;
        reg [2:0] cmd_param_byte_idx;
        reg [63:0] cmd_param_shift;
        reg exec_running;
        reg exec_launch_pending;
        reg [1:0] exec_rst_cnt;
        reg exec_result_vld_d;
        reg exec_result_sent;

        reg [1:0] cmd_tx_state;
        reg [2:0] cmd_tx_byte_idx;
        reg [63:0] cmd_tx_result_shift;
        reg [6:0] cmd_tx_global_byte_idx;
        reg [7:0] pending_ack;
        reg ack_pending;
        reg ack_request;
        reg [7:0] ack_request_data;
        reg global_dump_pending;
        reg global_dump_request;
        reg [7:0] tx_global_byte;

        assign sys_rstn = i_sys_rst;
        assign rst_n = sys_rstn;
        assign rx_data_ready = 1'b1;
        assign o_led[3:2] = comm_state;
        assign o_led[1:0] = o_work_state;

        clk_wiz_0 u_clk_wiz_0(
            .clk_in1_p(i_sys_clk_p),
            .clk_in1_n(i_sys_clk_n),
            .clk_out1(clk)
        );

        WASM_TOP u_WASM_TOP(
            .i_clk(clk),
            .i_rst_n(wasm_rst_n),
            .i_exec_mode(wasm_exec_mode),
            .i_exec_func_idx(exec_func_idx),
            .i_exec_param_vld(exec_param_vld),
            .i_exec_param_data(exec_param_data),
            .o_ERROR(o_ERROR),
            .o_work_state(o_work_state),
            .o_exec_result(exec_result_data),
            .o_exec_result_vld(exec_result_vld),
            .i_line_mem_rd_rdy(i_line_mem_rd_rdy),
            .i_line_mem_rd_addr(i_line_mem_rd_addr),
            .o_line_mem_rd_data(o_line_mem_rd_data),
            .o_instr_mem_wr_rdy(o_instr_mem_wr_rdy),
            .i_instr_mem_wr_vld(instr_wr_valid),
            .i_instr_mem_wr_addr(instr_count[14:0]),
            .i_instr_mem_wr_data(instr_wr),
            .i_instr_mem_wr_finish(i_instr_mem_write_finish),
            .i_scl(1'b1),
            .i_sda(1'b1),
            .o_sda(),
            .i_debug_ena(1'b0)
        );

        uart_rx_instr u_uart_rx_instr(
            .clk(clk),
            .rst_n(rst_n),
            .rx_data(rx_data),
            .rx_valid(rx_data_valid),
            .comm_stat(comm_state),
            .instr_wr(instr_wr),
            .instr_wr_valid(instr_wr_valid)
        );

        UART #(.CLK_FREQ_MHz(UART_CLK_FREQ_MHz), .BAUD_RATE(BAUD_RATE)) u_UART(
            .i_clk(clk),
            .i_rstn(sys_rstn),
            .o_rx_data(rx_data),
            .o_rx_data_valid(rx_data_valid),
            .i_rx_data_ready(rx_data_ready),
            .i_rx_pin(i_uart_rx),
            .i_tx_data(tx_data),
            .i_tx_data_valid(tx_data_valid),
            .o_tx_data_ready(tx_data_ready),
            .o_tx_pin(o_uart_tx)
        );

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                i_instr_mem_write_finish <= 1'b0;
            end else if (comm_state == 2'b10) begin
                i_instr_mem_write_finish <= 1'b1;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                i_line_mem_rd_rdy <= 1'b0;
            end else if (o_work_state == 2'b11) begin
                i_line_mem_rd_rdy <= 1'b1;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                read_enable <= 2'b00;
            end else if (o_work_state == 2'b11) begin
                read_enable <= read_enable + 2'b01;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                i_line_mem_rd_addr <= 9'h100;
            end else if (read_enable == 2'b11) begin
                if (i_line_mem_rd_addr < 9'h109) begin
                    i_line_mem_rd_addr <= i_line_mem_rd_addr + 9'h1;
                end
                global_record[i_line_mem_rd_addr - 9'h100] <= o_line_mem_rd_data;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                instr_count <= 31'd0;
            end else if (instr_wr_valid) begin
                instr_record[instr_count] <= instr_wr;
                instr_count <= instr_count + 31'd1;
            end
        end

        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                wasm_rst_n <= 1'b0;
                wasm_exec_mode <= 1'b0;
                exec_func_idx <= {`log_func_num_max{1'b0}};
                exec_param_vld <= 1'b0;
                exec_param_data <= 64'd0;
                cmd_rx_state <= RX_IDLE;
                cmd_param_byte_idx <= 3'd0;
                cmd_param_shift <= 64'd0;
                exec_running <= 1'b0;
                exec_launch_pending <= 1'b0;
                exec_rst_cnt <= 2'd0;
                exec_result_vld_d <= 1'b0;
                ack_request <= 1'b0;
                ack_request_data <= 8'd0;
                global_dump_request <= 1'b0;
            end else begin
                wasm_rst_n <= 1'b1;
                exec_param_vld <= 1'b0;
                exec_result_vld_d <= exec_result_vld;
                ack_request <= 1'b0;
                global_dump_request <= 1'b0;

                if (exec_rst_cnt != 2'd0) begin
                    wasm_rst_n <= 1'b0;
                    exec_rst_cnt <= exec_rst_cnt - 2'd1;
                end else if (exec_launch_pending) begin
                    exec_param_vld <= 1'b1;
                    exec_launch_pending <= 1'b0;
                end

                if (exec_result_vld && !exec_result_vld_d) begin
                    exec_running <= 1'b0;
                end

                if (comm_state == 2'b10 && rx_data_valid) begin
                    case (cmd_rx_state)
                        RX_IDLE: begin
                            if (rx_data == CMD_EXEC_I64) begin
                                if (exec_running) begin
                                    ack_request <= 1'b1;
                                    ack_request_data <= ACK_BUSY;
                                end else begin
                                    cmd_rx_state <= RX_FUNC;
                                end
                            end else if (rx_data == CMD_SEND_GLOBAL) begin
                                if (exec_running) begin
                                    ack_request <= 1'b1;
                                    ack_request_data <= ACK_BUSY;
                                end else begin
                                    ack_request <= 1'b1;
                                    ack_request_data <= ACK_SEND_GLOBAL;
                                    global_dump_request <= 1'b1;
                                end
                            end
                        end
                        RX_FUNC: begin
                            exec_func_idx <= rx_data[`log_func_num_max-1:0];
                            cmd_param_byte_idx <= 3'd0;
                            cmd_param_shift <= 64'd0;
                            cmd_rx_state <= RX_PARAM;
                        end
                        RX_PARAM: begin
                            cmd_param_shift <= {cmd_param_shift[55:0], rx_data};
                            if (cmd_param_byte_idx == 3'd7) begin
                                exec_param_data <= {cmd_param_shift[55:0], rx_data};
                                exec_running <= 1'b1;
                                exec_launch_pending <= 1'b1;
                                wasm_exec_mode <= 1'b1;
                                exec_rst_cnt <= 2'd2;
                                ack_request <= 1'b1;
                                ack_request_data <= ACK_READY;
                                cmd_rx_state <= RX_IDLE;
                            end else begin
                                cmd_param_byte_idx <= cmd_param_byte_idx + 3'd1;
                            end
                        end
                        default: begin
                            cmd_rx_state <= RX_IDLE;
                        end
                    endcase
                end
            end
        end

        always @(*) begin
            case(tx_cnt)
                8'd0:  tx_debug_byte = instr_record[0][7:0];
                8'd1:  tx_debug_byte = instr_record[0][15:8];
                8'd2:  tx_debug_byte = instr_record[0][23:16];
                8'd3:  tx_debug_byte = instr_record[0][31:24];
                8'd4:  tx_debug_byte = instr_record[0][39:32];
                8'd5:  tx_debug_byte = instr_record[0][47:40];
                8'd6:  tx_debug_byte = instr_record[0][55:48];
                8'd7:  tx_debug_byte = instr_record[0][63:56];
                8'd8:  tx_debug_byte = global_record[0][7:0];
                8'd9:  tx_debug_byte = global_record[0][15:8];
                8'd10: tx_debug_byte = global_record[0][23:16];
                8'd11: tx_debug_byte = global_record[0][31:24];
                8'd12: tx_debug_byte = global_record[1][7:0];
                8'd13: tx_debug_byte = global_record[1][15:8];
                8'd14: tx_debug_byte = global_record[1][23:16];
                8'd15: tx_debug_byte = global_record[1][31:24];
                default: tx_debug_byte = 8'd0;
            endcase
        end

        reg [7:0] global_send [9:0][7:0];
        genvar m, n;
        generate
            for (m=0; m<10; m=m+1) begin : gen_global
                for (n=0; n<8; n=n+1) begin : gen_global_outputs
                    always @(*) begin
                        case (global_record[m][n*4 +: 4])
                            4'h0: global_send[m][n] = 8'h30;
                            4'h1: global_send[m][n] = 8'h31;
                            4'h2: global_send[m][n] = 8'h32;
                            4'h3: global_send[m][n] = 8'h33;
                            4'h4: global_send[m][n] = 8'h34;
                            4'h5: global_send[m][n] = 8'h35;
                            4'h6: global_send[m][n] = 8'h36;
                            4'h7: global_send[m][n] = 8'h37;
                            4'h8: global_send[m][n] = 8'h38;
                            4'h9: global_send[m][n] = 8'h39;
                            4'hA: global_send[m][n] = 8'h41;
                            4'hB: global_send[m][n] = 8'h42;
                            4'hC: global_send[m][n] = 8'h43;
                            4'hD: global_send[m][n] = 8'h44;
                            4'hE: global_send[m][n] = 8'h45;
                            4'hF: global_send[m][n] = 8'h46;
                            default: global_send[m][n] = 8'h30;
                        endcase
                    end
                end
            end
        endgenerate

        always @(*) begin
            case (cmd_tx_global_byte_idx[3:0])
                4'd0: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][7];
                4'd1: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][6];
                4'd2: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][5];
                4'd3: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][4];
                4'd4: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][3];
                4'd5: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][2];
                4'd6: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][1];
                4'd7: tx_global_byte = global_send[cmd_tx_global_byte_idx / 7'd10][0];
                4'd8: tx_global_byte = 8'h0D;
                4'd9: tx_global_byte = 8'h0A;
                default: tx_global_byte = 8'd0;
            endcase
        end

        always @(posedge clk or negedge sys_rstn) begin
            if (~sys_rstn) begin
                tx_data <= 8'd0;
                tx_data_valid <= 1'b0;
                tx_cnt <= 8'd0;
                debug_state <= DEBUG_IDLE;
                cmd_tx_state <= TX_IDLE;
                cmd_tx_byte_idx <= 3'd0;
                cmd_tx_result_shift <= 64'd0;
                cmd_tx_global_byte_idx <= 7'd0;
                exec_result_sent <= 1'b0;
                pending_ack <= 8'd0;
                ack_pending <= 1'b0;
                global_dump_pending <= 1'b0;
            end else begin
                if (exec_result_vld && !exec_result_vld_d) begin
                    exec_result_sent <= 1'b0;
                end
                if (exec_launch_pending) begin
                    exec_result_sent <= 1'b0;
                end
                if (ack_request) begin
                    pending_ack <= ack_request_data;
                    ack_pending <= 1'b1;
                end
                if (global_dump_request) begin
                    global_dump_pending <= 1'b1;
                end
                case (cmd_tx_state)
                    TX_IDLE: begin
                        if (ack_pending) begin
                            tx_data <= pending_ack;
                            tx_data_valid <= 1'b1;
                            cmd_tx_state <= TX_ACK;
                        end else if (global_dump_pending) begin
                            cmd_tx_global_byte_idx <= 7'd1;
                            tx_data <= tx_global_byte;
                            tx_data_valid <= 1'b1;
                            cmd_tx_state <= TX_GLOBAL;
                        end else if (exec_result_vld && !exec_running && !exec_result_sent) begin
                            cmd_tx_result_shift <= exec_result_data;
                            tx_data <= exec_result_data[63:56];
                            tx_data_valid <= 1'b1;
                            cmd_tx_state <= TX_RESULT;
                        end else begin
                            case(debug_state)
                                DEBUG_IDLE: begin
                                    tx_data_valid <= 1'b0;
                                    if (comm_state[1]) begin
                                        debug_state <= DEBUG_SEND;
                                        tx_cnt <= 8'd0;
                                    end
                                end
                                DEBUG_SEND: begin
                                    tx_data <= tx_debug_byte;
                                    if (tx_data_valid && tx_data_ready && tx_cnt < 8'd15) begin
                                        tx_cnt <= tx_cnt + 8'd1;
                                    end else if (tx_data_valid && tx_data_ready) begin
                                        tx_cnt <= 8'd0;
                                        tx_data_valid <= 1'b0;
                                        debug_state <= DEBUG_DONE;
                                    end else if (!tx_data_valid) begin
                                        tx_data_valid <= 1'b1;
                                    end
                                end
                                DEBUG_DONE: begin
                                    tx_data_valid <= 1'b0;
                                end
                                default: begin
                                    debug_state <= DEBUG_IDLE;
                                end
                            endcase
                        end
                    end
                    TX_ACK: begin
                        if (tx_data_valid && tx_data_ready) begin
                            tx_data_valid <= 1'b0;
                            ack_pending <= 1'b0;
                            cmd_tx_state <= TX_IDLE;
                        end
                    end
                    TX_GLOBAL: begin
                        if (tx_data_valid && tx_data_ready) begin
                            if (cmd_tx_global_byte_idx == 7'd100) begin
                                tx_data_valid <= 1'b0;
                                cmd_tx_global_byte_idx <= 7'd0;
                                global_dump_pending <= 1'b0;
                                cmd_tx_state <= TX_IDLE;
                            end else begin
                                tx_data <= tx_global_byte;
                                cmd_tx_global_byte_idx <= cmd_tx_global_byte_idx + 7'd1;
                            end
                        end
                    end
                    TX_RESULT: begin
                        if (tx_data_valid && tx_data_ready) begin
                            if (cmd_tx_byte_idx == 3'd7) begin
                                tx_data_valid <= 1'b0;
                                exec_result_sent <= 1'b1;
                                cmd_tx_byte_idx <= 3'd0;
                                cmd_tx_state <= TX_IDLE;
                            end else begin
                                cmd_tx_byte_idx <= cmd_tx_byte_idx + 3'd1;
                                cmd_tx_result_shift <= {cmd_tx_result_shift[55:0], 8'd0};
                                tx_data <= cmd_tx_result_shift[55:48];
                            end
                        end
                    end
                    default: begin
                        cmd_tx_state <= TX_IDLE;
                    end
                endcase
            end
        end

endmodule
