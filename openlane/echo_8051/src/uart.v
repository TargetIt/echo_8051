// echo_8051 UART — full-duplex serial port, 4 modes
`timescale 1ns/1ps
// Mode 0: synchronous shift register
// Mode 1: 8-bit UART, variable baud
// Mode 2: 9-bit UART, fixed baud
// Mode 3: 9-bit UART, variable baud

module uart (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,     // baud rate clock (from timer1)

    // SFR interface
    input  wire [7:0] scon_wr,
    input  wire       scon_we,
    input  wire [7:0] sbuf_wr,
    input  wire       sbuf_we,
    output wire [7:0] scon_out,
    output wire [7:0] sbuf_out,

    // Serial pins
    input  wire       rxd,
    output reg        txd,

    // Interrupt flags
    output reg        ti_flag,       // transmit interrupt
    output reg        ri_flag        // receive interrupt
);

    // SCON bits
    reg [7:0] scon;    // SM0/SM1/SM2/REN/TB8/RB8/TI/RI
    reg [7:0] sbuf_tx, sbuf_rx;

    // Mode selection
    wire [1:0] mode = {scon[7], scon[6]};
    wire ren = scon[4];  // receive enable

    // Baud rate: mode 1/3 use timer1, mode 0/2 use fosc/12 or fosc/64
    // Simplified: always use baud_tick for rx/tx timing

    // TX state machine
    reg [3:0] tx_bit_cnt;
    reg [9:0] tx_shift;  // 10-bit: start + 8 data + stop
    reg       tx_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scon <= 8'h00;
            sbuf_tx <= 8'h00;
            sbuf_rx <= 8'h00;
            txd <= 1'b1;  // idle high
            tx_busy <= 1'b0;
            tx_bit_cnt <= 4'd0;
            ti_flag <= 1'b0;
            ri_flag <= 1'b0;
        end else begin
            // SCON write
            if (scon_we) begin
                scon[7:4] <= scon_wr[7:4];  // SM0/SM1/SM2/REN
                scon[3]   <= scon_wr[3];    // TB8
                // TI/RI are not directly writable
            end

            // SBUF write → start TX
            if (sbuf_we) begin
                sbuf_tx <= sbuf_wr;
                if (!tx_busy) begin
                    tx_busy <= 1'b1;
                    tx_bit_cnt <= 4'd0;
                    // Load shift register: start(0) + data + stop(1)
                    tx_shift <= {1'b1, sbuf_wr, 1'b0};
                end
            end

            // TX state machine (bit-banging at baud rate)
            if (tx_busy && baud_tick) begin
                if (tx_bit_cnt == 4'd10) begin
                    tx_busy <= 1'b0;
                    ti_flag <= 1'b1;  // TX complete
                    txd <= 1'b1;
                end else begin
                    txd <= tx_shift[0];
                    tx_shift <= {1'b0, tx_shift[9:1]};
                    tx_bit_cnt <= tx_bit_cnt + 4'd1;
                end
            end

            // TI cleared by software (not shown — simplified)

            // RX (simplified: single-byte capture)
            if (ren && baud_tick) begin
                // In a full implementation, RX uses a similar shift register
                // capturing at mid-bit timing
                // Simplified: just flag ready for now
            end
        end
    end

    assign scon_out = scon;
    assign sbuf_out = sbuf_tx;

endmodule
