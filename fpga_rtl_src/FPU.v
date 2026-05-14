(* use_dsp = "yes" *)
module FPU(
    input clk,
    input rst_n,
    input start,
    input [63:0] A,
    input [63:0] B,
    input [4:0] ALUControl,
    input length_mode,
    output [63:0] FPUResult,
    output result_vld
);

localparam [4:0] OP_ADD      = 5'b00000;
localparam [4:0] OP_SUB      = 5'b00001;
localparam [4:0] OP_ABS      = 5'b00010;
localparam [4:0] OP_NEG      = 5'b00011;
localparam [4:0] OP_EQ       = 5'b00110;
localparam [4:0] OP_GE       = 5'b01001;
localparam [4:0] OP_LT       = 5'b01011;
localparam [4:0] OP_GT       = 5'b01100;
localparam [4:0] OP_LE       = 5'b01101;
localparam [4:0] OP_NE       = 5'b01111;
localparam [4:0] OP_FLOOR    = 5'b10000;
localparam [4:0] OP_TRUNC    = 5'b10001;
localparam [4:0] OP_NEAREST  = 5'b10010;
localparam [4:0] OP_SQRT     = 5'b10011;
localparam [4:0] OP_MUL      = 5'b10101;
localparam [4:0] OP_DIV      = 5'b10110;
localparam [4:0] OP_MIN      = 5'b10111;
localparam [4:0] OP_CEIL     = 5'b11000;
localparam [4:0] OP_MAX      = 5'b11001;
localparam [4:0] OP_COPYSIGN = 5'b11010;

localparam [1:0] ST_IDLE      = 2'd0;
localparam [1:0] ST_WAIT_CORE = 2'd1;
localparam [1:0] ST_WAIT_F32  = 2'd2;
localparam [1:0] ST_WAIT_SQRT = 2'd3;

function is_nan64;
    input [63:0] value;
    begin
        is_nan64 = (value[62:52] == 11'h7ff) && (value[51:0] != 52'd0);
    end
endfunction

function is_nan32;
    input [31:0] value;
    begin
        is_nan32 = (value[30:23] == 8'hff) && (value[22:0] != 23'd0);
    end
endfunction

