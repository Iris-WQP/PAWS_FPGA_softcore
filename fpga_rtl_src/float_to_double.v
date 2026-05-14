(* use_dsp = "yes" *)
module float_to_double(
    input [31:0] input_a,
    output reg [63:0] output_z
);

    integer shift_cnt;
    reg sign;
    reg [7:0] exp_in;
    reg [22:0] frac_in;
    reg [22:0] frac_norm;
    reg [10:0] exp_out;

    always @(*) begin
        sign = input_a[31];
        exp_in = input_a[30:23];
        frac_in = input_a[22:0];
        output_z = 64'd0;
        output_z[63] = sign;

        if (exp_in == 8'hff) begin
            output_z[62:52] = 11'h7ff;
            output_z[51:29] = frac_in;
            if (frac_in != 23'd0) begin
                output_z[51] = 1'b1;
            end
        end else if (exp_in == 8'd0) begin
            if (frac_in == 23'd0) begin
                output_z[62:0] = 63'd0;
            end else begin
                frac_norm = frac_in;
                shift_cnt = 0;
                while ((frac_norm[22] == 1'b0) && (shift_cnt < 23)) begin
                    frac_norm = frac_norm << 1;
                    shift_cnt = shift_cnt + 1;
                end
                exp_out = 11'd897 - shift_cnt;
                output_z[62:52] = exp_out;
                output_z[51:29] = frac_norm[21:0];
            end
        end else begin
            output_z[62:52] = {3'd0, exp_in} + 11'd896;
            output_z[51:29] = frac_in;
        end
    end

endmodule
