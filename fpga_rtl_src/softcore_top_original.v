`timescale 1ns / 1ps

module softcore_top(
        // system clock & reset
        input        i_sys_clk_p,
        input        i_sys_clk_n,
        input        i_sys_rst,  
        // output led to show mode & top output
        output [3:0] o_led,
        // uart
        input        i_uart_rx,
        output       o_uart_tx        
    );

        wire [1:0] comm_state; // communication state
        wire clk;
        wire rst_n;
        // UART ports
        reg  [7:0]  tx_data;
        reg  [7:0]  tx_str;
        reg         tx_data_valid;
        wire        tx_data_ready;
        reg  [7:0]  tx_cnt;
        wire [7:0]  rx_data;
        wire        rx_data_valid;
        wire        rx_data_ready;
        reg  [31:0] wait_cnt;
        reg  [3:0]  state;
        // record instr
        reg [31:0] global_record [9:0];
        wire [`instr_read_width-1:0] instr_wr;
        wire instr_wr_valid;
        reg [`instr_read_width-1:0] instr_record [0:1023];
        reg [31:0] instr_count;
//        reg [1:0] check_reset;
        // wasm top ports
        wire [2:0] o_ERROR;
        wire [1:0] o_work_state;
        // line memory interface
        reg i_line_mem_rd_rdy;
        reg [`log_instr_mem_depth-1:0] i_line_mem_rd_addr;
        wire [`WIDTH-1:0] o_line_mem_rd_data;
        // instr memory interface
        wire o_instr_mem_wr_rdy;
        // reg i_instr_mem_wr_vld;
        // reg [14:0] i_instr_mem_wr_addr;
        // reg [`instr_read_width-1:0] i_instr_mem_wr_data;
        reg i_instr_mem_write_finish;
        wire sys_rstn;
        // debug interface
        // reg i_debug_enable;
        // // extra signals for debug
        // wire [(`instr_log2_bram_depth-1):0]  read_pointer;
        // wire [1:0] pre_read_state;
        // wire block_valid;
        assign sys_rstn = i_sys_rst;
        assign rst_n = sys_rstn;
        assign o_led[3:2] = comm_state;
        assign o_led[1:0] = o_work_state;
        