function is_zero64;
    input [63:0] value;
    begin
        is_zero64 = (value[62:0] == 63'd0);
    end
endfunction

function is_zero32;
    input [31:0] value;
    begin
        is_zero32 = (value[30:0] == 31'd0);
    end
endfunction

function less64;
    input [63:0] lhs;
    input [63:0] rhs;
    begin
        if (is_nan64(lhs) || is_nan64(rhs) || (is_zero64(lhs) && is_zero64(rhs))) begin
            less64 = 1'b0;
        end else if (lhs[63] != rhs[63]) begin
            less64 = lhs[63];
        end else if (lhs[63]) begin
            less64 = lhs[62:0] > rhs[62:0];
        end else begin
            less64 = lhs[62:0] < rhs[62:0];
        end
    end
endfunction

function less32;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        if (is_nan32(lhs) || is_nan32(rhs) || (is_zero32(lhs) && is_zero32(rhs))) begin
            less32 = 1'b0;
        end else if (lhs[31] != rhs[31]) begin
            less32 = lhs[31];
        end else if (lhs[31]) begin
            less32 = lhs[30:0] > rhs[30:0];
        end else begin
            less32 = lhs[30:0] < rhs[30:0];
        end
    end
endfunction

function equal64;
    input [63:0] lhs;
    input [63:0] rhs;
    begin
        if (is_nan64(lhs) || is_nan64(rhs)) begin
            equal64 = 1'b0;
        end else begin
            equal64 = (lhs == rhs) || (is_zero64(lhs) && is_zero64(rhs));
        end
    end
endfunction

function equal32;
    input [31:0] lhs;
    input [31:0] rhs;
    begin
        if (is_nan32(lhs) || is_nan32(rhs)) begin
            equal32 = 1'b0;
        end else begin
            equal32 = (lhs == rhs) || (is_zero32(lhs) && is_zero32(rhs));
        end
    end
endfunction

wire [31:0] A32 = A[31:0];
wire [31:0] B32 = B[31:0];
wire [63:0] A64 = A;
wire [63:0] B64 = B;
wire [63:0] A32_to_double;
wire [63:0] B32_to_double;
reg [63:0] simple_result;

float_to_double u_float_to_double_a(
    .input_a(A32),
    .output_z(A32_to_double)
);

float_to_double u_float_to_double_b(
    .input_a(B32),
    .output_z(B32_to_double)
);

wire [63:0] op_a_double = length_mode ? B64 : B32_to_double;
wire [63:0] op_b_double_raw = length_mode ? A64 : A32_to_double;
wire [63:0] op_b_double = (ALUControl == OP_SUB) ? {~op_b_double_raw[63], op_b_double_raw[62:0]} : op_b_double_raw;

reg [1:0] state;
reg pending_single;
reg [4:0] op_reg;
reg length_mode_reg;
reg [63:0] core_result_reg;
reg [63:0] start_a_reg;
reg [63:0] start_b_reg;
reg [12:0] sqrt_exp_reg;
reg [105:0] sqrt_radicand_shift_reg;
reg [107:0] sqrt_remainder_reg;
reg [52:0] sqrt_root_reg;
reg [5:0] sqrt_iter_reg;
reg result_vld_r;
reg [63:0] result_reg;

wire add_a_ack;
wire add_b_ack;
wire [63:0] add_z;
wire add_z_stb;
reg add_output_ack;

wire mul_a_ack;
wire mul_b_ack;
wire [63:0] mul_z;
wire mul_z_stb;
reg mul_output_ack;

wire div_a_ack;
wire div_b_ack;
wire [63:0] div_z;
wire div_z_stb;
reg div_output_ack;

wire conv_input_ack;
wire [31:0] conv_z;
wire conv_z_stb;
reg conv_output_ack;
integer norm_shift;
integer exp_unbiased;
reg [52:0] sqrt_mantissa_init;
reg [53:0] sqrt_root_rounded;
reg [52:0] sqrt_root_final;
reg [12:0] sqrt_exp_final;
reg sqrt_round_up;

(* use_dsp = "yes" *) wire [107:0] sqrt_trial_wire = {54'd0, sqrt_root_reg, 2'b01};
wire [107:0] sqrt_remainder_shift_wire = {sqrt_remainder_reg[105:0], sqrt_radicand_shift_reg[105:104]};
wire sqrt_remainder_ge_trial_wire = (sqrt_remainder_shift_wire >= sqrt_trial_wire);
(* use_dsp = "yes" *) wire [107:0] sqrt_remainder_sub_wire = sqrt_remainder_shift_wire - sqrt_trial_wire;
wire [107:0] sqrt_remainder_next_wire = sqrt_remainder_ge_trial_wire ? sqrt_remainder_sub_wire : sqrt_remainder_shift_wire;
wire [52:0] sqrt_root_next_wire = {sqrt_root_reg[51:0], sqrt_remainder_ge_trial_wire};
wire [108:0] sqrt_round_compare_lhs_wire = {sqrt_remainder_next_wire, 1'b0};
wire [108:0] sqrt_round_compare_rhs_wire = {{54'd0, sqrt_root_next_wire}, 1'b1};
(* use_dsp = "yes" *) wire [53:0] sqrt_root_rounded_inc_wire = {1'b0, sqrt_root_next_wire} + 54'd1;

wire core_done = (op_reg == OP_ADD || op_reg == OP_SUB) ? add_z_stb :
                 (op_reg == OP_MUL) ? mul_z_stb :
                 (op_reg == OP_DIV) ? div_z_stb : 1'b0;

wire [63:0] core_result_wire = (op_reg == OP_ADD || op_reg == OP_SUB) ? add_z :
                               (op_reg == OP_MUL) ? mul_z :
                               div_z;

(* use_dsp = "yes" *) double_adder u_double_adder(
    .input_a(start_a_reg),
    .input_b(start_b_reg),
    .input_a_stb(pending_single && (op_reg == OP_ADD || op_reg == OP_SUB)),
    .input_b_stb(pending_single && (op_reg == OP_ADD || op_reg == OP_SUB)),
    .output_z_ack(add_output_ack),
    .clk(clk),
    .rst(~rst_n),
    .output_z(add_z),
    .output_z_stb(add_z_stb),
    .input_a_ack(add_a_ack),
    .input_b_ack(add_b_ack)
);

(* use_dsp = "yes" *) double_multiplier u_double_multiplier(
    .input_a(start_a_reg),
    .input_b(start_b_reg),
    .input_a_stb(pending_single && (op_reg == OP_MUL)),
    .input_b_stb(pending_single && (op_reg == OP_MUL)),
    .output_z_ack(mul_output_ack),
    .clk(clk),
    .rst(~rst_n),
    .output_z(mul_z),
    .output_z_stb(mul_z_stb),
    .input_a_ack(mul_a_ack),
    .input_b_ack(mul_b_ack)
);

(* use_dsp = "yes" *) double_divider u_double_divider(
    .input_a(start_a_reg),
    .input_b(start_b_reg),
    .input_a_stb(pending_single && (op_reg == OP_DIV)),
    .input_b_stb(pending_single && (op_reg == OP_DIV)),
    .output_z_ack(div_output_ack),
    .clk(clk),
    .rst(~rst_n),
    .output_z(div_z),
    .output_z_stb(div_z_stb),
    .input_a_ack(div_a_ack),
    .input_b_ack(div_b_ack)
);

(* use_dsp = "yes" *) double_to_float u_double_to_float(
    .input_a(core_result_reg),
    .input_a_stb(state == ST_WAIT_F32),
    .output_z_ack(conv_output_ack),
    .clk(clk),
    .rst(~rst_n),
    .output_z(conv_z),
    .output_z_stb(conv_z_stb),
    .input_a_ack(conv_input_ack)
);

assign FPUResult = result_reg;
assign result_vld = result_vld_r;

always @(*) begin
    simple_result = 64'd0;

    if (length_mode) begin
        case (ALUControl)
            OP_ABS: simple_result = {1'b0, A64[62:0]};
            OP_NEG: simple_result = {~A64[63], A64[62:0]};
            OP_EQ: simple_result = {63'd0, equal64(B64, A64)};
            OP_NE: simple_result = {63'd0, ~equal64(B64, A64)};
            OP_LT: simple_result = {63'd0, less64(B64, A64)};
            OP_GT: simple_result = {63'd0, less64(A64, B64)};
            OP_LE: simple_result = {63'd0, less64(B64, A64) | equal64(B64, A64)};
            OP_GE: simple_result = {63'd0, less64(A64, B64) | equal64(B64, A64)};
            OP_CEIL, OP_FLOOR, OP_TRUNC, OP_NEAREST: simple_result = 64'h7ff8_0000_0000_0000;
            OP_MIN: begin
                if (is_nan64(A64) || is_nan64(B64)) begin
                    simple_result = 64'h7ff8_0000_0000_0000;
                end else if (is_zero64(A64) && is_zero64(B64)) begin
                    simple_result = A64[63] ? A64 : B64;
                end else begin
                    simple_result = less64(B64, A64) ? B64 : A64;
                end
            end
            OP_MAX: begin
                if (is_nan64(A64) || is_nan64(B64)) begin
                    simple_result = 64'h7ff8_0000_0000_0000;
                end else if (is_zero64(A64) && is_zero64(B64)) begin
                    simple_result = A64[63] ? B64 : A64;
                end else begin
                    simple_result = less64(B64, A64) ? A64 : B64;
                end
            end
            OP_COPYSIGN: simple_result = {A64[63], B64[62:0]};
            default: simple_result = 64'd0;
        endcase
    end else begin
        case (ALUControl)
            OP_ABS: simple_result = {32'd0, 1'b0, A32[30:0]};
            OP_NEG: simple_result = {32'd0, ~A32[31], A32[30:0]};
            OP_EQ: simple_result = {63'd0, equal32(B32, A32)};
            OP_NE: simple_result = {63'd0, ~equal32(B32, A32)};
            OP_LT: simple_result = {63'd0, less32(B32, A32)};
            OP_GT: simple_result = {63'd0, less32(A32, B32)};
            OP_LE: simple_result = {63'd0, less32(B32, A32) | equal32(B32, A32)};
            OP_GE: simple_result = {63'd0, less32(A32, B32) | equal32(B32, A32)};
            OP_CEIL, OP_FLOOR, OP_TRUNC, OP_NEAREST: simple_result = {32'd0, 32'h7fc0_0000};
            OP_MIN: begin
                if (is_nan32(A32) || is_nan32(B32)) begin
                    simple_result = {32'd0, 32'h7fc0_0000};
                end else if (is_zero32(A32) && is_zero32(B32)) begin
                    simple_result = {32'd0, (A32[31] ? A32 : B32)};
                end else begin
                    simple_result = {32'd0, (less32(B32, A32) ? B32 : A32)};
                end
            end
            OP_MAX: begin
                if (is_nan32(A32) || is_nan32(B32)) begin
                    simple_result = {32'd0, 32'h7fc0_0000};
                end else if (is_zero32(A32) && is_zero32(B32)) begin
                    simple_result = {32'd0, (A32[31] ? B32 : A32)};
                end else begin
                    simple_result = {32'd0, (less32(B32, A32) ? A32 : B32)};
                end
            end
            OP_COPYSIGN: simple_result = {32'd0, A32[31], B32[30:0]};
            default: simple_result = 64'd0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= ST_IDLE;
        pending_single <= 1'b0;
        op_reg <= 5'd0;
        length_mode_reg <= 1'b0;
        core_result_reg <= 64'd0;
        start_a_reg <= 64'd0;
        start_b_reg <= 64'd0;
        sqrt_exp_reg <= 13'd0;
        sqrt_radicand_shift_reg <= 106'd0;
        sqrt_remainder_reg <= 108'd0;
        sqrt_root_reg <= 53'd0;
        sqrt_iter_reg <= 6'd0;
        result_vld_r <= 1'b0;
        result_reg <= 64'd0;
        add_output_ack <= 1'b0;
        mul_output_ack <= 1'b0;
        div_output_ack <= 1'b0;
        conv_output_ack <= 1'b0;
    end else begin
        result_vld_r <= 1'b0;
        add_output_ack <= 1'b0;
        mul_output_ack <= 1'b0;
        div_output_ack <= 1'b0;
        conv_output_ack <= 1'b0;

        case (state)
            ST_IDLE: begin
                pending_single <= 1'b0;
                if (start) begin
                    if (ALUControl == OP_ADD || ALUControl == OP_SUB || ALUControl == OP_MUL || ALUControl == OP_DIV) begin
                        start_a_reg <= op_a_double;
                        start_b_reg <= op_b_double;
                        op_reg <= ALUControl;
                        length_mode_reg <= length_mode;
                        pending_single <= 1'b1;
                        state <= ST_WAIT_CORE;
                    end else if (ALUControl == OP_SQRT) begin
                        op_reg <= ALUControl;
                        length_mode_reg <= length_mode;
                        start_a_reg <= length_mode ? A64 : A32_to_double;
                        if (is_nan64(length_mode ? A64 : A32_to_double)) begin
                            core_result_reg <= 64'h7ff8_0000_0000_0000;
                            if (length_mode) begin
                                result_reg <= 64'h7ff8_0000_0000_0000;
                                result_vld_r <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_F32;
                            end
                        end else if ((length_mode ? A64[63] : A32_to_double[63]) && ~is_zero64(length_mode ? A64 : A32_to_double)) begin
                            core_result_reg <= 64'h7ff8_0000_0000_0000;
                            if (length_mode) begin
                                result_reg <= 64'h7ff8_0000_0000_0000;
                                result_vld_r <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_F32;
                            end
                        end else if ((length_mode ? A64[62:52] : A32_to_double[62:52]) == 11'h7ff) begin
                            core_result_reg <= length_mode ? A64 : A32_to_double;
                            if (length_mode) begin
                                result_reg <= length_mode ? A64 : A32_to_double;
                                result_vld_r <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_F32;
                            end
                        end else if (is_zero64(length_mode ? A64 : A32_to_double)) begin
                            core_result_reg <= length_mode ? A64 : A32_to_double;
                            if (length_mode) begin
                                result_reg <= length_mode ? A64 : A32_to_double;
                                result_vld_r <= 1'b1;
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_WAIT_F32;
                            end
                        end else begin
                            if ((length_mode ? A64[62:52] : A32_to_double[62:52]) == 11'd0) begin
                                sqrt_mantissa_init = {1'b0, (length_mode ? A64[51:0] : A32_to_double[51:0])};
                                exp_unbiased = -1022;
                                norm_shift = 0;
                                while ((sqrt_mantissa_init[52] == 1'b0) && (norm_shift < 53)) begin
                                    sqrt_mantissa_init = sqrt_mantissa_init << 1;
                                    exp_unbiased = exp_unbiased - 1;
                                    norm_shift = norm_shift + 1;
                                end
                            end else begin
                                sqrt_mantissa_init = {1'b1, (length_mode ? A64[51:0] : A32_to_double[51:0])};
                                exp_unbiased = (length_mode ? A64[62:52] : A32_to_double[62:52]) - 1023;
                            end

                            if (exp_unbiased[0] != 0) begin
                                sqrt_mantissa_init = sqrt_mantissa_init << 1;
                                exp_unbiased = exp_unbiased - 1;
                            end

                            sqrt_exp_reg <= (exp_unbiased >>> 1) + 1023;
                            sqrt_radicand_shift_reg <= {sqrt_mantissa_init, 53'd0};
                            sqrt_remainder_reg <= 108'd0;
                            sqrt_root_reg <= 53'd0;
                            sqrt_iter_reg <= 6'd53;
                            state <= ST_WAIT_SQRT;
                        end
                    end
                end
            end
            ST_WAIT_CORE: begin
                pending_single <= 1'b0;
                if (core_done) begin
                    core_result_reg <= core_result_wire;
                    if (op_reg == OP_ADD || op_reg == OP_SUB) begin
                        add_output_ack <= 1'b1;
                    end else if (op_reg == OP_MUL) begin
                        mul_output_ack <= 1'b1;
                    end else begin
                        div_output_ack <= 1'b1;
                    end

                    if (length_mode_reg) begin
                        result_reg <= core_result_wire;
                        result_vld_r <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        state <= ST_WAIT_F32;
                    end
                end
            end
            ST_WAIT_F32: begin
                if (conv_z_stb) begin
                    conv_output_ack <= 1'b1;
                    result_reg <= {32'd0, conv_z};
                    result_vld_r <= 1'b1;
                    state <= ST_IDLE;
                end
            end
            ST_WAIT_SQRT: begin
                sqrt_remainder_reg <= sqrt_remainder_next_wire;
                sqrt_root_reg <= sqrt_root_next_wire;
                sqrt_radicand_shift_reg <= {sqrt_radicand_shift_reg[103:0], 2'b00};
                sqrt_iter_reg <= sqrt_iter_reg - 1'b1;

                if (sqrt_iter_reg == 6'd1) begin
                    sqrt_round_up = (sqrt_round_compare_lhs_wire > sqrt_round_compare_rhs_wire) ||
                                    ((sqrt_round_compare_lhs_wire == sqrt_round_compare_rhs_wire) &&
                                     sqrt_root_next_wire[0]);

                    sqrt_root_rounded = {1'b0, sqrt_root_next_wire};
                    if (sqrt_round_up) begin
                        sqrt_root_rounded = sqrt_root_rounded_inc_wire;
                    end

                    sqrt_exp_final = sqrt_exp_reg;
                    if (sqrt_root_rounded[53]) begin
                        sqrt_root_final = sqrt_root_rounded[53:1];
                        sqrt_exp_final = sqrt_exp_reg + 1'b1;
                    end else begin
                        sqrt_root_final = sqrt_root_rounded[52:0];
                    end

                    core_result_reg <= {1'b0, sqrt_exp_final[10:0], sqrt_root_final[51:0]};
                    if (length_mode_reg) begin
                        result_reg <= {1'b0, sqrt_exp_final[10:0], sqrt_root_final[51:0]};
                        result_vld_r <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        state <= ST_WAIT_F32;
                    end
                end
            end
            default: begin
                state <= ST_IDLE;
            end
        endcase
    end
end

endmodule
