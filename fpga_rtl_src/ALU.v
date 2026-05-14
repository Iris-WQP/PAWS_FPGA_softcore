// `timescale 1ns / 1ps
`include "wasm_defines.vh"
module ALU(
input clk,
input rst_n,
input start,
input [`st_width-1:0] A,
input [`st_width-1:0] B,
input [`st_width-1:0] C,
input [4:0] ALUControl,
input length_mode, // 0: 32-bit, 1: 64-bit
output [`WIDTH-1:0] ALUResult,
output busy,
output result_vld
);

localparam [4:0] OP_MUL   = 5'b10101;
localparam [4:0] OP_DIV_S = 5'b10110;
localparam [4:0] OP_DIV_U = 5'b10111;
localparam [4:0] OP_REM_S = 5'b11001;
localparam [4:0] OP_REM_U = 5'b11010;

localparam [1:0] ST_IDLE = 2'd0;
localparam [1:0] ST_MUL  = 2'd1;
localparam [1:0] ST_DIV  = 2'd2;

function [63:0] abs_u64;
    input [63:0] value;
    begin
        abs_u64 = value[63] ? (~value + 64'd1) : value;
    end
endfunction

wire multi_cycle_op = (ALUControl == OP_MUL) |
                      (ALUControl == OP_DIV_S) |
                      (ALUControl == OP_DIV_U) |
                      (ALUControl == OP_REM_S) |
                      (ALUControl == OP_REM_U);

wire [31:0] A_32b = A[31:0];
wire [31:0] B_32b = B[31:0];
wire [31:0] C_32b = C[31:0];
wire [31:0] ALUResult_32b;
wire busy_32b;
wire result_vld_32b;

reg [63:0] simple_result_64b;
reg C_out;
reg [64:0] sum;
wire [63:0] eqz = {63'd0, (A == 64'd0)};
wire [63:0] eq = {63'd0, (A == B)};
wire [63:0] ne = {63'd0, ~(A == B)};
wire [63:0] lt_u = {63'd0, (B < A)};
wire [63:0] gt_u = {63'd0, (B > A)};
wire [63:0] lt_s = {63'd0, ($signed(B) < $signed(A))};
wire [63:0] gt_s = {63'd0, ($signed(B) > $signed(A))};
wire [1:0] popcnt64_l0 [31:0];
wire [2:0] popcnt64_l1 [15:0];
wire [3:0] popcnt64_l2 [7:0];
wire [4:0] popcnt64_l3 [3:0];
wire [5:0] popcnt64_l4 [1:0];
wire [6:0] popcnt64_total;

reg [63:0] multi_result_64b;
reg busy_64b;
reg result_vld_64b;
reg [1:0] state_64b;
reg [6:0] iter_count_64b;

reg [63:0] mul_a_reg_64b;
reg [63:0] mul_b_reg_64b;
(* use_dsp = "yes" *) wire [127:0] mul_product_dsp_64b = mul_a_reg_64b * mul_b_reg_64b;

reg [63:0] div_dividend_shift_64b;
reg [63:0] div_divisor_mag_64b;
reg [63:0] div_quotient_64b;
reg [64:0] div_remainder_64b;
reg div_signed_64b;
reg div_return_remainder_64b;
reg div_neg_quotient_64b;
reg div_neg_remainder_64b;

reg [64:0] div_trial_64b;
reg [64:0] div_next_remainder_64b;
reg [63:0] div_next_quotient_64b;
reg [63:0] signed_div_result_64b;
reg [63:0] signed_rem_result_64b;

genvar popcnt64_idx;
generate
    for (popcnt64_idx = 0; popcnt64_idx < 32; popcnt64_idx = popcnt64_idx + 1) begin: gen_popcnt64_l0
        assign popcnt64_l0[popcnt64_idx] = A[2*popcnt64_idx] + A[2*popcnt64_idx + 1];
    end
    for (popcnt64_idx = 0; popcnt64_idx < 16; popcnt64_idx = popcnt64_idx + 1) begin: gen_popcnt64_l1
        assign popcnt64_l1[popcnt64_idx] = popcnt64_l0[2*popcnt64_idx] + popcnt64_l0[2*popcnt64_idx + 1];
    end
    for (popcnt64_idx = 0; popcnt64_idx < 8; popcnt64_idx = popcnt64_idx + 1) begin: gen_popcnt64_l2
        assign popcnt64_l2[popcnt64_idx] = popcnt64_l1[2*popcnt64_idx] + popcnt64_l1[2*popcnt64_idx + 1];
    end
    for (popcnt64_idx = 0; popcnt64_idx < 4; popcnt64_idx = popcnt64_idx + 1) begin: gen_popcnt64_l3
        assign popcnt64_l3[popcnt64_idx] = popcnt64_l2[2*popcnt64_idx] + popcnt64_l2[2*popcnt64_idx + 1];
    end
    for (popcnt64_idx = 0; popcnt64_idx < 2; popcnt64_idx = popcnt64_idx + 1) begin: gen_popcnt64_l4
        assign popcnt64_l4[popcnt64_idx] = popcnt64_l3[2*popcnt64_idx] + popcnt64_l3[2*popcnt64_idx + 1];
    end
endgenerate

assign popcnt64_total = popcnt64_l4[0] + popcnt64_l4[1];

assign busy = length_mode ? busy_64b : busy_32b;
assign result_vld = length_mode ? result_vld_64b : result_vld_32b;
assign ALUResult = length_mode ? (multi_cycle_op ? multi_result_64b : simple_result_64b)
                               : {{32{ALUResult_32b[31]}}, ALUResult_32b};

ALU_32bit u_alu_32bit(
    .clk(clk),
    .rst_n(rst_n),
    .start(start & (~length_mode)),
    .A(A_32b),
    .B(B_32b),
    .C(C_32b),
    .ALUControl(ALUControl),
    .ALUResult(ALUResult_32b),
    .busy(busy_32b),
    .result_vld(result_vld_32b)
);

always @(*) begin
    {C_out, sum} = (ALUControl[0]) ? (B + (~A) + 1'b1) : (A + B);
    case (ALUControl)
        5'b00000, 5'b00001: simple_result_64b = sum[63:0];
        5'b00010: simple_result_64b = A & B;
        5'b00011: simple_result_64b = A | B;
        5'b00100: simple_result_64b = eqz[0] ? B : C;
        5'b00101: simple_result_64b = eqz;
        5'b00110: simple_result_64b = eq;
        5'b00111: simple_result_64b = lt_u;
        5'b01000: simple_result_64b = gt_u;
        5'b01001: simple_result_64b = lt_u | eq;
        5'b01010: simple_result_64b = gt_u | eq;
        5'b01011: simple_result_64b = lt_s;
        5'b01100: simple_result_64b = gt_s;
        5'b01101: simple_result_64b = lt_s | eq;
        5'b01110: simple_result_64b = gt_s | eq;
        5'b01111: simple_result_64b = ne;
        5'b10000: simple_result_64b = B << A[5:0];
        5'b10001: simple_result_64b = $signed(B) >>> A[5:0];
        5'b10010: simple_result_64b = B >> A[5:0];
        5'b10011: simple_result_64b = (A[5:0] == 6'd0) ? B : ((B << A[5:0]) | (B >> (64 - A[5:0])));
        5'b10100: simple_result_64b = (A[5:0] == 6'd0) ? B : ((B >> A[5:0]) | (B << (64 - A[5:0])));
        5'b11000: simple_result_64b = A ^ B;
        5'b11011: simple_result_64b = {57'd0, popcnt64_total};
        default: simple_result_64b = 64'd0;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        multi_result_64b <= 64'd0;
        busy_64b <= 1'b0;
        result_vld_64b <= 1'b0;
        state_64b <= ST_IDLE;
        iter_count_64b <= 7'd0;
        mul_a_reg_64b <= 64'd0;
        mul_b_reg_64b <= 64'd0;
        div_dividend_shift_64b <= 64'd0;
        div_divisor_mag_64b <= 64'd0;
        div_quotient_64b <= 64'd0;
        div_remainder_64b <= 65'd0;
        div_signed_64b <= 1'b0;
        div_return_remainder_64b <= 1'b0;
        div_neg_quotient_64b <= 1'b0;
        div_neg_remainder_64b <= 1'b0;
    end else begin
        result_vld_64b <= 1'b0;

        if (start && length_mode && multi_cycle_op && (~busy_64b)) begin
            case (ALUControl)
                OP_MUL: begin
                    busy_64b <= 1'b1;
                    state_64b <= ST_MUL;
                    iter_count_64b <= 7'd1;
                    mul_a_reg_64b <= A;
                    mul_b_reg_64b <= B;
                end
                OP_DIV_S, OP_DIV_U, OP_REM_S, OP_REM_U: begin
                    div_signed_64b <= (ALUControl == OP_DIV_S) || (ALUControl == OP_REM_S);
                    div_return_remainder_64b <= (ALUControl == OP_REM_S) || (ALUControl == OP_REM_U);
                    div_neg_quotient_64b <= ((ALUControl == OP_DIV_S) || (ALUControl == OP_REM_S)) ? (A[63] ^ B[63]) : 1'b0;
                    div_neg_remainder_64b <= ((ALUControl == OP_DIV_S) || (ALUControl == OP_REM_S)) ? B[63] : 1'b0;
                    div_dividend_shift_64b <= ((ALUControl == OP_DIV_S) || (ALUControl == OP_REM_S)) ? abs_u64(B) : B;
                    div_divisor_mag_64b <= ((ALUControl == OP_DIV_S) || (ALUControl == OP_REM_S)) ? abs_u64(A) : A;
                    div_quotient_64b <= 64'd0;
                    div_remainder_64b <= 65'd0;

                    if (A == 64'd0) begin
                        multi_result_64b <= ((ALUControl == OP_REM_S) || (ALUControl == OP_REM_U)) ? B : 64'hFFFF_FFFF_FFFF_FFFF;
                        busy_64b <= 1'b0;
                        state_64b <= ST_IDLE;
                        iter_count_64b <= 7'd0;
                        result_vld_64b <= 1'b1;
                    end else if ((ALUControl == OP_DIV_S || ALUControl == OP_REM_S) &&
                                 (B == 64'h8000_0000_0000_0000) && (A == 64'hFFFF_FFFF_FFFF_FFFF)) begin
                        multi_result_64b <= (ALUControl == OP_REM_S) ? 64'd0 : 64'h8000_0000_0000_0000;
                        busy_64b <= 1'b0;
                        state_64b <= ST_IDLE;
                        iter_count_64b <= 7'd0;
                        result_vld_64b <= 1'b1;
                    end else begin
                        busy_64b <= 1'b1;
                        state_64b <= ST_DIV;
                        iter_count_64b <= 7'd64;
                    end
                end
                default: begin
                    busy_64b <= 1'b0;
                    state_64b <= ST_IDLE;
                end
            endcase
        end else if (busy_64b) begin
            case (state_64b)
                ST_MUL: begin
                    multi_result_64b <= mul_product_dsp_64b[63:0];
                    busy_64b <= 1'b0;
                    state_64b <= ST_IDLE;
                    result_vld_64b <= 1'b1;
                end
                ST_DIV: begin
                    div_trial_64b = {div_remainder_64b[63:0], div_dividend_shift_64b[63]};
                    if (div_trial_64b >= {1'b0, div_divisor_mag_64b}) begin
                        div_next_remainder_64b = div_trial_64b - {1'b0, div_divisor_mag_64b};
                        div_next_quotient_64b = {div_quotient_64b[62:0], 1'b1};
                    end else begin
                        div_next_remainder_64b = div_trial_64b;
                        div_next_quotient_64b = {div_quotient_64b[62:0], 1'b0};
                    end

                    div_remainder_64b <= div_next_remainder_64b;
                    div_quotient_64b <= div_next_quotient_64b;
                    div_dividend_shift_64b <= {div_dividend_shift_64b[62:0], 1'b0};
                    iter_count_64b <= iter_count_64b - 1'b1;

                    if (iter_count_64b == 7'd1) begin
                        if (div_signed_64b) begin
                            signed_div_result_64b = div_neg_quotient_64b ? (~div_next_quotient_64b + 64'd1) : div_next_quotient_64b;
                            signed_rem_result_64b = div_neg_remainder_64b ? (~div_next_remainder_64b[63:0] + 64'd1) : div_next_remainder_64b[63:0];
                            multi_result_64b <= div_return_remainder_64b ? signed_rem_result_64b : signed_div_result_64b;
                        end else begin
                            multi_result_64b <= div_return_remainder_64b ? div_next_remainder_64b[63:0] : div_next_quotient_64b;
                        end
                        busy_64b <= 1'b0;
                        state_64b <= ST_IDLE;
                        result_vld_64b <= 1'b1;
                    end
                end
                default: begin
                    busy_64b <= 1'b0;
                    state_64b <= ST_IDLE;
                end
            endcase
        end
    end
end

endmodule
