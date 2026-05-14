`timescale 1ns / 1ps
module UART #(
    parameter CLK_FREQ_MHz = 50,      // clock frequency (MHz)
    parameter BAUD_RATE = 115200 // serial baud rate
    ) (
    input  i_clk,
    input  i_rstn,

    output [7:0] o_rx_data, // received data
    output       o_rx_data_valid,
    input        i_rx_data_ready, // data receiver module ready
    input        i_rx_pin,

    input  [7:0] i_tx_data, // data to send
    input        i_tx_data_valid,
    output       o_tx_data_ready,
    output       o_tx_pin
    );

    UART_Rx #(.CLK_FREQ_MHz(CLK_FREQ_MHz), .BAUD_RATE(BAUD_RATE)) u_UART_Rx (
        .i_clk           ( i_clk           ),
        .i_rstn          ( i_rstn          ),
        .o_rx_data       ( o_rx_data[7:0]  ),
        .o_rx_data_valid ( o_rx_data_valid ),
        .i_rx_data_ready ( i_rx_data_ready ),
        .i_rx_pin        ( i_rx_pin        )
    );

    UART_Tx #(.CLK_FREQ_MHz(CLK_FREQ_MHz), .BAUD_RATE(BAUD_RATE)) u_UART_Tx (
        .i_clk           ( i_clk           ),
        .i_rstn          ( i_rstn          ),
        .i_tx_data       ( i_tx_data[7:0]  ),
        .i_tx_data_valid ( i_tx_data_valid ),
        .o_tx_data_ready ( o_tx_data_ready ),
        .o_tx_pin        ( o_tx_pin        )
    );

endmodule
