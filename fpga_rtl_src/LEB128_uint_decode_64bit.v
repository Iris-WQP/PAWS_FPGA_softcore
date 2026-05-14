 `timescale 1ns / 1ps

module LEB128_uint_decode(
            input [72:0] LEB128_in,
            output reg [63:0] uint_out,
            output reg [3:0] byte_cnt,
            input LEB128_signed_decode
    );
    
    wire [6:0] dt [8:0]; //data from LEB128_in
    wire dt_9;
    assign dt[0] = LEB128_in [6:0];
    assign dt[1] = LEB128_in [14:8];
    assign dt[2] = LEB128_in [22:16];
    assign dt[3] = LEB128_in [30:24];
    assign dt[4] = LEB128_in [38:32];
    assign dt[5] = LEB128_in [46:40];
    assign dt[6] = LEB128_in [54:48];
    assign dt[7] = LEB128_in [62:56];
    assign dt[8] = LEB128_in [70:64];
    assign dt_9 = LEB128_in [72];
    
    always@(*) begin
        if(~LEB128_in[7]) begin
            uint_out = (LEB128_in[6]&LEB128_signed_decode)? {{57{1'b1}},dt[0]} : {57'b0,dt[0]};
            byte_cnt = 1;
        end else begin
            if(~LEB128_in[15]) begin
                uint_out = (LEB128_in[14]&LEB128_signed_decode)? {{50{1'b1}}, dt[1], dt[0]} : {50'b0, dt[1], dt[0]};
                byte_cnt = 2;
            end else begin
                if(~LEB128_in[23]) begin
                    uint_out = (LEB128_in[22]&LEB128_signed_decode)? {{43{1'b1}}, dt[2], dt[1], dt[0]}:{43'b0, dt[2], dt[1], dt[0]};
                    byte_cnt = 3;
                end else begin
                    if(~LEB128_in[31]) begin
                        uint_out = (LEB128_in[30]&LEB128_signed_decode)?{{36{1'b1}}, dt[3], dt[2], dt[1], dt[0]}:{36'b0, dt[3], dt[2], dt[1], dt[0]};
                        byte_cnt = 4;
                    end else begin
                        if(~LEB128_in[39]) begin
                            uint_out = (LEB128_in[38]&LEB128_signed_decode)?{{29{1'b1}}, dt[4], dt[3], dt[2], dt[1], dt[0]}:{29'b0, dt[4], dt[3], dt[2], dt[1], dt[0]};
                            byte_cnt = 5;
                        end else begin
                            if(~LEB128_in[47]) begin
                                uint_out = (LEB128_in[46]&LEB128_signed_decode)?{{22{1'b1}}, dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]}:{22'b0, dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
                                byte_cnt = 6;
                            end else begin
                                if(~LEB128_in[55])begin
                                    uint_out = (LEB128_in[54]&LEB128_signed_decode)? {{15{1'b1}}, dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]}:{15'b0, dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
                                    byte_cnt = 7;
                                end else begin
                                   if(~LEB128_in[63])begin
                                        uint_out = (LEB128_in[62]&LEB128_signed_decode)? {{8{1'b1}}, dt[7], dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]}:{8'b0, dt[7], dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
                                        byte_cnt = 8;
                                    end else begin
                                        if(~LEB128_in[71])begin
                                            uint_out = (LEB128_in[70]&LEB128_signed_decode)? {{1'b1}, dt[8], dt[7], dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]}:{1'b0, dt[8], dt[7], dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
                                            byte_cnt = 9;
                                        end else begin
                                            uint_out = {dt_9, dt[8], dt[7], dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
                                            byte_cnt = 10;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    // always (posedge clk or negedge rst_n) begin
    //     if(~rst_n)begin
    //         last_cycle_part <= 49'b0;
    //         two_cycle_read <= 1'b0;
    //     end
    //     else begin
    //         if((~const_push)&length_mode)begin
    //             last_cycle_part <= {dt[6], dt[5], dt[4], dt[3], dt[2], dt[1], dt[0]};
    //             two_cycle_read <= 1'b1;
    //         end else begin
    //             two_cycle_read <= 1'b0;
    //         end
    //     end
    // end
    
endmodule
