// echo_8051 ALU — 8-bit arithmetic logic unit
`timescale 1ns/1ps

module alu (
    input  wire [7:0] a,          // operand A (usually ACC)
    input  wire [7:0] b,          // operand B
    input  wire [3:0] op,         // operation select
    input  wire       cy_in,      // carry in (from PSW.CY)
    output reg  [7:0] result,     // ALU result
    output reg        cy_out,     // carry out
    output reg        ac_out,     // auxiliary carry
    output reg        ov_out      // overflow
);

    // ALU operations
    localparam ALU_ADD  = 4'd0;
    localparam ALU_ADDC = 4'd1;
    localparam ALU_SUBB = 4'd2;
    localparam ALU_MUL  = 4'd3;
    localparam ALU_DIV  = 4'd4;
    localparam ALU_DA   = 4'd5;
    localparam ALU_ANL  = 4'd6;
    localparam ALU_ORL  = 4'd7;
    localparam ALU_XRL  = 4'd8;
    localparam ALU_INC  = 4'd9;
    localparam ALU_DEC  = 4'd10;
    localparam ALU_CLR  = 4'd11;
    localparam ALU_CPL  = 4'd12;
    localparam ALU_RL   = 4'd13;
    localparam ALU_RLC  = 4'd14;
    localparam ALU_RRC  = 4'd15;

    wire [8:0]  add_result  = {1'b0, a} + {1'b0, b};
    wire [8:0]  addc_result = {1'b0, a} + {1'b0, b} + {8'd0, cy_in};
    wire [8:0]  subb_result = {1'b0, a} - {1'b0, b} - {8'd0, cy_in};
    wire [15:0] mul_result  = {8'd0, a} * {8'd0, b};

    // Division
    wire [7:0] div_quotient;
    wire [7:0] div_remainder;
    assign div_quotient  = (b == 8'd0) ? 8'hFF : a / b;
    assign div_remainder = (b == 8'd0) ? 8'd0   : a % b;

    // DA adjust logic
    wire [7:0] da_adj;
    wire       da_lo = ((a[3:0] > 4'd9) || ac_out);
    wire       da_hi = ((a[7:4] > 4'd9) || cy_out);
    assign da_adj = (da_hi ? 8'h60 : 8'd0) | (da_lo ? 8'h06 : 8'd0);

    // Rotate
    wire [7:0] rl_result  = {a[6:0], a[7]};
    wire [7:0] rlc_result = {a[6:0], cy_in};
    wire [7:0] rr_result  = {a[0], a[7:1]};
    wire [7:0] rrc_result = {cy_in, a[7:1]};

    always @(*) begin
        result = 8'd0;
        cy_out = 1'b0;
        ac_out = 1'b0;
        ov_out = 1'b0;

        case (op)
            ALU_ADD: begin
                result = add_result[7:0];
                cy_out = add_result[8];
                ac_out = ((a[3:0] + b[3:0]) > 4'd15);
                ov_out = add_result[8] ^ ((a[6:0] + b[6:0]) > 7'd127);
            end
            ALU_ADDC: begin
                result = addc_result[7:0];
                cy_out = addc_result[8];
                ac_out = ((a[3:0] + b[3:0] + {3'd0,cy_in}) > 4'd15);
                ov_out = addc_result[8] ^ ((a[6:0] + b[6:0] + {6'd0,cy_in}) > 7'd127);
            end
            ALU_SUBB: begin
                result = subb_result[7:0];
                cy_out = subb_result[8];
                ac_out = (a[3:0] < (b[3:0] + {3'd0,cy_in}));
                ov_out = subb_result[8] ^ (a[6:0] < (b[6:0] + {6'd0,cy_in}));
            end
            ALU_MUL: begin
                result = mul_result[7:0];
                ov_out = |mul_result[15:8];
            end
            ALU_DIV: begin
                result = div_quotient;
                ov_out = (b == 8'd0);
            end
            ALU_DA: begin
                result = a + da_adj;
                cy_out = da_hi | ((a + da_adj) > 8'd255);
            end
            ALU_ANL:  result = a & b;
            ALU_ORL:  result = a | b;
            ALU_XRL:  result = a ^ b;
            ALU_INC:  result = a + 8'd1;
            ALU_DEC:  result = a - 8'd1;
            ALU_CLR:  result = 8'd0;
            ALU_CPL:  result = ~a;
            ALU_RL:   result = rl_result;
            ALU_RLC:  begin result = rlc_result; cy_out = a[7]; end
            ALU_RRC:  begin result = rrc_result; cy_out = a[0]; end
            default:  result = a;
        endcase
    end

endmodule
