// Full regression: 13 tests including PUSH/POP
`timescale 1ns/1ps
module prom #(parameter ROM_SIZE=4096, AW=12) (
    input [AW-1:0] addr, output [7:0] data
);
    reg [7:0] rom [0:ROM_SIZE-1];
    integer i;
    initial begin for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;

        // T1-T12: chain test (all feed into each other)
        rom[0]=8'h74; rom[1]=8'h42;       // MOV A,#0x42
        rom[2]=8'hF5; rom[3]=8'h90;       // MOV P1,A

        rom[4]=8'h78; rom[5]=8'h55;       // MOV R0,#0x55
        rom[6]=8'hE8;                      // MOV A,R0
        rom[7]=8'hF5; rom[8]=8'hA0;       // MOV P2,A

        rom[9]=8'h24; rom[10]=8'h20;      // ADD A,#0x20 → A=0x75
        rom[11]=8'hF5; rom[12]=8'hB0;     // MOV P3,A

        rom[13]=8'hC3;                     // CLR C
        rom[14]=8'h94; rom[15]=8'h25;     // SUBB A,#0x25 → A=0x50
        rom[16]=8'hF5; rom[17]=8'h80;     // MOV P0,A

        rom[18]=8'h54; rom[19]=8'h0F;     // ANL A,#0x0F → A=0x00
        rom[20]=8'hF5; rom[21]=8'h90;     // MOV P1,A

        rom[22]=8'h44; rom[23]=8'hAA;     // ORL A,#0xAA → A=0xAA
        rom[24]=8'hF5; rom[25]=8'hA0;     // MOV P2,A

        rom[26]=8'h64; rom[27]=8'h55;     // XRL A,#0x55 → A=0xFF
        rom[28]=8'hF5; rom[29]=8'hB0;     // MOV P3,A

        rom[30]=8'h04;                     // INC A → A=0x00
        rom[31]=8'hF5; rom[32]=8'h80;     // MOV P0,A

        rom[33]=8'h14;                     // DEC A → A=0xFF
        rom[34]=8'hF5; rom[35]=8'h90;     // MOV P1,A

        rom[36]=8'h74; rom[37]=8'h0A;     // MOV A,#10
        rom[38]=8'h75; rom[39]=8'hF0; rom[40]=8'h06; // MOV B,#6
        rom[41]=8'hA4;                     // MUL AB → A=60=0x3C
        rom[42]=8'hF5; rom[43]=8'hA0;     // MOV P2,A

        rom[44]=8'hE4;                     // CLR A
        rom[45]=8'h04; rom[46]=8'h04; rom[47]=8'h14; // INC,INC,DEC → A=1
        rom[48]=8'hF5; rom[49]=8'hB0;     // MOV P3,A

        rom[50]=8'hE4;                     // CLR A
        rom[51]=8'h78; rom[52]=8'h05;     // MOV R0,#5
        rom[53]=8'h04;                     // INC A (loop)
        rom[54]=8'hD8; rom[55]=8'hFD;     // DJNZ R0,-3
        rom[56]=8'hF5; rom[57]=8'h80;     // MOV P0,A → P0=5

        // T13: PUSH/POP — uses P1 (overwrites T9)
        // ACC currently = 5 (from DJNZ loop). PUSH ACC, CLR A, POP ACC, MOV P1,A
        rom[58]=8'hC0; rom[59]=8'hE0;     // PUSH ACC
        rom[60]=8'hE4;                     // CLR A
        rom[61]=8'hD0; rom[62]=8'hE0;     // POP ACC
        rom[63]=8'hF5; rom[64]=8'h90;     // MOV P1,A → P1=5 if PUSH/POP works

        rom[65]=8'h80; rom[66]=8'hFE;     // SJMP $
    end
    assign data = rom[addr];
endmodule
