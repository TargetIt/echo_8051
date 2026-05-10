// echo_8051 CPU Core — 8-bit 8051-compatible processor
`timescale 1ns/1ps
// Multi-cycle FSM: FETCH → EXEC1 → EXEC2 → WBACK
// One ROM byte read per clock cycle (combinational ROM)

module cpu_core #(
    parameter ROM_AW = 12
) (
    input  wire        clk,
    input  wire        rst_n,

    // Program ROM
    output reg  [ROM_AW-1:0] rom_addr,
    input  wire [7:0]        rom_data,

    // Internal RAM
    output reg  [6:0]  iram_addr,
    output reg         iram_we,
    output reg  [7:0]  iram_wdata,
    input  wire [7:0]  iram_rdata,

    // SFR interface
    output reg  [7:0]  sfr_addr,
    output reg         sfr_we,
    output reg  [7:0]  sfr_wdata,
    input  wire [7:0]  sfr_rdata,
    input  wire [7:0]  acc, b_reg, psw_val, sp,

    // Register file (internal)

    // Interrupt
    input  wire        int_ack,
    input  wire [15:0] int_vector,

    // Control
    output reg         ale,
    output reg         psen_n
);

    // ===== FSM States =====
    localparam S_FETCH   = 3'd0;  // read opcode
    localparam S_EXEC1   = 3'd1;  // read 2nd byte / execute 1-byte ops
    localparam S_EXEC2   = 3'd2;  // read 3rd byte / execute 2-byte ops
    localparam S_WBACK   = 3'd3;  // writeback 3-byte results
    localparam S_POP2    = 3'd4;  // POP: update SP
    localparam S_ACALL2  = 3'd5;  // ACALL: push PC high + jump
    localparam S_XCH2    = 3'd6;  // XCH A,direct: direct→ACC

    reg [2:0] state;

    // ===== Architectural Registers =====
    reg [15:0] pc;
    reg [7:0]  ir;             // instruction register (opcode)
    reg [7:0]  op1, op2;      // operand bytes
    // ACC forwarding: solves 1-cycle SFR write-read stall
    reg         acc_fwd_valid;     // forwarding buffer has valid data
    reg  [7:0]  acc_fwd_data;     // forwarded ACC value
    wire [7:0]  eff_acc = acc_fwd_valid ? acc_fwd_data : acc;
    // Parity helper: XOR of all bits → 1 if odd number of 1s
    function parity8;
        input [7:0] v;
        begin parity8 = ^v; end
    endfunction

    // Update PSW parity after ACC write
    wire update_psw_p = sfr_we && (sfr_addr == 8'hE0);

    // ===== Register File (internal) =====
    reg  [2:0] rn_sel;
    reg        reg_we;
    reg  [7:0] reg_wdata;
    wire [7:0] reg_rdata;

    reg_file u_regfile (
        .clk     (clk),
        .rs      (psw_val[4:3]),
        .rn      (rn_sel),
        .wr_en   (reg_we),
        .wr_data (reg_wdata),
        .rd_data (reg_rdata)
    );

    // ===== ALU =====
    reg  [7:0] alu_a, alu_b;
    reg  [3:0] alu_op;
    wire [7:0] alu_result;
    wire       alu_cy, alu_ac, alu_ov;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .cy_in  (psw_val[7]),
        .result (alu_result),
        .cy_out (alu_cy),
        .ac_out (alu_ac),
        .ov_out (alu_ov)
    );

    // ===== ALU opcode alias =====
    localparam A_ADD=0, A_ADDC=1, A_SUBB=2, A_MUL=3, A_DIV=4,
               A_DA=5, A_ANL=6, A_ORL=7, A_XRL=8,
               A_INC=9, A_DEC=10, A_CLR=11, A_CPL=12,
               A_RL=13, A_RLC=14, A_RRC=15;

    // ===== Instruction Length Decode =====
    // nbytes = 1, 2, or 3
    wire is_1byte = (ir == 8'h00) ||  // NOP
                    (ir == 8'h03) || (ir == 8'h13) ||  // RR A, RRC A
                    (ir == 8'h23) || (ir == 8'h33) ||  // RL A, RLC A
                    (ir == 8'h04) || (ir == 8'h14) ||  // INC A, DEC A
                    (ir == 8'h06) || (ir == 8'h07) ||  // INC @R0, @R1
                    (ir == 8'h16) || (ir == 8'h17) ||  // DEC @R0, @R1
                    (ir == 8'h22) || (ir == 8'h32) ||  // RET, RETI
                    (ir == 8'hC3) || (ir == 8'hD3) || (ir == 8'hB3) || // CLR/SETB/CPL C
                    (ir == 8'hE4) || (ir == 8'hF4) ||  // CLR A, CPL A
                    (ir == 8'hC4) || (ir == 8'hD4) ||  // SWAP A, DA A
                    (ir == 8'hA4) || (ir == 8'h84) ||  // MUL AB, DIV AB
                    (ir == 8'hA3) ||                   // INC DPTR
                    (ir == 8'h73) ||                   // JMP @A+DPTR
                    (ir == 8'h83) ||                   // MOVC A,@A+PC
                    (ir == 8'h93) ||                   // MOVC A,@A+DPTR
                    (ir == 8'hE0) || (ir == 8'hE2) || (ir == 8'hE3) || // MOVX A,@...
                    (ir == 8'hF0) || (ir == 8'hF2) || (ir == 8'hF3) || // MOVX @...,A
                    (ir[7:3] == 5'b11101) ||  // MOV A,Rn (E8-EF)
                    (ir[7:3] == 5'b11111) ||  // MOV Rn,A (F8-FF)
                    (ir[7:3] == 5'b00001) ||  // INC Rn (08-0F)
                    (ir[7:3] == 5'b00011) ||  // DEC Rn (18-1F)
                    (ir[7:3] == 5'b00101) ||  // ADD A,Rn (28-2F)
                    (ir[7:3] == 5'b00111) ||  // ADDC A,Rn (38-3F)
                    (ir[7:3] == 5'b01001) ||  // ORL A,Rn (48-4F)
                    (ir[7:3] == 5'b01011) ||  // ANL A,Rn (58-5F)
                    (ir[7:3] == 5'b01101) ||  // XRL A,Rn (68-6F)
                    (ir[7:3] == 5'b10011) ||  // SUBB A,Rn (98-9F)
                    (ir[7:3] == 5'b11001) ||  // XCH A,Rn (C8-CF)
                    (ir == 8'h26) || (ir == 8'h27) || // ADD A,@R0/@R1
                    (ir == 8'h36) || (ir == 8'h37) || // ADDC A,@R0/@R1
                    (ir == 8'h46) || (ir == 8'h47) || // ORL A,@R0/@R1
                    (ir == 8'h56) || (ir == 8'h57) || // ANL A,@R0/@R1
                    (ir == 8'h66) || (ir == 8'h67) || // XRL A,@R0/@R1
                    (ir == 8'h96) || (ir == 8'h97) || // SUBB A,@R0/@R1
                    (ir == 8'hE6) || (ir == 8'hE7) || // MOV A,@R0/@R1
                    (ir == 8'hF6) || (ir == 8'hF7) || // MOV @R0/@R1,A
                    (ir == 8'hC6) || (ir == 8'hC7) || // XCH A,@R0/@R1
                    (ir == 8'hD6) || (ir == 8'hD7);   // XCHD A,@R0/@R1

    wire is_2byte = (ir == 8'h80) ||  // SJMP
                    (ir[7:3] == 5'b01111) ||  // MOV Rn,#imm (78-7F)
                    (ir == 8'h74) ||   // MOV A,#imm
                    (ir == 8'h24) || (ir == 8'h34) ||  // ADD/ADDC A,#imm
                    (ir == 8'h94) ||   // SUBB A,#imm
                    (ir == 8'h54) || (ir == 8'h44) || (ir == 8'h64) || // ANL/ORL/XRL A,#imm
                    (ir == 8'h04) || (ir == 8'h14) ||  // INC/DEC A (already in 1-byte!)
                    (ir == 8'h40) || (ir == 8'h50) ||  // JC, JNC
                    (ir == 8'h60) || (ir == 8'h70) ||  // JZ, JNZ
                    (ir == 8'hC0) || (ir == 8'hD0) ||  // PUSH direct, POP direct
                    (ir == 8'hC2) || (ir == 8'hD2) || (ir == 8'hB2) || // CLR/SETB/CPL bit
                    (ir == 8'hA2) || (ir == 8'h92) ||  // MOV C,bit; MOV bit,C
                    (ir == 8'h72) || (ir == 8'hA0) ||  // ORL C,bit; ORL C,/bit
                    (ir == 8'h82) || (ir == 8'hB0) ||  // ANL C,bit; ANL C,/bit
                    (ir == 8'hE5) || (ir == 8'hF5) ||  // MOV A,direct; MOV direct,A
                    (ir == 8'hC5) ||                   // XCH A,direct
                    (ir == 8'h05) || (ir == 8'h15) ||  // INC/DEC direct
                    (ir == 8'h25) || (ir == 8'h35) ||  // ADD/ADDC A,direct
                    (ir == 8'h45) || (ir == 8'h55) || (ir == 8'h65) || // ORL/ANL/XRL A,direct
                    (ir == 8'h95) ||                   // SUBB A,direct
                    (ir == 8'h76) || (ir == 8'h77) ||  // MOV @R0/@R1,#imm
                    (ir == 8'hA6) || (ir == 8'hA7) ||  // MOV @R0/@R1,direct
                    (ir == 8'h86) || (ir == 8'h87) ||  // MOV direct,@R0/@R1
                    (ir[7:3] == 5'b11011) ||  // DJNZ Rn,rel (D8-DF)
                    (ir[7:3] == 5'b10001) ||  // ACALL (11-1F odd)
                    (ir[7:3] == 5'b00000) ||  // AJMP (01-0F odd)... messy
                    (ir == 8'h02) ||          // LJMP... wait LJMP is 3 bytes!
                    (ir == 8'h12);            // LCALL... also 3 bytes!
    // Note: LJMP(02) and LCALL(12) are actually 3 bytes. Fix below.

    wire is_3byte = (ir == 8'h75) ||   // MOV direct,#imm
                    (ir == 8'h85) ||   // MOV direct,direct
                    (ir == 8'h43) || (ir == 8'h53) || (ir == 8'h63) || // ORL/ANL/XRL direct,#imm
                    (ir == 8'hB4) || (ir == 8'hB5) ||  // CJNE A,#imm,rel; CJNE A,direct,rel
                    (ir == 8'hB6) || (ir == 8'hB7) ||  // CJNE @R0/@R1,#imm,rel
                    (ir[7:3] == 5'b10111) ||  // CJNE Rn,#imm,rel (B8-BF)
                    (ir == 8'hD5) ||   // DJNZ direct,rel
                    (ir == 8'h02) ||   // LJMP
                    (ir == 8'h12) ||   // LCALL
                    (ir == 8'h90) ||   // MOV DPTR,#imm16
                    (ir == 8'h10) ||   // JBC bit,rel
                    (ir == 8'h20) || (ir == 8'h30);  // JB/JNB bit,rel

    // ROM data available THIS cycle (combinational read from rom_addr set LAST cycle)
    wire [7:0] rom_byte = rom_data;

    // ===== Main FSM =====
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_FETCH;
            pc       <= 16'd0;
            ir       <= 8'h00;
            op1      <= 8'h00;
            op2      <= 8'h00;
            rom_addr <= 12'd0;
            ale      <= 1'b0;
            psen_n   <= 1'b1;
            sfr_we   <= 1'b0;
            sfr_addr <= 8'd0;
            sfr_wdata<= 8'd0;
            iram_we  <= 1'b0;
            iram_addr<= 7'd0;
            iram_wdata<=8'd0;
            reg_we   <= 1'b0;
            rn_sel   <= 3'd0;
            reg_wdata<= 8'd0;
            acc_fwd_valid <= 1'b0;
            acc_fwd_data  <= 8'd0;
            rn_sel   <= 3'd0;
            reg_we   <= 1'b0;
            reg_wdata<= 8'd0;
            alu_a    <= 8'd0;
            alu_b    <= 8'd0;
            alu_op   <= 4'd0;
        end else begin
            // Default: de-assert strobes
            psen_n  <= 1'b1;
            sfr_we  <= 1'b0;
            iram_we <= 1'b0;
            reg_we  <= 1'b0;
            acc_fwd_valid <= 1'b0;  // forwarding valid for 1 cycle only

            case (state)
                S_FETCH: begin
                    // rom_data has the byte at rom_addr (set in previous cycle or reset)
                    ir <= rom_byte;
                    psen_n <= 1'b0;
                    // Pre-fetch next byte
                    rom_addr <= pc + 12'd1;
                    if (int_ack) begin
                        // Save PC for interrupt return
                        pc <= int_vector;
                    end else begin
                        pc <= pc + 16'd1;
                    end
                    state <= S_EXEC1;
                end

                S_EXEC1: begin
                    psen_n <= 1'b1;
                    op1 <= rom_byte;  // 2nd byte of instruction
                    rom_addr <= pc + 12'd1;  // pre-fetch possible 3rd byte

                    if (is_1byte) begin
                        execute_1byte();
                        state <= S_FETCH;
                        rom_addr <= pc;
                    end else if (is_2byte || is_3byte) begin
                        pc <= pc + 16'd1;
                        state <= S_EXEC2;
                    end else begin
                        state <= S_FETCH;
                        rom_addr <= pc;
                    end
                end

                S_EXEC2: begin
                    if (is_3byte) begin
                        op2 <= rom_byte;
                        rom_addr <= pc + 12'd1;
                        pc <= pc + 16'd1;
                        state <= S_WBACK;
                    end else begin
                        execute_2byte();
                        if (ir == 8'hD0) begin  // POP → S_POP2
                            state <= S_POP2; rom_addr <= pc;
                        end else if ((ir[4:0] == 5'b10001) && ir[7:5] != 3'b000) begin  // ACALL
                            state <= S_ACALL2; rom_addr <= pc;
                        end else if (ir == 8'hC5) begin  // XCH A,direct → S_XCH2
                            state <= S_XCH2; rom_addr <= pc;
                        end else begin
                            state <= S_FETCH; rom_addr <= pc;
                        end
                    end
                end

                S_WBACK: begin
                    execute_3byte();
                    state <= S_FETCH;
                    rom_addr <= pc;
                end

                S_POP2: begin
                    sfr_we <= 1'b1; sfr_addr <= 8'h81; sfr_wdata <= sp - 8'd1;
                    state <= S_FETCH;
                end

                S_ACALL2: begin
                    iram_addr <= sp[6:0] + 7'd2;
                    iram_we <= 1'b1; iram_wdata <= pc[15:8];
                    sfr_we <= 1'b1; sfr_addr <= 8'h81; sfr_wdata <= sp + 8'd2;
                    pc = (pc & 16'hF800) | (({ir[7:5]} << 8) | op1);
                    state <= S_FETCH;
                end

                S_XCH2: begin
                    // Complete XCH A,direct: write SFR[op1] to ACC
                    sfr_addr = op1;  // blocking: read SFR value
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= sfr_rdata;
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= sfr_rdata;
                    state <= S_FETCH;
                end

                default: state <= S_FETCH;
            endcase
        end
    end

    // ===== Instruction Execution Tasks =====

    task execute_1byte;
        begin
            case (ir)
                // NOP
                8'h00: ;

                // MOV A,Rn (E8-EF)
                8'hE8,8'hE9,8'hEA,8'hEB,8'hEC,8'hED,8'hEE,8'hEF: begin
                    rn_sel = ir[2:0];  // blocking: immediate reg_rdata update
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= reg_rdata;
                end
                // MOV Rn,A (F8-FF)
                8'hF8,8'hF9,8'hFA,8'hFB,8'hFC,8'hFD,8'hFE,8'hFF: begin
                    rn_sel = ir[2:0];  // blocking
                    reg_we <= 1'b1; reg_wdata <= eff_acc;
                end
                // INC Rn (08-0F), DEC Rn (18-1F) — inline
                8'h08,8'h09,8'h0A,8'h0B,8'h0C,8'h0D,8'h0E,8'h0F,
                8'h18,8'h19,8'h1A,8'h1B,8'h1C,8'h1D,8'h1E,8'h1F: begin
                    rn_sel = ir[2:0];
                    reg_we <= 1'b1; reg_wdata <= (ir[4] == 1'b1) ? (reg_rdata - 8'd1) : (reg_rdata + 8'd1);
                end
                // ALU A,Rn — inline ops with ACC forwarding
                8'h28,8'h29,8'h2A,8'h2B,8'h2C,8'h2D,8'h2E,8'h2F: begin  // ADD A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc + reg_rdata);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc + reg_rdata); end
                8'h38,8'h39,8'h3A,8'h3B,8'h3C,8'h3D,8'h3E,8'h3F: begin  // ADDC A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc + reg_rdata + psw_val[7]);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc + reg_rdata + psw_val[7]); end
                8'h48,8'h49,8'h4A,8'h4B,8'h4C,8'h4D,8'h4E,8'h4F: begin  // ORL A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc | reg_rdata);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc | reg_rdata); end
                8'h58,8'h59,8'h5A,8'h5B,8'h5C,8'h5D,8'h5E,8'h5F: begin  // ANL A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc & reg_rdata);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc & reg_rdata); end
                8'h68,8'h69,8'h6A,8'h6B,8'h6C,8'h6D,8'h6E,8'h6F: begin  // XRL A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc ^ reg_rdata);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc ^ reg_rdata); end
                8'h98,8'h99,8'h9A,8'h9B,8'h9C,8'h9D,8'h9E,8'h9F: begin  // SUBB A,Rn
                    rn_sel = ir[2:0]; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc - reg_rdata - psw_val[7]);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc - reg_rdata - psw_val[7]); end
                // XCH A,Rn (C8-CF)
                8'hC8,8'hC9,8'hCA,8'hCB,8'hCC,8'hCD,8'hCE,8'hCF: begin
                    rn_sel = ir[2:0];
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= reg_rdata;
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= reg_rdata;
                    reg_we <= 1'b1; reg_wdata <= eff_acc;
                end

                // Rotate — inline
                8'h03: begin  // RR A
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= {eff_acc[0], eff_acc[7:1]};
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= {eff_acc[0], eff_acc[7:1]}; end
                8'h13: begin  // RRC A
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= {psw_val[7], eff_acc[7:1]};
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= {psw_val[7], eff_acc[7:1]}; end
                8'h23: begin  // RL A
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= {eff_acc[6:0], eff_acc[7]};
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= {eff_acc[6:0], eff_acc[7]}; end
                8'h33: begin  // RLC A
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= {eff_acc[6:0], psw_val[7]};
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= {eff_acc[6:0], psw_val[7]}; end

                // INC A, DEC A
                8'h04: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc + 8'd1); acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc + 8'd1); end
                8'h14: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc - 8'd1); acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc - 8'd1); end

                // CLR A, CPL A
                8'hE4: begin acc_fwd_valid <= 1'b1; acc_fwd_data <= 8'h00; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= 8'h00; end
                8'hF4: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= ~eff_acc; acc_fwd_valid <= 1'b1; acc_fwd_data <= ~eff_acc; end

                // SWAP A
                8'hC4: begin acc_fwd_valid <= 1'b1; acc_fwd_data <= {eff_acc[3:0], eff_acc[7:4]}; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= {eff_acc[3:0], eff_acc[7:4]}; end

                // MUL AB, DIV AB — inline ops
                8'hA4: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= eff_acc * b_reg; acc_fwd_valid <= 1'b1; acc_fwd_data <= eff_acc * b_reg; end
                8'h84: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (b_reg == 8'd0) ? 8'hFF : (eff_acc / b_reg); acc_fwd_valid <= 1'b1; acc_fwd_data <= (b_reg == 8'd0) ? 8'hFF : (eff_acc / b_reg); end

                // INC DPTR
                8'hA3: begin sfr_we <= 1'b1; sfr_addr <= 8'h83; sfr_wdata <= sfr_rdata + 8'd1; end

                // MOVC A,@A+PC (83); MOVC A,@A+DPTR (93)
                8'h83: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= rom_data; end  // rom_data at pc+acc
                8'h93: begin sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= rom_data; acc_fwd_valid<=1'b1; acc_fwd_data<=rom_data; end

                // MOVX A,@DPTR (E0); MOVX A,@R0 (E2); MOVX A,@R1 (E3)
                8'hE0,8'hE2,8'hE3: begin sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=8'h00; acc_fwd_valid<=1'b1;acc_fwd_data<=8'h00; end
                // MOVX @DPTR,A (F0); MOVX @R0,A (F2); MOVX @R1,A (F3)
                8'hF0,8'hF2,8'hF3: begin /* XRAM write — not modeled */ end

                // JMP @A+DPTR (73)
                8'h73: pc = sfr_rdata + acc;  // simplified: use DPTR value

                // SETB C, CLR C, CPL C
                8'hD3: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val | 8'h80; end
                8'hC3: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val & 8'h7F; end
                8'hB3: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val ^ 8'h80; end

                // MOV A,@R0 (E6) / MOV A,@R1 (E7)
                8'hE6,8'hE7: begin
                    rn_sel = (ir == 8'hE6) ? 3'd0 : 3'd1;
                    iram_addr <= reg_rdata[6:0];
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= iram_rdata;
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= iram_rdata;
                end
                8'hF6,8'hF7: begin
                    rn_sel = (ir == 8'hF6) ? 3'd0 : 3'd1;
                    iram_addr <= reg_rdata[6:0];
                    iram_we <= 1'b1; iram_wdata <= eff_acc;
                end
                // ALU A,@Ri: ADD(26-27), ADDC(36-37), ORL(46-47), ANL(56-57), XRL(66-67), SUBB(96-97)
                8'h26,8'h27: begin rn_sel=(ir==8'h26)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc+iram_rdata);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc+iram_rdata); end
                8'h36,8'h37: begin rn_sel=(ir==8'h36)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc+iram_rdata+psw_val[7]);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc+iram_rdata+psw_val[7]); end
                8'h46,8'h47: begin rn_sel=(ir==8'h46)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc|iram_rdata);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc|iram_rdata); end
                8'h56,8'h57: begin rn_sel=(ir==8'h56)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc&iram_rdata);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc&iram_rdata); end
                8'h66,8'h67: begin rn_sel=(ir==8'h66)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc^iram_rdata);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc^iram_rdata); end
                8'h96,8'h97: begin rn_sel=(ir==8'h96)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc-iram_rdata-psw_val[7]);
                    acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc-iram_rdata-psw_val[7]); end
                // INC @Ri(06-07), DEC @Ri(16-17)
                8'h06,8'h07: begin rn_sel=(ir==8'h06)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    iram_we<=1'b1; iram_wdata<=(iram_rdata+8'd1); end
                8'h16,8'h17: begin rn_sel=(ir==8'h16)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    iram_we<=1'b1; iram_wdata<=(iram_rdata-8'd1); end
                // XCH A,@Ri(C6-C7), XCHD A,@Ri(D6-D7)
                8'hC6,8'hC7: begin rn_sel=(ir==8'hC6)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=iram_rdata;
                    acc_fwd_valid<=1'b1;acc_fwd_data<=iram_rdata;
                    iram_we<=1'b1; iram_wdata<=eff_acc; end
                8'hD6,8'hD7: begin rn_sel=(ir==8'hD6)?3'd0:3'd1; iram_addr<=reg_rdata[6:0];
                    sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<={(eff_acc&8'hF0),(iram_rdata&8'h0F)};
                    acc_fwd_valid<=1'b1;acc_fwd_data<={(eff_acc&8'hF0),(iram_rdata&8'h0F)};
                    iram_we<=1'b1; iram_wdata<={(iram_rdata&8'hF0),(eff_acc&8'h0F)}; end
                // MOV direct,@Ri (86-87) — handled in execute_2byte
                // MOV @Ri,direct (A6-A7) — handled in execute_2byte

                // RET, RETI
                8'h22,8'h32: begin
                    sfr_we <= 1'b1; sfr_addr <= 8'h81; sfr_wdata <= sp - 8'd2;
                end

                default: ; // undefined → NOP
            endcase
        end
    endtask

    task execute_2byte;
        begin
            case (ir)
                // MOV A,#imm
                8'h74: begin acc_fwd_valid <= 1'b1; acc_fwd_data <= op1; sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= op1; end

                // MOV Rn,#imm (78-7F)
                8'h78,8'h79,8'h7A,8'h7B,8'h7C,8'h7D,8'h7E,8'h7F: begin
                    rn_sel = ir[2:0];  // blocking
                    reg_we <= 1'b1; reg_wdata <= op1;
                end

                // ALU with #imm — inline ops + ACC forwarding
                8'h24: begin  // ADD A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc + op1);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc + op1); end
                8'h34: begin  // ADDC A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc + op1 + psw_val[7]);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc + op1 + psw_val[7]); end
                8'h94: begin  // SUBB A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc - op1 - psw_val[7]);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc - op1 - psw_val[7]); end
                8'h54: begin  // ANL A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc & op1);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc & op1); end
                8'h44: begin  // ORL A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc | op1);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc | op1); end
                8'h64: begin  // XRL A,#imm
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= (eff_acc ^ op1);
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= (eff_acc ^ op1); end

                // MOV A,direct — read SFR at op1, write to ACC
                8'hE5: begin
                    sfr_we <= 1'b1; sfr_addr <= 8'hE0; sfr_wdata <= sfr_rdata;
                    acc_fwd_valid <= 1'b1; acc_fwd_data <= sfr_rdata;
                end
                // MOV direct,A — output ACC to SFR
                8'hF5: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= eff_acc; end

                // INC direct (05), DEC direct (15)
                8'h05: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata + 8'd1; end
                8'h15: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata - 8'd1; end

                // ALU A,direct: ADD(25), ADDC(35), SUBB(95), ANL(55), ORL(45), XRL(65)
                8'h25: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc+sfr_rdata); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc+sfr_rdata); end
                8'h35: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc+sfr_rdata+psw_val[7]); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc+sfr_rdata+psw_val[7]); end
                8'h95: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc-sfr_rdata-psw_val[7]); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc-sfr_rdata-psw_val[7]); end
                8'h55: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc&sfr_rdata); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc&sfr_rdata); end
                8'h45: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc|sfr_rdata); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc|sfr_rdata); end
                8'h65: begin sfr_addr=op1; sfr_we<=1'b1;sfr_addr<=8'hE0;sfr_wdata<=(eff_acc^sfr_rdata); acc_fwd_valid<=1'b1;acc_fwd_data<=(eff_acc^sfr_rdata); end

                // MOV C,bit (A2), MOV bit,C (92)
                8'hA2: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= (psw_val & 8'h7F) | (sfr_rdata[op1[2:0]] ? 8'h80 : 8'h00); end
                8'h92: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata; /* simplified */ end

                // CLR bit (C2), SETB bit (D2), CPL bit (B2)
                8'hC2: begin sfr_we <= 1'b1; sfr_addr <= op1; /* write 0 to bit */ sfr_wdata <= sfr_rdata & ~(8'd1 << op1[2:0]); end
                8'hD2: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata | (8'd1 << op1[2:0]); end
                8'hB2: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata ^ (8'd1 << op1[2:0]); end

                // ANL C,bit (82), ORL C,bit (72), ANL C,/bit (B0), ORL C,/bit (A0)
                8'h82: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val ^ (psw_val[7] & ~sfr_rdata[op1[2:0]] ? 8'h80 : 8'h00); end
                8'h72: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val | (sfr_rdata[op1[2:0]] ? 8'h80 : 8'h00); end
                8'hB0: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val ^ (psw_val[7] & sfr_rdata[op1[2:0]] ? 8'h80 : 8'h00); end
                8'hA0: begin sfr_we <= 1'b1; sfr_addr <= 8'hD0; sfr_wdata <= psw_val | (~sfr_rdata[op1[2:0]] ? 8'h80 : 8'h00); end

                // SJMP — blocking so rom_addr captures new pc
                8'h80: pc = pc + {{8{op1[7]}}, op1};

                // AJMP addr11 (01,21,41,61,81,A1,C1,E1) — 2KB page jump
                8'h01,8'h21,8'h41,8'h61,8'h81,8'hA1,8'hC1,8'hE1:
                    pc = (pc & 16'hF800) | (({ir[7:5]} << 8) | op1);

                // ACALL addr11 (11,31,51,71,91,B1,D1,F1) — 2-cycle push
                8'h11,8'h31,8'h51,8'h71,8'h91,8'hB1,8'hD1,8'hF1: begin
                    iram_addr <= sp[6:0] + 7'd1;
                    iram_we <= 1'b1; iram_wdata <= pc[7:0];  // push PC low
                    // PC high + SP update + jump in S_ACALL2
                end

                // JZ, JNZ, JC, JNC — blocking pc for rom_addr update
                8'h60: if (acc == 8'd0) pc = pc + {{8{op1[7]}}, op1};
                8'h70: if (acc != 8'd0) pc = pc + {{8{op1[7]}}, op1};
                8'h40: if (psw_val[7]) pc = pc + {{8{op1[7]}}, op1};
                8'h50: if (!psw_val[7]) pc = pc + {{8{op1[7]}}, op1};

                // PUSH direct — blocking sfr_addr read, then IRAM + SP writes
                8'hC0: begin
                    // Read source SFR: set sfr_addr blocking for combinational read
                    sfr_addr = op1;  // blocking: sfr_rdata updates immediately
                    iram_addr <= sp[6:0] + 7'd1;
                    iram_we <= 1'b1;
                    iram_wdata <= (op1 == 8'hE0) ? eff_acc : sfr_rdata;
                    // Write SP (overwrites sfr_addr with non-blocking)
                    sfr_we <= 1'b1; sfr_addr <= 8'h81; sfr_wdata <= sp + 8'd1;
                end
                // POP direct — 2-cycle: S_EXEC2 writes target SFR, S_POP2 updates SP
                8'hD0: begin
                    iram_addr <= sp[6:0];
                    sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= iram_rdata;
                    if (op1 == 8'hE0) begin acc_fwd_valid <= 1'b1; acc_fwd_data <= iram_rdata; end
                    // Don't write SP here — handled in S_POP2
                end

                // DJNZ Rn,rel (D8-DF) — blocking pc, inline dec
                8'hD8,8'hD9,8'hDA,8'hDB,8'hDC,8'hDD,8'hDE,8'hDF: begin
                    rn_sel = ir[2:0];
                    reg_we <= 1'b1; reg_wdata <= (reg_rdata - 8'd1);
                    if ((reg_rdata - 8'd1) != 8'd0)
                        pc = pc + {{8{op1[7]}}, op1};
                end

                // MOV @R0,#imm (76) / MOV @R1,#imm (77)
                8'h76,8'h77: begin rn_sel=(ir==8'h76)?3'd0:3'd1; iram_addr<=reg_rdata[6:0]; iram_we<=1'b1; iram_wdata<=op1; end
                // MOV direct,@Ri (86-87): write IRAM[Ri] to SFR[direct]
                8'h86,8'h87: begin rn_sel=(ir==8'h86)?3'd0:3'd1; iram_addr<=reg_rdata[6:0]; sfr_we<=1'b1; sfr_addr<=op1; sfr_wdata<=iram_rdata; end
                // MOV @Ri,direct (A6-A7): write SFR[direct] to IRAM[Ri]
                8'hA6,8'hA7: begin rn_sel=(ir==8'hA6)?3'd0:3'd1; iram_addr<=reg_rdata[6:0]; sfr_addr=op1; iram_we<=1'b1; iram_wdata<=sfr_rdata; end
                // XCH A,direct (C5) — 2-cycle: write ACC→direct now, direct→ACC in S_XCH2
                8'hC5: begin
                    sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= eff_acc;  // ACC → direct
                    // direct → ACC handled in S_XCH2
                end

                // INC direct, DEC direct
                8'h05: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata + 8'd1; end
                8'h15: begin sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata - 8'd1; end

                default: ; // undefined
            endcase
        end
    endtask

    task execute_3byte;
        begin
            case (ir)
                // MOV direct,#imm (0x75)
                8'h75: begin sfr_we<=1'b1; sfr_addr<=op1; sfr_wdata<=op2; end

                // MOV direct,direct (0x85)
                8'h85: begin sfr_we<=1'b1; sfr_addr<=op1; sfr_wdata<=sfr_rdata; end

                // LJMP (0x02)
                8'h02: pc = {op1, op2};

                // LCALL (0x12)
                8'h12: begin
                    iram_addr <= sp[6:0] + 7'd1; iram_we <= 1'b1; iram_wdata <= pc[7:0];
                    sfr_we <= 1'b1; sfr_addr <= 8'h81; sfr_wdata <= sp + 8'd2;
                    pc = {op1, op2};
                end

                // MOV DPTR,#imm16 (0x90)
                8'h90: begin
                    sfr_we <= 1'b1; sfr_addr <= 8'h83; sfr_wdata <= op1;  // DPH
                end

                // JB bit,rel (0x20), JNB bit,rel (0x30), JBC bit,rel (0x10)
                8'h20,8'h30,8'h10: begin
                    sfr_addr = op1;  // blocking: read byte containing the bit
                    if ((ir==8'h20 && sfr_rdata[op1[2:0]]) ||   // JB: jump if bit=1
                        (ir==8'h30 && !sfr_rdata[op1[2:0]]) ||  // JNB: jump if bit=0
                        (ir==8'h10 && sfr_rdata[op1[2:0]])) begin // JBC: jump if bit=1 then clear
                        if (ir==8'h10) begin sfr_we<=1'b1; sfr_addr<=op1; sfr_wdata<=sfr_rdata & ~(8'd1<<op1[2:0]); end
                        pc = pc + {{8{op2[7]}}, op2};
                    end
                end

                // CJNE A,#imm,rel (0xB4), CJNE A,direct,rel (0xB5)
                // CJNE @R0,#imm,rel (0xB6), CJNE @R1,#imm,rel (0xB7)
                // CJNE Rn,#imm,rel (0xB8-0xBF)
                8'hB4,8'hB5,8'hB6,8'hB7,8'hB8,8'hB9,8'hBA,8'hBB,
                8'hBC,8'hBD,8'hBE,8'hBF: begin
                    sfr_we <= 1'b1; sfr_addr <= 8'hD0;  // for CY update
                    case (ir)
                        8'hB4: begin if (eff_acc != op1) pc = pc + {{8{op2[7]}}, op2}; if (eff_acc < op1) sfr_wdata <= psw_val | 8'h80; else sfr_wdata <= psw_val & 8'h7F; end
                        8'hB5: begin sfr_addr = op1; if (eff_acc != sfr_rdata) pc = pc + {{8{op2[7]}}, op2}; if (eff_acc < sfr_rdata) sfr_wdata <= psw_val | 8'h80; else sfr_wdata <= psw_val & 8'h7F; end
                        8'hB6,8'hB7: begin rn_sel=(ir==8'hB6)?3'd0:3'd1; if (reg_rdata!=op1) pc=pc+{{8{op2[7]}},op2}; if (reg_rdata<op1) sfr_wdata<=psw_val|8'h80; else sfr_wdata<=psw_val&8'h7F; end
                        default: begin rn_sel=ir[2:0]; if (reg_rdata!=op1) pc=pc+{{8{op2[7]}},op2}; if (reg_rdata<op1) sfr_wdata<=psw_val|8'h80; else sfr_wdata<=psw_val&8'h7F; end
                    endcase
                end

                // DJNZ direct,rel (0xD5)
                8'hD5: begin
                    sfr_we <= 1'b1; sfr_addr <= op1; sfr_wdata <= sfr_rdata - 8'd1;
                    if ((sfr_rdata - 8'd1) != 8'd0) pc = pc + {{8{op2[7]}}, op2};
                end

                default: ;
            endcase
        end
    endtask

endmodule
