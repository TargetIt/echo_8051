module prom #(parameter ROM_SIZE=4096, AW=12) (
    input [AW-1:0] addr, output reg [7:0] data
);
    reg [7:0] rom [0:ROM_SIZE-1];
    integer i;
    initial begin
        for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;
        rom[0] = 8'h74;
        rom[1] = 8'h99;
        rom[2] = 8'hC0;
        rom[3] = 8'hE0;
        rom[4] = 8'hE4;
        rom[5] = 8'hD0;
        rom[6] = 8'hE0;
        rom[7] = 8'hF5;
        rom[8] = 8'h90;
        rom[9] = 8'h80;
        rom[10] = 8'hFE;
    end
    always @(*) data = rom[addr];
endmodule