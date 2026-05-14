`timescale 1ns / 1ps
//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//2017/8/1                    1.0          Original
//*******************************************************************************/


module UART_Tx #(parameter CLK_FREQ_MHz = 50,      // clock frequency(Mhz)
                 parameter BAUD_RATE = 115200 // serial baud rate
    ) (
	input            i_clk,           // clock input
	input            i_rstn,          // asynchronous reset input, low active 
	input      [7:0] i_tx_data,       // data to send
	input            i_tx_data_valid, // data to be sent is valid
	output reg       o_tx_data_ready, // send ready
	output           o_tx_pin         // serial data output
    );

    // calculates the clock cycle for baud rate 
    localparam CYCLE = CLK_FREQ_MHz * 1000000 / BAUD_RATE;
    // FSM code
    localparam S_IDLE       = 1;
    localparam S_START      = 2; // start bit
    localparam S_SEND_BYTE  = 3; // data bits
    localparam S_STOP       = 4; // stop bit

    reg [2:0]  state;
    reg [2:0]  next_state;
    reg [15:0] cycle_cnt;     // baud counter
    reg [2:0]  bit_cnt;       // bit counter
    reg [7:0]  tx_data_latch; // latch data to send
    reg        tx_reg;        // serial data output

    assign o_tx_pin = tx_reg;

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            S_IDLE: begin
                if (i_tx_data_valid == 1'b1) begin
                    next_state <= S_START;
                end else begin
                    next_state <= S_IDLE;
                end
            end
            S_START: begin
                if (cycle_cnt == CYCLE - 1) begin
                    next_state <= S_SEND_BYTE;
                end else begin
                    next_state <= S_START;
                end
            end
            S_SEND_BYTE: begin
                if (cycle_cnt == CYCLE - 1  && bit_cnt == 3'd7) begin
                    next_state <= S_STOP;
                end else begin
                    next_state <= S_SEND_BYTE;
                end
            end
            S_STOP: begin
                if (cycle_cnt == CYCLE - 1) begin
                    next_state <= S_IDLE;
                end else begin
                    next_state <= S_STOP;
                end
            end
            default: begin
                next_state <= S_IDLE;
            end
        endcase
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            o_tx_data_ready <= 1'b0;
        end else if(state == S_IDLE) begin
            if (i_tx_data_valid == 1'b1) begin
                o_tx_data_ready <= 1'b0;
            end else begin
                o_tx_data_ready <= 1'b1;
            end
        end else if(state == S_STOP && cycle_cnt == CYCLE - 1) begin
            o_tx_data_ready <= 1'b1;
        end
    end


    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0)begin
            tx_data_latch <= 8'd0;
        end else if (state == S_IDLE && i_tx_data_valid == 1'b1) begin
            tx_data_latch <= i_tx_data;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            bit_cnt <= 3'd0;
        end else if (state == S_SEND_BYTE) begin
            if (cycle_cnt == CYCLE - 1) begin
                bit_cnt <= bit_cnt + 3'd1;
            end else begin
                bit_cnt <= bit_cnt;
            end
        end else begin
            bit_cnt <= 3'd0;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0)begin
            cycle_cnt <= 16'd0;
        end else if ((state == S_SEND_BYTE && cycle_cnt == CYCLE - 1) || next_state != state) begin
            cycle_cnt <= 16'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 16'd1;	
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            tx_reg <= 1'b1;
        end else begin
            case (state)
                S_IDLE:      tx_reg <= 1'b1;
                S_STOP:      tx_reg <= 1'b1; 
                S_START:     tx_reg <= 1'b0; 
                S_SEND_BYTE: tx_reg <= tx_data_latch[bit_cnt];
                default:     tx_reg <= 1'b1; 
            endcase
        end
    end

endmodule