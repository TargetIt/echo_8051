// echo_8051 Interrupt Controller — 5 sources, 2 priority levels
`timescale 1ns/1ps
// Sources: INT0, T0, INT1, T1, Serial
// Vectors: 0x03, 0x0B, 0x13, 0x1B, 0x23

module intc (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       int0_n,        // external interrupt 0 (active low)
    input  wire       int1_n,        // external interrupt 1 (active low)
    input  wire       tf0, tf1,      // timer overflow flags
    input  wire       ti, ri,        // serial TX/RX interrupt flags
    input  wire [7:0] ie,            // interrupt enable (IE)
    input  wire [7:0] ip,            // interrupt priority (IP)
    output reg        int_ack,       // interrupt acknowledged
    output reg  [15:0] int_vector    // interrupt vector address
);

    // Priority encoding (lower vector = higher priority by default)
    // Two-level priority via IP register

    wire int0_req = !int0_n && ie[0];  // EX0
    wire t0_req   = tf0    && ie[1];  // ET0
    wire int1_req = !int1_n && ie[2];  // EX1
    wire t1_req   = tf1    && ie[3];  // ET1
    wire ser_req  = (ti||ri) && ie[4]; // ES
    wire ea = ie[7];

    // Priority group: high priority (IP bit = 1)
    wire [4:0] hi_req = {
        ser_req  && ip[4],
        t1_req   && ip[3],
        int1_req && ip[2],
        t0_req   && ip[1],
        int0_req && ip[0]
    };

    // Priority group: low priority (IP bit = 0)
    wire [4:0] lo_req = {
        ser_req  && !ip[4],
        t1_req   && !ip[3],
        int1_req && !ip[2],
        t0_req   && !ip[1],
        int0_req && !ip[0]
    };

    // Vector lookup
    function [15:0] get_vector;
        input [2:0] src;
        case (src)
            3'd0: get_vector = 16'h0003;  // INT0
            3'd1: get_vector = 16'h000B;  // T0
            3'd2: get_vector = 16'h0013;  // INT1
            3'd3: get_vector = 16'h001B;  // T1
            3'd4: get_vector = 16'h0023;  // Serial
            default: get_vector = 16'h0000;
        endcase
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_ack <= 1'b0;
            int_vector <= 16'd0;
        end else begin
            int_ack <= 1'b0;

            if (ea) begin
                // Check high priority first
                if (hi_req[4])      begin int_ack <= 1'b1; int_vector <= get_vector(3'd4); end
                else if (hi_req[3]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd3); end
                else if (hi_req[2]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd2); end
                else if (hi_req[1]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd1); end
                else if (hi_req[0]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd0); end
                // Then low priority
                else if (lo_req[4]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd4); end
                else if (lo_req[3]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd3); end
                else if (lo_req[2]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd2); end
                else if (lo_req[1]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd1); end
                else if (lo_req[0]) begin int_ack <= 1'b1; int_vector <= get_vector(3'd0); end
            end
        end
    end

endmodule
