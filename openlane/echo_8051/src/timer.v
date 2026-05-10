// echo_8051 Timer — T0 + T1, 4 modes each
`timescale 1ns/1ps
// Mode 0: 13-bit, Mode 1: 16-bit, Mode 2: 8-bit auto-reload, Mode 3: split

module timer (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       timer_tick,     // 1 pulse per machine cycle

    // SFR interface
    input  wire [7:0] tmod,           // timer mode register
    output reg  [7:0] tcon_out,       // timer control output
    input  wire [7:0] tcon_wr,        // write value for TCON
    input  wire       tcon_wr_en,     // TCON write enable
    output reg  [7:0] tl0_out, th0_out, tl1_out, th1_out,
    input  wire [7:0] tl0_wr, th0_wr, tl1_wr, th1_wr,
    input  wire       tl0_we, th0_we, tl1_we, th1_we,

    // Interrupt flags
    output wire       tf0, tf1
);

    // TCON bits
    reg it0, ie0, it1, ie1, tr0, tr1;
    reg tf0_reg, tf1_reg;

    // Timer registers
    reg [7:0] tl0, th0, tl1, th1;

    // Timer control
    wire [1:0] t0_mode = tmod[1:0];
    wire       t0_gate = tmod[3];
    wire       t0_ct   = tmod[2];  // 0=timer, 1=counter (not implemented)
    wire [1:0] t1_mode = tmod[5:4];
    wire       t1_gate = tmod[7];
    wire       t1_ct   = tmod[6];

    wire t0_run = tr0 && (!t0_gate || ie0);  // INT0 gating
    wire t1_run = tr1 && (!t1_gate || ie1);  // INT1 gating

    // T0
    wire [15:0] t0_val = {th0[4:0], tl0[4:0]};  // 13-bit for mode 0
    wire [15:0] t0_val16 = {th0, tl0};            // 16-bit for mode 1

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {it0, ie0, it1, ie1, tr0, tr1} <= 6'd0;
            {tf0_reg, tf1_reg} <= 2'd0;
            {tl0, th0, tl1, th1} <= 48'd0;
        end else begin
            // TCON writes
            if (tcon_wr_en) begin
                it0 <= tcon_wr[0]; ie0 <= tcon_wr[1];
                it1 <= tcon_wr[2]; ie1 <= tcon_wr[3];
                tr0 <= tcon_wr[4]; tr1 <= tcon_wr[6];
            end

            // TL0/TH0 writes
            if (tl0_we) tl0 <= tl0_wr;
            if (th0_we) th0 <= th0_wr;
            if (tl1_we) tl1 <= tl1_wr;
            if (th1_we) th1 <= th1_wr;

            // Timer ticks (once per machine cycle)
            if (timer_tick) begin
                // T0
                if (t0_run && !t0_ct) begin
                    case (t0_mode)
                        2'd0: begin // 13-bit
                            if (t0_val == 16'h03FF) begin
                                {th0[4:0], tl0[4:0]} <= 10'd0;
                                tf0_reg <= 1'b1;
                            end else begin
                                {th0[4:0], tl0[4:0]} <= t0_val + 1'd1;
                            end
                        end
                        2'd1: begin // 16-bit
                            if (t0_val16 == 16'hFFFF) begin
                                {th0, tl0} <= 16'd0;
                                tf0_reg <= 1'b1;
                            end else begin
                                {th0, tl0} <= t0_val16 + 1'd1;
                            end
                        end
                        2'd2: begin // 8-bit auto-reload
                            if (tl0 == 8'hFF) begin
                                tl0 <= th0;  // reload
                                tf0_reg <= 1'b1;
                            end else begin
                                tl0 <= tl0 + 1'd1;
                            end
                        end
                        default: ; // mode 3 not implemented in basic version
                    endcase
                end

                // T1
                if (t1_run && !t1_ct) begin
                    case (t1_mode)
                        2'd0: begin // 13-bit
                            if ({th1[4:0], tl1[4:0]} == 10'h3FF) begin
                                {th1[4:0], tl1[4:0]} <= 10'd0;
                                tf1_reg <= 1'b1;
                            end else begin
                                {th1[4:0], tl1[4:0]} <= {th1[4:0], tl1[4:0]} + 1'd1;
                            end
                        end
                        2'd1: begin // 16-bit
                            if ({th1, tl1} == 16'hFFFF) begin
                                {th1, tl1} <= 16'd0;
                                tf1_reg <= 1'b1;
                            end else begin
                                {th1, tl1} <= {th1, tl1} + 1'd1;
                            end
                        end
                        2'd2: begin // 8-bit auto-reload
                            if (tl1 == 8'hFF) begin
                                tl1 <= th1;
                                tf1_reg <= 1'b1;
                            end else begin
                                tl1 <= tl1 + 1'd1;
                            end
                        end
                        default: ;
                    endcase
                end
            end

            // TF0/TF1 can be cleared by software (writing 0 to TCON)
            if (tcon_wr_en) begin
                tf0_reg <= tcon_wr[5] ? tf0_reg : 1'b0;
                tf1_reg <= tcon_wr[7] ? tf1_reg : 1'b0;
            end
        end
    end

    // TCON output
    always @(*) begin
        tcon_out = {tf1_reg, tr1, tf0_reg, tr0, ie1, it1, ie0, it0};
    end

    // Timer register outputs
    always @(*) begin
        tl0_out = tl0; th0_out = th0;
        tl1_out = tl1; th1_out = th1;
    end

    assign tf0 = tf0_reg;
    assign tf1 = tf1_reg;

endmodule
