
module BlockCtrl(
    input clk,
    input rst_n,
    input ALUResult_0,
    input br_table_instr,
    input [(`instr_bram_width-1):0] br_table_depth,
    input end_instr,
    input br_if,
    input else_instr,
    input br_related,
    input function_call,
    input block_instr,
    input loop_instr,
    input if_instr,
    input cu_working,
    input [63:0] constant,
    output block_valid,
    output reg block_hold
  );

    //break control         
    reg [31:0] break_depth;
    wire break_depth_is_zero;
    // wire block_valid;   //when block vaild==0, operand stack and memory stop, no jump.
    wire br_if_true;
    wire block_hold_up;
    wire block_hold_down;
    wire control_stack_push; 
    //break control
    assign break_depth_is_zero = break_depth==32'd0;
    assign br_if_true = br_if&(~ALUResult_0);
    assign block_hold_up = block_valid&(br_related|br_if_true);
    assign block_hold_down = end_instr&break_depth_is_zero;
    assign control_stack_push = function_call|block_instr|loop_instr|if_instr;

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            break_depth <= 32'd0;
            block_hold <= 1'b0;
        end
        else if(cu_working) begin
            if(block_hold_up)begin
                break_depth <= (br_table_instr)?br_table_depth:constant;
                block_hold <= 1'b1;
            end else if(block_hold_down)begin
                block_hold <= 1'b0;
            end else if(end_instr)begin
                break_depth <= break_depth - 1'd1;
            end else if (block_hold&(block_instr|loop_instr|if_instr))begin
                break_depth <= break_depth + 1'd1;
            end
        end
    end

    //if else control
    reg if_hold;
    reg [31:0] if_hold_depth;
    wire if_hold_depth_is_zero = if_hold_depth==32'd0;
    wire if_unhold = (~if_hold)|(if_hold&if_hold_depth_is_zero&end_instr);
    assign block_valid = (block_hold_down|(~block_hold))&if_unhold;    
    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            if_hold <= 1'b0;
            if_hold_depth <= 8'd0;
        end
        else if(cu_working) begin
            if(if_hold)begin
                if(control_stack_push)begin
                    if_hold_depth <= if_hold_depth + 1'd1;
                end else if(if_hold_depth_is_zero)begin
                    if(end_instr|else_instr)begin
                        if_hold <= 1'b0;
                    end
                end else if(end_instr)begin
                    if_hold_depth <= if_hold_depth - 1'd1;
                end
            end else begin
                if(else_instr|(if_instr&ALUResult_0))begin
                    if_hold <= 1'b1;
                end
            end
        end
    end

endmodule