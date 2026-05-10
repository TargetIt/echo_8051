// echo_8051 I/O Ports — P0, P1, P2, P3
`timescale 1ns/1ps
// P0: open-drain bidirectional, muxed with external memory bus
// P1: quasi-bidirectional
// P2: quasi-bidirectional, muxed with high address
// P3: quasi-bidirectional, muxed with alternate functions

module io_ports (
    input  wire        clk,
    input  wire        rst_n,

    // Port register writes (from SFR)
    input  wire [7:0]  p0_wr, p1_wr, p2_wr, p3_wr,
    input  wire        p0_we, p1_we, p2_we, p3_we,

    // Port output values
    output wire [7:0]  p0_out, p1_out, p2_out, p3_out,

    // External pins (bidirectional — simplified as separate in/out)
    input  wire [7:0]  p0_in, p1_in, p2_in, p3_in,

    // Alternate function inputs for P3
    input  wire        int0_n, int1_n,  // external interrupts
    input  wire        t0_in, t1_in,    // timer inputs
    input  wire        rxd,             // serial RX
    output wire        txd,             // serial TX (P3.1)
    output wire        rd_n, wr_n       // external memory RD/WR (P3.6, P3.7)
);

    reg [7:0] p0_reg, p1_reg, p2_reg, p3_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p0_reg <= 8'hFF;
            p1_reg <= 8'hFF;
            p2_reg <= 8'hFF;
            p3_reg <= 8'hFF;
        end else begin
            if (p0_we) p0_reg <= p0_wr;
            if (p1_we) p1_reg <= p1_wr;
            if (p2_we) p2_reg <= p2_wr;
            if (p3_we) p3_reg <= p3_wr;
        end
    end

    // Port outputs: register value drives output
    // P3 outputs are muxed with alternate functions
    assign p0_out = p0_reg;
    assign p1_out = p1_reg;
    assign p2_out = p2_reg;
    assign p3_out = p3_reg;

    // Alternate functions from P3
    assign txd  = p3_reg[1];   // P3.1 = TXD
    assign rd_n = p3_reg[7];   // P3.7 = RD#
    assign wr_n = p3_reg[6];   // P3.6 = WR#

endmodule
