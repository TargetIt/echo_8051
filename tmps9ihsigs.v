module prom #(parameter ROM_SIZE=4096, AW=12) (
    input [AW-1:0] addr, output reg [7:0] data
);
    reg [7:0] rom [0:ROM_SIZE-1];
    integer i;
    initial begin
        for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;
        rom[0] = 8'hED;
        rom[1] = 8'h84;
        rom[2] = 8'h64;
        rom[3] = 8'hBC;
        rom[4] = 8'hD3;
        rom[5] = 8'h7E;
        rom[6] = 8'hDF;
        rom[7] = 8'h44;
        rom[8] = 8'hBF;
        rom[9] = 8'hC0;
        rom[10] = 8'hDD;
        rom[11] = 8'h79;
        rom[12] = 8'h59;
        rom[13] = 8'hFB;
        rom[14] = 8'h7D;
        rom[15] = 8'h5F;
        rom[16] = 8'hE9;
        rom[17] = 8'hA4;
        rom[18] = 8'h74;
        rom[19] = 8'hD3;
        rom[20] = 8'hF9;
        rom[21] = 8'hF4;
        rom[22] = 8'h44;
        rom[23] = 8'h4B;
        rom[24] = 8'h54;
        rom[25] = 8'h27;
        rom[26] = 8'hD3;
        rom[27] = 8'hE8;
        rom[28] = 8'h7A;
        rom[29] = 8'h0C;
        rom[30] = 8'h7B;
        rom[31] = 8'hAD;
        rom[32] = 8'h04;
        rom[33] = 8'hF4;
        rom[34] = 8'hED;
        rom[35] = 8'h84;
        rom[36] = 8'h84;
        rom[37] = 8'hFE;
        rom[38] = 8'h44;
        rom[39] = 8'h5B;
        rom[40] = 8'hE4;
        rom[41] = 8'hB3;
    end
    always @(*) data = rom[addr];
endmodule