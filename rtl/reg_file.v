// echo_8051 Register File — 4 banks × 8 registers (R0-R7)
`timescale 1ns/1ps
// Bank selected by PSW.RS1:RS0

module reg_file (
    input  wire       clk,
    input  wire [1:0] rs,          // register bank select (from PSW)
    input  wire [2:0] rn,          // register number (0-7)
    input  wire       wr_en,       // write enable
    input  wire [7:0] wr_data,     // write data
    output wire [7:0] rd_data      // read data
);

    // 32 registers total (4 banks × 8 registers)
    reg [7:0] regs [0:31];

    // Base address for current bank
    wire [4:0] base = {rs, 3'd0};

    // Read: combinatorial
    assign rd_data = regs[base + {2'd0, rn}];

    // Write: synchronous
    always @(posedge clk) begin
        if (wr_en)
            regs[base + {2'd0, rn}] <= wr_data;
    end

endmodule
