`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
//                                                                              //
//  Author: meisq                                                               //
//          msq@qq.com                                                          //
//          ALINX(shanghai) Technology Co.,Ltd                                  //
//          heijin                                                              //
//     WEB: http://www.alinx.cn/                                                //
//     BBS: http://www.heijin.org/                                              //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////
//                                                                              //
// Copyright (c) 2017,ALINX(shanghai) Technology Co.,Ltd                        //
//                    All rights reserved                                       //
//                                                                              //
// This source file may be used and distributed without restriction provided    //
// that this copyright statement is not removed from the file and that any      //
// derivative work contains the original copyright notice and the associated    //
// disclaimer.                                                                  //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

//================================================================================
//  Revision History:
//  Date          By            Revision    Change Description
//--------------------------------------------------------------------------------
//2017/8/1                    1.0          Original
//*******************************************************************************/


module UART_Rx #(parameter CLK_FREQ_MHz = 50,      // clock frequency (MHz)
                 parameter BAUD_RATE = 115200 // serial baud rate
    ) (
    input            i_clk,           // clock input
    input            i_rstn,          // asynchronous reset input, low active 
    output reg [7:0] o_rx_data,       // received serial data
    output reg       o_rx_data_valid, // received serial data is valid
    input            i_rx_data_ready, // data receiver module ready
    input            i_rx_pin         // serial data input
	);

    // calculates the clock cycle for baud rate 
    localparam CYCLE = CLK_FREQ_MHz * 1000000 / BAUD_RATE;
    // FSM code
    localparam S_IDLE      = 1;
    localparam S_START     = 2; // start bit
    localparam S_REC_BYTE  = 3; // data bits
    localparam S_STOP      = 4; // stop bit
    localparam S_DATA      = 5;

    reg  [2:0]  state;
    reg  [2:0]  next_state;
    reg         rx_d0;      // delay 1 clock for i_rx_pin
    reg         rx_d1;      // delay 1 clock for rx_d0
    wire        rx_negedge; // negedge of i_rx_pin
    reg  [7:0]  rx_bits;    // temporary storage of received data
    reg  [15:0] cycle_cnt;  // baud counter
    reg  [2:0]  bit_cnt;    // bit counter

    assign rx_negedge = rx_d1 && ~rx_d0;

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            rx_d0 <= 1'b0;
            rx_d1 <= 1'b0;	
        end else begin
            rx_d0 <= i_rx_pin;
            rx_d1 <= rx_d0;
        end
    end

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
                if (rx_negedge) begin
                    next_state <= S_START;
                end else begin
                    next_state <= S_IDLE;
                end
            end
            S_START: begin
                if (cycle_cnt == CYCLE - 1) begin //one data cycle 
                    next_state <= S_REC_BYTE;
                end else begin
                    next_state <= S_START;
                end
            end
            S_REC_BYTE: begin
                if (cycle_cnt == CYCLE - 1  && bit_cnt == 3'd7) begin //receive 8bit data
                    next_state <= S_STOP;
                end else begin
                    next_state <= S_REC_BYTE;
                end
            end
            S_STOP: begin
                if (cycle_cnt == CYCLE/2 - 1) begin // half bit cycle,to avoid missing the next byte receiver
                    next_state <= S_DATA;
                end else begin
                    next_state <= S_STOP;
                end
            end
            S_DATA: begin
                if (i_rx_data_ready) begin // data receive complete
                    next_state <= S_IDLE;
                end else begin
                    next_state <= S_DATA;
                end
            end
            default: begin
                next_state <= S_IDLE;
            end
        endcase
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            o_rx_data_valid <= 1'b0;
        end
        else if (state == S_STOP && next_state != state) begin
            o_rx_data_valid <= 1'b1;
        end
        else if (state == S_DATA && i_rx_data_ready) begin
            o_rx_data_valid <= 1'b0;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            o_rx_data <= 8'd0;
        end else if (state == S_STOP && next_state != state) begin
            o_rx_data <= rx_bits; //latch received data
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            bit_cnt <= 3'd0;
        end else if (state == S_REC_BYTE) begin
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
        if (i_rstn == 1'b0) begin
            cycle_cnt <= 16'd0;
        end else if ((state == S_REC_BYTE && cycle_cnt == CYCLE - 1) || next_state != state) begin
            cycle_cnt <= 16'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 16'd1;	
        end
    end

    // receive serial data bit data
    always @(posedge i_clk or negedge i_rstn) begin
        if (i_rstn == 1'b0) begin
            rx_bits <= 8'd0;
        end else if (state == S_REC_BYTE && cycle_cnt == CYCLE/2 - 1) begin
            rx_bits[bit_cnt] <= i_rx_pin;
        end else begin
            rx_bits <= rx_bits; 
        end
    end

endmodule