//        always @(posedge clk or negedge rst_n) begin
//            if (!rst_n) begin
//                check_reset <= 2'b00;
//            end else begin
//                check_reset <= 2'b11;
//            end
//        end    

        clk_wiz_0 u_clk_wiz_0(
            .clk_in1_p ( i_sys_clk_p ),
            .clk_in1_n ( i_sys_clk_n ),
            .clk_out1 ( clk )
        );

   /*---------------wasm top---------------------*/
       WASM_TOP u_WASM_TOP (
        .i_clk(clk), 
        .i_rst_n(rst_n), 
        .o_ERROR(o_ERROR), 
        .o_work_state(o_work_state), 
        .i_line_mem_rd_rdy(i_line_mem_rd_rdy),    //or you can call it request
        // o_line_mem_rd_vld,
        .i_line_mem_rd_addr(i_line_mem_rd_addr), 
        .o_line_mem_rd_data(o_line_mem_rd_data), // 
        .o_instr_mem_wr_rdy(o_instr_mem_wr_rdy), // useless signal
        .i_instr_mem_wr_vld(instr_wr_valid), 
        .i_instr_mem_wr_addr(instr_count[14:0]), 
        .i_instr_mem_wr_data(instr_wr), 
        .i_instr_mem_wr_finish(i_instr_mem_write_finish),
        .i_scl(1'b1),
        .i_sda(1'b1),
        .o_sda(),
        .i_debug_ena(1'b0)

        );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_instr_mem_write_finish <= 1'b0;
        end else begin
            if(comm_state == 2'b10)begin
                i_instr_mem_write_finish <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_line_mem_rd_rdy <= 1'b0;
        end else begin
            if(o_work_state == 2'b11)begin
                i_line_mem_rd_rdy <= 1'b1;
            end
        end
    end

    reg [1:0] read_enable;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_enable <= 2'b00;
        end else begin
            if(o_work_state == 2'b11)begin
                read_enable <= read_enable + 2'b01;
            end
        end
    end    

   /*---------------record global data---------------------*/  
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_line_mem_rd_addr <= 9'h100;
        end else begin
            if(read_enable == 2'b11)begin
                if(i_line_mem_rd_addr < 9'h109) begin
                    i_line_mem_rd_addr <= i_line_mem_rd_addr + 9'h1;
                end
                global_record[i_line_mem_rd_addr - 9'h100] <= o_line_mem_rd_data;
            end
        end
    end

   /*---------------record instr---------------------*/
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            instr_count <= 31'b0;
        end else begin
            if (instr_wr_valid) begin
                instr_record[instr_count] <= instr_wr;
                instr_count <= instr_count + 31'b1;
            end
        end
    end


   /*------------------UART control-------------------*/   
    localparam UART_CLK_FREQ_MHz = 5;
    localparam BAUD_RATE = 115200;
    localparam  IDLE =  0;
    localparam  SEND =  1;
    localparam  WAIT =  2;  //state for send only 


    assign rx_data_ready = 1'b1;
    
    always@(posedge clk or negedge sys_rstn) begin
        if (~sys_rstn) begin
            wait_cnt      <= 32'd0;
            tx_data       <= 8'd0;
            state         <= IDLE;
            tx_cnt        <= 8'd0;
            tx_data_valid <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    if(comm_state[1]) state <= SEND;
                end
                SEND: begin
                    wait_cnt <= 32'd0;
                    tx_data <= tx_str;

                    if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < 8'd20) begin // Send 12 bytes data
                        tx_cnt <= tx_cnt + 8'd1; // Send data counter
                    end else if (tx_data_valid && tx_data_ready) begin //last byte sent is complete
                        tx_cnt <= 8'd0;
                        tx_data_valid <= 1'b0;
                        state <= WAIT;
                    end else if (~tx_data_valid) begin
                        tx_data_valid <= 1'b1;
                    end
                end
                WAIT: begin
                    wait_cnt <= wait_cnt + 32'd1;

                    if(rx_data_valid == 1'b1) begin
                        tx_data_valid <= 1'b1;
                        tx_data <= rx_data;   // send uart received data
                    end else if(tx_data_valid && tx_data_ready) begin
                        tx_data_valid <= 1'b0;
                    end else if(wait_cnt >= UART_CLK_FREQ_MHz * 100) begin // wait for 1 second
                        state <= SEND;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    // instantiate uart_rx_instr
    uart_rx_instr u_uart_rx_instr(
        .clk           ( clk              ),
        .rst_n         ( rst_n            ),
        .rx_data       ( rx_data[7:0]     ),
        .rx_valid      ( rx_data_valid    ),
        .comm_stat     ( comm_state       ),
        .instr_wr      ( instr_wr         ), 
        .instr_wr_valid( instr_wr_valid   )
    );
    UART #(.CLK_FREQ_MHz(UART_CLK_FREQ_MHz), .BAUD_RATE(BAUD_RATE)) u_UART(
        .i_clk           ( clk         ),
        .i_rstn          ( sys_rstn        ),
        .o_rx_data       ( rx_data[7:0]  ),
        .o_rx_data_valid ( rx_data_valid ),
        .i_rx_data_ready ( rx_data_ready ),
        .i_rx_pin        ( i_uart_rx     ),
        .i_tx_data       ( tx_data[7:0]  ),
        .i_tx_data_valid ( tx_data_valid ),
        .o_tx_data_ready ( tx_data_ready ),
        .o_tx_pin        ( o_uart_tx     )
    );   
     /*--------------------ila---------------------*/
     wire [`instr_read_width-1:0] instr_record_0;
        ila_0 u_ila(
            .clk(clk),
            .probe0({o_work_state,o_ERROR,global_record[0],global_record[1],o_line_mem_rd_data[31:0],instr_wr_valid,rx_data_valid,rst_n,instr_record_0,instr_wr})
        ); 

    /*------------------send instr to check-------------------*/ 

    // convert instr_record[0] and instr_record[1] into ascii code to send by uart
    reg [7:0] tx_str_array [`instr_read_width/8-1:0];
    reg [7:0] tx_str_array1 [`instr_read_width/8-1:0];
    reg [7:0] global_send [9:0][7:0];
    assign instr_record_0 = instr_record[0];
    genvar i;
    generate
        for (i=0; i<`instr_read_width/4; i=i+1) begin : gen_tx_str_array
            always @(*) begin
                case (instr_record[0][i*4 +: 4])
                    4'h0: tx_str_array[i] = 8'h30; // '0'
                    4'h1: tx_str_array[i] = 8'h31; // '1'
                    4'h2: tx_str_array[i] = 8'h32; // '2'
                    4'h3: tx_str_array[i] = 8'h33; // '3'
                    4'h4: tx_str_array[i] = 8'h34; // '4'
                    4'h5: tx_str_array[i] = 8'h35; // '5'
                    4'h6: tx_str_array[i] = 8'h36; // '6'
                    4'h7: tx_str_array[i] = 8'h37; // '7'
                    4'h8: tx_str_array[i] = 8'h38; // '8'
                    4'h9: tx_str_array[i] = 8'h39; // '9'
                    4'hA: tx_str_array[i] = 8'h41; // 'A'
                    4'hB: tx_str_array[i] = 8'h42; // 'B'
                    4'hC: tx_str_array[i] = 8'h43; // 'C'
                    4'hD: tx_str_array[i] = 8'h44; // 'D'
                    4'hE: tx_str_array[i] = 8'h45; // 'E'
                    4'hF: tx_str_array[i] = 8'h46; // 'F'
                    default: tx_str_array[i] = 8'h30; // '0'
                endcase
            end
        end
    endgenerate

    genvar j;
    generate
        for (j=0; j<`instr_read_width/4; j=j+1) begin : gen_tx_str_array1
            always @(*) begin
                case (instr_record[1][j*4 +: 4])
                    4'h0: tx_str_array1[j] = 8'h30; // '0'
                    4'h1: tx_str_array1[j] = 8'h31; // '1'
                    4'h2: tx_str_array1[j] = 8'h32; // '2'
                    4'h3: tx_str_array1[j] = 8'h33; // '3'
                    4'h4: tx_str_array1[j] = 8'h34; // '4'
                    4'h5: tx_str_array1[j] = 8'h35; // '5'
                    4'h6: tx_str_array1[j] = 8'h36; // '6'
                    4'h7: tx_str_array1[j] = 8'h37; // '7'
                    4'h8: tx_str_array1[j] = 8'h38; // '8'
                    4'h9: tx_str_array1[j] = 8'h39; // '9'
                    4'hA: tx_str_array1[j] = 8'h41; // 'A'
                    4'hB: tx_str_array1[j] = 8'h42; // 'B'
                    4'hC: tx_str_array1[j] = 8'h43; // 'C'
                    4'hD: tx_str_array1[j] = 8'h44; // 'D'
                    4'hE: tx_str_array1[j] = 8'h45; // 'E'
                    4'hF: tx_str_array1[j] = 8'h46; // 'F'
                    default: tx_str_array1[j] = 8'h30; // '0'
                endcase
            end
        end
    endgenerate   

    genvar m, n;
    generate
        for(m=0; m<10; m=m+1) begin : gen_global
            for (n=0; n<8; n=n+1) begin : gen_global_outputs
                always @(*)begin
                    case (global_record[m][n*4 +: 4])
                        4'h0: global_send[m][n] = 8'h30; // '0'
                        4'h1: global_send[m][n] = 8'h31; // '1'
                        4'h2: global_send[m][n] = 8'h32; // '2'
                        4'h3: global_send[m][n] = 8'h33; // '3'
                        4'h4: global_send[m][n] = 8'h34; // '4'
                        4'h5: global_send[m][n] = 8'h35; // '5'
                        4'h6: global_send[m][n] = 8'h36; // '6'
                        4'h7: global_send[m][n] = 8'h37; // '7'
                        4'h8: global_send[m][n] = 8'h38; // '8'
                        4'h9: global_send[m][n] = 8'h39; // '9'
                        4'hA: global_send[m][n] = 8'h41; // 'A'
                        4'hB: global_send[m][n] = 8'h42; // 'B'
                        4'hC: global_send[m][n] = 8'h43; // 'C'
                        4'hD: global_send[m][n] = 8'h44; // 'D'
                        4'hE: global_send[m][n] = 8'h45; // 'E'
                        4'hF: global_send[m][n] = 8'h46; // 'F'
                        default: global_send[m][n] = 8'h30; // '0'
                    endcase
                end
            end
        end
    endgenerate     

    always@(*) begin
        case(tx_cnt)
//            8'd0: tx_str = tx_str_array[10];
//            8'd1: tx_str = tx_str_array[9];
//            8'd2: tx_str = tx_str_array[8];
//            8'd3: tx_str = tx_str_array[7];
//            8'd4: tx_str = tx_str_array[6];
//            8'd5:  tx_str = tx_str_array[5];
//            8'd6:  tx_str = tx_str_array[4];
//            8'd7:  tx_str = tx_str_array[3];
//            8'd8:  tx_str = tx_str_array[2];
//            8'd9:  tx_str = tx_str_array[1];
//            8'd10: tx_str = tx_str_array[0];
//            8'd11: tx_str = 8'h0D; // Carriage Return
//            8'd12: tx_str = 8'h0A; // Line Feed
//            8'd13: tx_str = tx_str_array1[10];
//            8'd14: tx_str = tx_str_array1[9];
//            8'd15: tx_str = tx_str_array1[8];
//            8'd16: tx_str = tx_str_array1[7];   
//            8'd17: tx_str = tx_str_array1[6];
//            8'd18: tx_str = tx_str_array1[5];
//            8'd19: tx_str = tx_str_array1[4];
//            8'd20: tx_str = tx_str_array1[3];
//            8'd21: tx_str = tx_str_array1[2];
//            8'd22: tx_str = tx_str_array1[1];
//            8'd23: tx_str = tx_str_array1[0];
//            8'd24: tx_str = 8'h0D; // Carriage Return
//            8'd25: tx_str = 8'h0A; // Line Feed
            8'd0: tx_str = global_send[0][7];
            8'd1: tx_str = global_send[0][6];
            8'd2: tx_str = global_send[0][5];
            8'd3: tx_str = global_send[0][4];  
            8'd4: tx_str = global_send[0][3];
            8'd5: tx_str = global_send[0][2];
            8'd6: tx_str = global_send[0][1];
            8'd7: tx_str = global_send[0][0];
            8'd8: tx_str = 8'h0D; // Carriage Return
            8'd9: tx_str = 8'h0A; // Line Feed
            8'd10: tx_str = global_send[1][7];
            8'd11: tx_str = global_send[1][6];
            8'd12: tx_str = global_send[1][5];
            8'd13: tx_str = global_send[1][4];
            8'd14: tx_str = global_send[1][3];
            8'd15: tx_str = global_send[1][2];
            8'd16: tx_str = global_send[1][1];
            8'd17: tx_str = global_send[1][0];
            8'd18: tx_str = 8'h0D; // Carriage Return
            8'd19: tx_str = 8'h0A; // Line Feed
//            8'd46: tx_str = global_send[2][7];
//            8'd47: tx_str = global_send[2][6];
//            8'd48: tx_str = global_send[2][5];
//            8'd49: tx_str = global_send[2][4];
//            8'd50: tx_str = global_send[2][3];
//            8'd51: tx_str = global_send[2][2];
//            8'd52: tx_str = global_send[2][1];
//            8'd53: tx_str = global_send[2][0];
//            8'd54: tx_str = 8'h0D; // Carriage Return
//            8'd55: tx_str = 8'h0A; // Line Feed
//            8'd56: tx_str = global_send[3][7];
//            8'd57: tx_str = global_send[3][6];
//            8'd58: tx_str = global_send[3][5];
//            8'd59: tx_str = global_send[3][4];
//            8'd60: tx_str = global_send[3][3];
//            8'd61: tx_str = global_send[3][2];
//            8'd62: tx_str = global_send[3][1];
//            8'd63: tx_str = global_send[3][0];
//            8'd64: tx_str = 8'h0D; // Carriage Return
//            8'd65: tx_str = 8'h0A; // Line Feed
//            8'd66: tx_str = global_send[4][7];
//            8'd67: tx_str = global_send[4][6];
//            8'd68: tx_str = global_send[4][5];  
//            8'd69: tx_str = global_send[4][4];
//            8'd70: tx_str = global_send[4][3];
//            8'd71: tx_str = global_send[4][2];
//            8'd72: tx_str = global_send[4][1];
//            8'd73: tx_str = global_send[4][0];
//            8'd74: tx_str = 8'h0D; // Carriage Return
//            8'd75: tx_str = 8'h0A; // Line Feed
//            8'd76: tx_str = global_send[5][7];
//            8'd77: tx_str = global_send[5][6];
//            8'd78: tx_str = global_send[5][5];
//            8'd79: tx_str = global_send[5][4];
//            8'd80: tx_str = global_send[5][3];
//            8'd81: tx_str = global_send[5][2];
//            8'd82: tx_str = global_send[5][1];
//            8'd83: tx_str = global_send[5][0];
//            8'd84: tx_str = 8'h0D; // Carriage Return
//            8'd85: tx_str = 8'h0A; // Line Feed
//            8'd86: tx_str = global_send[6][7];
//            8'd87: tx_str = global_send[6][6];
//            8'd88: tx_str = global_send[6][5];
//            8'd89: tx_str = global_send[6][4];
//            8'd90: tx_str = global_send[6][3];
//            8'd91: tx_str = global_send[6][2];
//            8'd92: tx_str = global_send[6][1];
//            8'd93: tx_str = global_send[6][0];
//            8'd94: tx_str = 8'h0D; // Carriage Return
//            8'd95: tx_str = 8'h0A; // Line Feed
//            8'd96: tx_str = global_send[7][7];
//            8'd97: tx_str = global_send[7][6];
//            8'd98: tx_str = global_send[7][5];
//            8'd99: tx_str = global_send[7][4];
//            8'd100: tx_str = global_send[7][3];
//            8'd101: tx_str = global_send[7][2];
//            8'd102: tx_str = global_send[7][1];
//            8'd103: tx_str = global_send[7][0];
//            8'd104: tx_str = 8'h0D; // Carriage Return
//            8'd105: tx_str = 8'h0A; // Line Feed
//            8'd106: tx_str = global_send[8][7];
//            8'd107: tx_str = global_send[8][6];
//            8'd108: tx_str = global_send[8][5];
//            8'd109: tx_str = global_send[8][4];
//            8'd110: tx_str = global_send[8][3];
//            8'd111: tx_str = global_send[8][2];
//            8'd112: tx_str = global_send[8][1];
//            8'd113: tx_str = global_send[8][0];
//            8'd114: tx_str = 8'h0D; // Carriage Return
//            8'd115: tx_str = 8'h0A; // Line Feed
//            8'd116: tx_str = global_send[9][7];
//            8'd117: tx_str = global_send[9][6];
//            8'd118: tx_str = global_send[9][5];
//            8'd119: tx_str = global_send[9][4];
//            8'd120: tx_str = global_send[9][3];
//            8'd121: tx_str = global_send[9][2];
//            8'd122: tx_str = global_send[9][1];
//            8'd123: tx_str = global_send[9][0];
//            8'd124: tx_str = 8'h0D; // Carriage Return
//            8'd125: tx_str = 8'h0A; // Line Feed
            default: tx_str = 8'd0;
        endcase
    end    

endmodule