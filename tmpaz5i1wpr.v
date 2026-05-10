module prom #(parameter ROM_SIZE=4096, AW=12) (
    input [AW-1:0] addr, output reg [7:0] data
);
    reg [7:0] rom [0:ROM_SIZE-1];
    integer i;
    initial begin
        for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;
        rom[0] = 8'h74;
        rom[1] = 8'h0A;
        rom[2] = 8'h75;
        rom[3] = 8'hF0;
        rom[4] = 8'h06;
        rom[5] = 8'hA4;
        rom[6] = 8'hF5;
        rom[7] = 8'h90;
        rom[8] = 8'h74;
        rom[9] = 8'h0F;
        rom[10] = 8'h75;
        rom[11] = 8'hF0;
        rom[12] = 8'h04;
        rom[13] = 8'h84;
        rom[14] = 8'hF5;
        rom[15] = 8'hA0;
        rom[16] = 8'h80;
        rom[17] = 8'hFE;
    end
    always @(*) data = rom[addr];
endmodule