// echo_8051 PSW — Program Status Word
`timescale 1ns/1ps
// Bit 7=CY, 6=AC, 5=F0, 4=RS1, 3=RS0, 2=OV, 1=-, 0=P

module psw (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       psw_write,         // write enable
    input  wire [7:0] psw_in,           // full PSW write value
    input  wire       cy_in,            // individual flag inputs
    input  wire       ac_in,
    input  wire       ov_in,
    input  wire       flags_update,      // update flags from ALU
    output wire [7:0] psw_out,
    output wire       cy_out,
    output wire       ac_out,
    output wire       ov_out,
    output wire [1:0] rs_out            // register bank select
);

    reg [7:0] psw_reg;

    // Parity computation for bit 0
    wire p_bit;
    assign p_bit = ^psw_in;  // odd parity (will be computed externally)

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psw_reg <= 8'h00;
        end else if (psw_write) begin
            // Writing to PSW via SFR
            psw_reg <= {psw_in[7], psw_in[6], psw_in[5], psw_in[4],
                        psw_in[3], psw_in[2], psw_in[1], psw_in[0]};
        end else if (flags_update) begin
            // Update flags from ALU result
            psw_reg[7] <= cy_in;
            psw_reg[6] <= ac_in;
            psw_reg[2] <= ov_in;
            // P bit updated separately via ACC parity
        end
    end

    assign psw_out = psw_reg;
    assign cy_out  = psw_reg[7];
    assign ac_out  = psw_reg[6];
    assign ov_out  = psw_reg[2];
    assign rs_out  = psw_reg[4:3];

endmodule
