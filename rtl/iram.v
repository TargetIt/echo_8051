// echo_8051 Internal RAM — 128 bytes (0x00-0x7F)
`timescale 1ns/1ps
// Direct-addressed by CPU, stores register banks + stack + general purpose

module iram (
    input  wire       clk,
    input  wire [6:0] addr,        // 7-bit address (0-127)
    input  wire       wr_en,       // write enable
    input  wire [7:0] wr_data,     // write data
    output wire [7:0] rd_data      // read data (combinatorial)
);

    reg [7:0] ram [0:127];

    assign rd_data = ram[addr];

    always @(posedge clk) begin
        if (wr_en)
            ram[addr] <= wr_data;
    end

endmodule
