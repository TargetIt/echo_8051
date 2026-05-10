// Cross-validation test program — matches scripts/crossval_iss.py
module prom #(parameter ROM_SIZE=4096, AW=12) (
    input [AW-1:0] addr, output [7:0] data
);
    reg [7:0] rom [0:ROM_SIZE-1];
    integer i;
    initial begin for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;
        rom[0]=8'h74; rom[1]=8'h42;      // MOV A,#0x42
        rom[2]=8'h78; rom[3]=8'h55;      // MOV R0,#0x55
        rom[4]=8'h79; rom[5]=8'h33;      // MOV R1,#0x33
        rom[6]=8'hE8;                    // MOV A,R0 → A=0x55
        rom[7]=8'h24; rom[8]=8'h20;      // ADD A,#0x20 → A=0x75
        rom[9]=8'hC3;                    // CLR C
        rom[10]=8'h94; rom[11]=8'h25;    // SUBB A,#0x25 → A=0x50
        rom[12]=8'h54; rom[13]=8'h0F;    // ANL A,#0x0F → A=0x00
        rom[14]=8'h44; rom[15]=8'hAA;    // ORL A,#0xAA → A=0xAA
        rom[16]=8'h64; rom[17]=8'h55;    // XRL A,#0x55 → A=0xFF
        rom[18]=8'h04;                   // INC A → A=0x00
        rom[19]=8'h14;                   // DEC A → A=0xFF
        rom[20]=8'h04;                   // INC A → A=0x00
        rom[21]=8'h04;                   // INC A → A=0x01
        rom[22]=8'h04;                   // INC A → A=0x02
        rom[23]=8'hC4;                   // SWAP A → A=0x20
        rom[24]=8'hF4;                   // CPL A → A=0xDF
        rom[25]=8'hE4;                   // CLR A → A=0x00
        rom[26]=8'h74; rom[27]=8'h0A;    // MOV A,#10
        rom[28]=8'h75; rom[29]=8'hF0; rom[30]=8'h06; // MOV B,#6
        rom[31]=8'hA4;                   // MUL AB → A=60=0x3C
        rom[32]=8'hF5; rom[33]=8'h90;    // MOV P1,A
        rom[34]=8'h74; rom[35]=8'h0F;    // MOV A,#15
        rom[36]=8'h75; rom[37]=8'hF0; rom[38]=8'h04; // MOV B,#4
        rom[39]=8'h84;                   // DIV AB → A=3
        rom[40]=8'hF5; rom[41]=8'hA0;    // MOV P2,A
        rom[42]=8'h78; rom[43]=8'h03;    // MOV R0,#3
        rom[44]=8'hE4;                   // CLR A
        rom[45]=8'h04;                   // INC A (loop)
        rom[46]=8'hD8; rom[47]=8'hFD;    // DJNZ R0,-3 → A=3
        rom[48]=8'hF5; rom[49]=8'hB0;    // MOV P3,A
        rom[50]=8'hC0; rom[51]=8'hE0;    // PUSH ACC
        rom[52]=8'hE4;                   // CLR A
        rom[53]=8'hD0; rom[54]=8'hE0;    // POP ACC → A=3
        rom[55]=8'hF5; rom[56]=8'h80;    // MOV P0,A
        rom[57]=8'hD3;                   // SETB C
        rom[58]=8'hC3;                   // CLR C
        rom[59]=8'hB3;                   // CPL C
        rom[60]=8'h80; rom[61]=8'hFE;    // SJMP $
    end
    assign data = rom[addr];
endmodule
