// echo_8051 Top Level — complete 8051 microcontroller
`timescale 1ns/1ps
// Integrates CPU core, memories, peripherals, and I/O

module echo_8051_top #(
    parameter ROM_AW = 12,
    parameter CLK_FREQ = 50_000_000
) (
    input  wire       clk,
    input  wire       rst_n,

    // External interrupt pins
    input  wire       int0_n,
    input  wire       int1_n,

    // I/O ports
    inout  wire [7:0] p0, p1, p2, p3,

    // Serial port
    input  wire       rxd,
    output wire       txd,

    // External memory interface
    output wire       ale,
    output wire       psen_n,
    output wire       rd_n,
    output wire       wr_n,
    input  wire       ea_n
);

    // ===== Internal buses =====
    wire [ROM_AW-1:0] rom_addr;
    wire [7:0]        rom_data;

    wire [6:0]        iram_addr;
    wire              iram_we;
    wire [7:0]        iram_wdata, iram_rdata;

    wire [7:0]        sfr_addr_wire;
    wire              sfr_we;
    wire [7:0]        sfr_wdata, sfr_rdata;

    // SFR direct access
    wire [7:0]  acc, b_reg, psw_val, sp;
    wire [15:0] dptr;
    wire [7:0]  sfr_p0_out, sfr_p1_out, sfr_p2_out, sfr_p3_out;
    wire [7:0]  sfr_p0_in,  sfr_p1_in,  sfr_p2_in,  sfr_p3_in;
    wire [7:0]  sfr_tcon, sfr_tmod, sfr_tl0, sfr_th0, sfr_tl1, sfr_th1;
    wire [7:0]  sfr_tcon_in, sfr_tl0_in, sfr_th0_in, sfr_tl1_in, sfr_th1_in;
    wire [7:0]  sfr_scon, sfr_sbuf;
    wire [7:0]  sfr_scon_in, sfr_sbuf_in;
    wire [7:0]  sfr_ie, sfr_ip;
    wire [7:0]  sfr_ie_in, sfr_ip_in;

    // Timer/interrupt
    wire timer_tick;
    wire tf0, tf1;

    // Baud rate
    wire baud_tick;

    // ===== Module Instances =====

    // Program ROM
    prom #(.ROM_SIZE(4096), .AW(ROM_AW)) u_prom (
        .addr(rom_addr),
        .data(rom_data)
    );

    // Internal RAM
    iram u_iram (
        .clk     (clk),
        .addr    (iram_addr),
        .wr_en   (iram_we),
        .wr_data (iram_wdata),
        .rd_data (iram_rdata)
    );

    // SFR Block
    sfr_block u_sfr (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (sfr_addr_wire),
        .wr_en    (sfr_we),
        .wr_data  (sfr_wdata),
        .rd_data  (sfr_rdata),
        .acc      (acc),
        .b_reg    (b_reg),
        .psw_val  (psw_val),
        .sp       (sp),
        .dptr     (dptr),
        .p0_out   (sfr_p0_out), .p1_out(sfr_p1_out), .p2_out(sfr_p2_out), .p3_out(sfr_p3_out),
        .p0_in    (sfr_p0_in),  .p1_in(sfr_p1_in),  .p2_in(sfr_p2_in),  .p3_in(sfr_p3_in),
        .tcon     (sfr_tcon), .tmod(sfr_tmod), .tl0(sfr_tl0), .th0(sfr_th0), .tl1(sfr_tl1), .th1(sfr_th1),
        .tcon_in  (sfr_tcon_in), .tl0_in(sfr_tl0_in), .th0_in(sfr_th0_in), .tl1_in(sfr_tl1_in), .th1_in(sfr_th1_in),
        .scon     (sfr_scon), .sbuf(sfr_sbuf),
        .scon_in  (sfr_scon_in), .sbuf_in(sfr_sbuf_in),
        .ie       (sfr_ie), .ip(sfr_ip),
        .ie_in    (sfr_ie_in), .ip_in(sfr_ip_in)
    );

    // CPU Core
    cpu_core #(.ROM_AW(ROM_AW)) u_cpu (
        .clk        (clk),
        .rst_n      (rst_n),
        .rom_addr   (rom_addr),
        .rom_data   (rom_data),
        .iram_addr  (iram_addr),
        .iram_we    (iram_we),
        .iram_wdata (iram_wdata),
        .iram_rdata (iram_rdata),
        .sfr_addr   (sfr_addr_wire),
        .sfr_we     (sfr_we),
        .sfr_wdata  (sfr_wdata),
        .sfr_rdata  (sfr_rdata),
        .acc        (acc),
        .b_reg      (b_reg),
        .psw_val    (psw_val),
        .sp         (sp),
        .int_ack    (1'b0),
        .int_vector (16'd0),
        .ale        (ale),
        .psen_n     (psen_n)
    );

    // Timer
    timer u_timer (
        .clk        (clk),
        .rst_n      (rst_n),
        .timer_tick (timer_tick),
        .tmod       (sfr_tmod),
        .tcon_out   (sfr_tcon_in),
        .tcon_wr    (sfr_tcon),
        .tcon_wr_en (sfr_we && sfr_addr_wire == 8'h88),
        .tl0_out    (sfr_tl0_in),
        .th0_out    (sfr_th0_in),
        .tl1_out    (sfr_tl1_in),
        .th1_out    (sfr_th1_in),
        .tl0_wr     (sfr_wdata),
        .th0_wr     (sfr_wdata),
        .tl1_wr     (sfr_wdata),
        .th1_wr     (sfr_wdata),
        .tl0_we     (sfr_we && sfr_addr_wire == 8'h8A),
        .th0_we     (sfr_we && sfr_addr_wire == 8'h8C),
        .tl1_we     (sfr_we && sfr_addr_wire == 8'h8B),
        .th1_we     (sfr_we && sfr_addr_wire == 8'h8D),
        .tf0        (tf0),
        .tf1        (tf1)
    );

    // Simple timer tick: divide clk by 12 (12T mode)
    reg [3:0] div_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) div_counter <= 4'd0;
        else div_counter <= div_counter + 4'd1;
    end
    assign timer_tick = (div_counter == 4'd11);

    // Baud rate tick: divide clk by (12 * 32) = 384
    // At 50MHz: 50M/384 ≈ 130kHz baud
    reg [8:0] baud_div;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) baud_div <= 9'd0;
        else baud_div <= baud_div + 9'd1;
    end
    assign baud_tick = (baud_div == 9'd383);

    // UART
    uart u_uart (
        .clk       (clk),
        .rst_n     (rst_n),
        .baud_tick (baud_tick),
        .scon_wr   (sfr_wdata),
        .scon_we   (sfr_we && sfr_addr_wire == 8'h98),
        .sbuf_wr   (sfr_wdata),
        .sbuf_we   (sfr_we && sfr_addr_wire == 8'h99),
        .scon_out  (sfr_scon_in),
        .sbuf_out  (sfr_sbuf_in),
        .rxd       (rxd),
        .txd       (txd),
        .ti_flag   (),
        .ri_flag   ()
    );

    // Interrupt Controller
    intc u_intc (
        .clk        (clk),
        .rst_n      (rst_n),
        .int0_n     (int0_n),
        .int1_n     (int1_n),
        .tf0        (tf0),
        .tf1        (tf1),
        .ti         (sfr_scon[1]),
        .ri         (sfr_scon[0]),
        .ie         (sfr_ie),
        .ip         (sfr_ip),
        .int_ack    (),
        .int_vector ()
    );

    // I/O Ports
    io_ports u_ports (
        .clk    (clk),
        .rst_n  (rst_n),
        .p0_wr  (sfr_wdata), .p1_wr(sfr_wdata), .p2_wr(sfr_wdata), .p3_wr(sfr_wdata),
        .p0_we  (sfr_we && sfr_addr_wire == 8'h80),
        .p1_we  (sfr_we && sfr_addr_wire == 8'h90),
        .p2_we  (sfr_we && sfr_addr_wire == 8'hA0),
        .p3_we  (sfr_we && sfr_addr_wire == 8'hB0),
        .p0_out (sfr_p0_in), .p1_out(sfr_p1_in), .p2_out(sfr_p2_in), .p3_out(sfr_p3_in),
        .p0_in  (p0), .p1_in(p1), .p2_in(p2), .p3_in(p3),
        .int0_n (), .int1_n (),
        .t0_in  (1'b0), .t1_in(1'b0),
        .rxd    (rxd), .txd(), .rd_n(rd_n), .wr_n(wr_n)
    );

    // Port output assignments — driven continuously by SFR port registers
    assign p0 = sfr_p0_out;
    assign p1 = sfr_p1_out;
    assign p2 = sfr_p2_out;
    assign p3 = sfr_p3_out;

endmodule
