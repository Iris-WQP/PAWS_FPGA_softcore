`timescale 1ns / 1ps

module blk_mem(
        input [9:0] addra,
        input clka,
        input [7:0] dina,
        output [7:0] douta,
        input ena,
        input [0:0] wea
    );

    reg [7:0] ram[0:1023];
    reg [7:0] douta_reg;    
    assign douta = douta_reg;
    always @(posedge clka) begin
        if (ena) begin
            if (wea[0]) begin
                ram[addra] <= dina;
            end
            douta_reg <= ram[addra];
        end
    end
    
endmodule
