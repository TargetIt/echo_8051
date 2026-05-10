// echo_8051 SFR Block — Special Function Registers (128 bytes, 0x80-0xFF)
`timescale 1ns/1ps
// Key SFRs: P0,P1,P2,P3, SP, DPL, DPH, ACC, B, PSW, IE, IP,
//           TCON, TMOD, TL0, TH0, TL1, TH1, SCON, SBUF, PCON

module sfr_block (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  addr,           // full SFR address (0x80-0xFF)
    input  wire        wr_en,
    input  wire [7:0]  wr_data,
    output wire [7:0]  rd_data,

    // Direct access for CPU core (ACC, B, PSW, SP, DPTR)
    output wire [7:0]  acc,            // Accumulator (0xE0)
    output wire [7:0]  b_reg,          // B register (0xF0)
    output wire [7:0]  psw_val,        // PSW (0xD0)
    output wire [7:0]  sp,             // Stack Pointer (0x81)
    output wire [15:0] dptr,           // Data Pointer (0x82+0x83)

    // Port registers
    output wire [7:0]  p0_out, p1_out, p2_out, p3_out,
    input  wire [7:0]  p0_in,  p1_in,  p2_in,  p3_in,

    // Timer registers
    output wire [7:0]  tcon, tmod, tl0, th0, tl1, th1,
    input  wire [7:0]  tcon_in, tl0_in, th0_in, tl1_in, th1_in,

    // Serial
    output wire [7:0]  scon, sbuf,
    input  wire [7:0]  scon_in, sbuf_in,

    // Interrupt
    output wire [7:0]  ie, ip,
    input  wire [7:0]  ie_in, ip_in
);

    // SFR storage
    reg [7:0] sfr [0:127];

    // SFR addresses (offset from 0x80)
    localparam SFR_P0   = 7'h00;  // 0x80
    localparam SFR_SP   = 7'h01;  // 0x81
    localparam SFR_DPL  = 7'h02;  // 0x82
    localparam SFR_DPH  = 7'h03;  // 0x83
    localparam SFR_PCON = 7'h07;  // 0x87
    localparam SFR_TCON = 7'h08;  // 0x88
    localparam SFR_TMOD = 7'h09;  // 0x89
    localparam SFR_TL0  = 7'h0A;  // 0x8A
    localparam SFR_TL1  = 7'h0B;  // 0x8B
    localparam SFR_TH0  = 7'h0C;  // 0x8C
    localparam SFR_TH1  = 7'h0D;  // 0x8D
    localparam SFR_P1   = 7'h10;  // 0x90
    localparam SFR_SCON = 7'h18;  // 0x98
    localparam SFR_SBUF = 7'h19;  // 0x99
    localparam SFR_P2   = 7'h20;  // 0xA0
    localparam SFR_IE   = 7'h28;  // 0xA8
    localparam SFR_P3   = 7'h30;  // 0xB0
    localparam SFR_IP   = 7'h38;  // 0xB8
    localparam SFR_PSW  = 7'h50;  // 0xD0
    localparam SFR_ACC  = 7'h60;  // 0xE0
    localparam SFR_B    = 7'h70;  // 0xF0

    wire [6:0] sfr_idx = addr[6:0];  // offset from 0x80

    // Reset values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sfr[SFR_SP]  <= 8'h07;
            sfr[SFR_P0]  <= 8'hFF;
            sfr[SFR_P1]  <= 8'hFF;
            sfr[SFR_P2]  <= 8'hFF;
            sfr[SFR_P3]  <= 8'hFF;
            sfr[SFR_PCON] <= 8'h00;
            sfr[SFR_TCON] <= 8'h00;
            sfr[SFR_TMOD] <= 8'h00;
            sfr[SFR_IE]   <= 8'h00;
            sfr[SFR_IP]   <= 8'h00;
            sfr[SFR_PSW]  <= 8'h00;
            sfr[SFR_ACC]  <= 8'h00;
            sfr[SFR_B]    <= 8'h00;
        end else if (wr_en) begin
            // Write to SFR, respecting read-only bits
            case (sfr_idx)
                SFR_TCON: sfr[SFR_TCON] <= tcon_in;
                SFR_TL0:  sfr[SFR_TL0]  <= tl0_in;
                SFR_TH0:  sfr[SFR_TH0]  <= th0_in;
                SFR_TL1:  sfr[SFR_TL1]  <= tl1_in;
                SFR_TH1:  sfr[SFR_TH1]  <= th1_in;
                SFR_SCON: sfr[SFR_SCON] <= scon_in;
                SFR_SBUF: sfr[SFR_SBUF] <= sbuf_in;
                SFR_IE:   sfr[SFR_IE]   <= ie_in;
                SFR_IP:   sfr[SFR_IP]   <= ip_in;
                SFR_PSW:  sfr[SFR_PSW]  <= wr_data;
                SFR_ACC:  sfr[SFR_ACC]  <= wr_data;
                SFR_B:    sfr[SFR_B]    <= wr_data;
                SFR_SP:   sfr[SFR_SP]   <= wr_data;
                SFR_DPL:  sfr[SFR_DPL]  <= wr_data;
                SFR_DPH:  sfr[SFR_DPH]  <= wr_data;
                SFR_P0:   sfr[SFR_P0]   <= wr_data;
                SFR_P1:   sfr[SFR_P1]   <= wr_data;
                SFR_P2:   sfr[SFR_P2]   <= wr_data;
                SFR_P3:   sfr[SFR_P3]   <= wr_data;
                default:  ; // read-only or unimplemented
            endcase
        end
    end

    // Read (combinatorial)
    assign rd_data = sfr[sfr_idx];

    // Direct access outputs
    assign acc     = sfr[SFR_ACC];
    assign b_reg   = sfr[SFR_B];
    assign psw_val = sfr[SFR_PSW];
    assign sp      = sfr[SFR_SP];
    assign dptr    = {sfr[SFR_DPH], sfr[SFR_DPL]};

    assign p0_out = sfr[SFR_P0];
    assign p1_out = sfr[SFR_P1];
    assign p2_out = sfr[SFR_P2];
    assign p3_out = sfr[SFR_P3];

    assign tcon = sfr[SFR_TCON];
    assign tmod = sfr[SFR_TMOD];
    assign tl0  = sfr[SFR_TL0];
    assign th0  = sfr[SFR_TH0];
    assign tl1  = sfr[SFR_TL1];
    assign th1  = sfr[SFR_TH1];

    assign scon = sfr[SFR_SCON];
    assign sbuf = sfr[SFR_SBUF];
    assign ie   = sfr[SFR_IE];
    assign ip   = sfr[SFR_IP];

endmodule
