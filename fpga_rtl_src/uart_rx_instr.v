`timescale 1ns / 1ps
`include "wasm_defines.vh"
module uart_rx_instr(
        input clk,
        input rst_n,
        input [7:0] rx_data,
        input rx_valid,
        output [1:0] comm_stat,
        output [`instr_read_width-1:0] instr_wr,
        output instr_wr_valid
    );
        
        reg [`instr_read_width-1:0] shift_reg;
        reg [1:0] comm_stat_reg;
        reg [3:0] counter;
        reg counter_state;
        reg instr_wr_valid_reg;
        
        assign comm_stat = comm_stat_reg;
        assign instr_wr = shift_reg;
        assign instr_wr_valid = instr_wr_valid_reg;
        
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 64'b0;
            comm_stat_reg <= 2'b00;
        end else begin
            if (rx_valid) begin
                shift_reg <= {rx_data,shift_reg[87:8]};
                if (shift_reg[87:24] == 64'h000000016d736100) begin
                    comm_stat_reg <= 2'b01;
                end else if (shift_reg[87:24] == 64'hEEEEEEEEEEEEEEEE) begin
                    comm_stat_reg <= 2'b10;
                end
            end
        end
    end     

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 4'b0;
            counter_state <= 1'b0;
            instr_wr_valid_reg <= 1'b0;
        end else begin
            if (comm_stat_reg == 2'b01) begin
                if(rx_valid) begin
                    if (!counter_state) begin // 3 max
                        if (counter == 4'd1) begin
                            counter <= 4'b0;
                            counter_state <= 1'b1;
                            instr_wr_valid_reg <= 1'b1;
                        end else begin
                            counter <= counter + 4'b1;
                            instr_wr_valid_reg <= 1'b0;
                        end
                    end else begin // 11 max
                        if (counter == 4'd10) begin
                            counter <= 4'b0;
                            instr_wr_valid_reg <= 1'b1;
                        end else begin
                            counter <= counter + 4'b1;
                            instr_wr_valid_reg <= 1'b0;
                        end
                    end
                end else begin
                    instr_wr_valid_reg <= 1'b0;
                end
            end else begin
                counter <= 4'b0;
                counter_state <= 1'b0;
            end
        end
    end
 
endmodule
