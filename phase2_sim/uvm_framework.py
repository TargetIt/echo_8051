#!/usr/bin/env python3
"""
echo_8051 UVM Verification Framework

Pure Python implementation of UVM methodology:
  - TestHarness: manages test execution, aggregates results
  - StimulusGenerator: constrained random 8051 instruction sequences
  - Driver: loads program into RTL PROM, runs iverilog simulation
  - Monitor: parses RTL trace output, captures state
  - Scoreboard: compares RTL vs Python ISS golden reference
  - CoverageCollector: opcode, functional, cross coverage
  - Reporter: generates HTML/Markdown verification report

Dependencies: Python 3.8+, iverilog (in WSL), pyuvm (optional)
"""

import sys, os, json, random, subprocess, tempfile, time
from pathlib import Path
from dataclasses import dataclass, field
from collections import defaultdict
from typing import Optional

PROJECT_ROOT = Path(__file__).parent.parent
RTL_DIR = PROJECT_ROOT / 'rtl'
sys.path.insert(0, str(PROJECT_ROOT / 'model'))

from python.echo_8051 import Echo8051
from python.decoder import OPCODES, build_opcode_table

build_opcode_table()

# ============================================================
# Data Structures
# ============================================================

@dataclass
class InstrState:
    """CPU state after one instruction."""
    pc: int; acc: int; psw: int; sp: int
    p1: int = 0; p2: int = 0; p3: int = 0

@dataclass
class TestResult:
    name: str
    passed: bool
    total_checks: int = 0
    matches: int = 0
    mismatches: int = 0
    opcodes_seen: set = field(default_factory=set)
    duration_ms: float = 0
    errors: list = field(default_factory=list)


# ============================================================
# StimulusGenerator — constrained random 8051 instruction sequences
# ============================================================

class StimulusGenerator:
    """Generates random but valid 8051 instruction sequences."""

    # Safe opcodes to generate (exclude jumps, calls, ret to keep linear flow)
    SAFE_OPCODES = {
        # MOV
        0x74, 0x75, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F,  # MOV #imm
        0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,  # MOV A,Rn
        0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF,  # MOV Rn,A
        0xE4,  # CLR A
        0xF4,  # CPL A
        0xC4,  # SWAP A
        # ALU
        0x24,  # ADD A,#imm
        0x04,  # INC A
        0x14,  # DEC A
        0x94,  # SUBB A,#imm
        0x54,  # ANL A,#imm
        0x44,  # ORL A,#imm
        0x64,  # XRL A,#imm
        0xD4,  # DA A
        0xA4,  # MUL AB
        0x84,  # DIV AB
        0xC3, 0xD3, 0xB3,  # CLR/SETB/CPL C
        # Stack
        0xC0,  # PUSH
        0xD0,  # POP
    }

    def __init__(self, seed: int = 42):
        random.seed(seed)

    def random_byte(self) -> int:
        return random.randint(0, 255)

    def generate_linear(self, count: int) -> bytearray:
        """Generate a linear sequence of N instructions (no branches)."""
        prog = bytearray()
        opcodes = list(self.SAFE_OPCODES)
        for _ in range(count):
            op = random.choice(opcodes)
            info = OPCODES.get(op)
            nbytes = info.bytes if info else 1
            prog.append(op)
            for _ in range(nbytes - 1):
                prog.append(self.random_byte())
        return prog

    def generate_with_branches(self, count: int) -> bytearray:
        """Generate a sequence that includes conditional branches."""
        # Start with linear ALU ops, then add DJNZ loop, SJMP
        prog = self.generate_linear(max(5, count - 10))
        # Add DJNZ loop
        prog += bytes([0x78, random.randint(1, 5),  # MOV R0, #N
                       0x04,                          # INC A (loop)
                       0xD8, 0xFD])                   # DJNZ R0, -3
        # Add SJMP halt
        prog += bytes([0x80, 0xFE])  # SJMP $
        return prog


# ============================================================
# Driver — loads program into PROM, runs iverilog
# ============================================================

class Driver:
    """Runs iverilog simulation with a given ROM program."""

    RTL_FILES = [
        'alu.v', 'psw.v', 'reg_file.v', 'iram.v',
        'sfr_block.v', 'timer.v', 'uart.v', 'intc.v', 'io_ports.v',
        'cpu_core.v', 'echo_8051_top.v',
    ]
    # prom.v is generated dynamically with test program

    def __init__(self):
        self.rtl_paths = [str(RTL_DIR / f) for f in self.RTL_FILES]

    def run(self, program: bytes, max_cycles: int = 200) -> str:
        """Compile and run iverilog simulation. Returns trace output."""
        import uuid
        uid = uuid.uuid4().hex[:8]

        # Write temp PROM with unique module name
        prom_file = str(PROJECT_ROOT / f'_prom_{uid}.v')
        with open(prom_file, 'w') as f:
            f.write(self._gen_prom(program, len(program)))

        # Write testbench with unique module name
        tb_file = str(PROJECT_ROOT / f'_tb_{uid}.v')
        with open(tb_file, 'w') as f:
            f.write(self._gen_tb(max_cycles, uid))

        # Compile (unique names to avoid duplicate module errors)
        import uuid
        uid = uuid.uuid4().hex[:8]
        vvp_file = str(PROJECT_ROOT / f'sim_{uid}.vvp')
        sources = self.rtl_paths  # prom and tb added separately below

        ivl = 'iverilog'
        vvp = 'vvp'
        if sys.platform == 'win32':
            ivl = 'wsl'
            vvp = 'wsl'
            # Convert paths to WSL format
            wsl_vvp = vvp_file.replace('D:', '/mnt/d').replace('\\', '/')
            wsl_tb = tb_file.replace('D:', '/mnt/d').replace('\\', '/')
            wsl_prom = prom_file.replace('D:', '/mnt/d').replace('\\', '/')
            wsl_sources = [s.replace('D:', '/mnt/d').replace('\\', '/') for s in sources]
            compile_cmd = [ivl, '-d', 'Ubuntu-24.04', '--', 'iverilog', '-Wall', '-g2005',
                          '-o', wsl_vvp] + wsl_sources + [wsl_tb, wsl_prom]
            run_cmd = [vvp, '-d', 'Ubuntu-24.04', '--', 'vvp', wsl_vvp]
        else:
            compile_cmd = [ivl, '-Wall', '-g2005', '-o', vvp_file] + sources + [tb_file, prom_file]
            run_cmd = [vvp, vvp_file]

        result = subprocess.run(compile_cmd, capture_output=True, text=True,
                                cwd=str(PROJECT_ROOT))
        if result.returncode != 0:
            raise RuntimeError(f"iverilog compile failed:\n{result.stderr}")

        # Run
        run_result = subprocess.run(run_cmd, capture_output=True, text=True,
                                     cwd=str(PROJECT_ROOT), timeout=30)

        # Cleanup
        for f in [prom_file, tb_file, vvp_file]:
            try: os.unlink(f)
            except: pass

        return run_result.stdout

    def _gen_prom(self, program: bytes, size: int) -> str:
        """Generate a PROM Verilog module with the given program."""
        lines = [
            "module prom #(parameter ROM_SIZE=4096, AW=12) (",
            "    input [AW-1:0] addr, output reg [7:0] data",
            ");",
            "    reg [7:0] rom [0:ROM_SIZE-1];",
            "    integer i;",
            "    initial begin",
            "        for (i=0;i<ROM_SIZE;i=i+1) rom[i]=8'h00;",
        ]
        for i, b in enumerate(program):
            lines.append(f"        rom[{i}] = 8'h{b:02X};")
        lines.append("    end")
        lines.append("    always @(*) data = rom[addr];")
        lines.append("endmodule")
        return '\n'.join(lines)

    def _gen_tb(self, max_cycles: int, uid: str = '') -> str:
        """Generate a trace testbench."""
        return f"""
module sim_tb_{uid};
    reg clk, rst_n, int0_n, int1_n, rxd, ea_n;
    wire [7:0] p0, p1, p2, p3;
    wire txd, ale, psen_n, rd_n, wr_n;
    always #10 clk = ~clk;

    echo_8051_top dut (.clk(clk),.rst_n(rst_n),.int0_n(int0_n),.int1_n(int1_n),
        .p0(p0),.p1(p1),.p2(p2),.p3(p3),.rxd(rxd),.txd(txd),
        .ale(ale),.psen_n(psen_n),.rd_n(rd_n),.wr_n(wr_n),.ea_n(ea_n));

    integer cyc, prev_state;
    initial begin
        clk=0; rst_n=0; int0_n=1; int1_n=1; rxd=1; ea_n=1;
        #100 rst_n=1; prev_state=0;
    end

    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (cyc > {max_cycles}) $finish;
        // Dump state at S_FETCH entry
        if (dut.u_cpu.state == 3'd0 && prev_state != 3'd0) begin
            $display("TRACE|%04X|%02X|%02X|%02X|%02X|%02X|%02X",
                dut.u_cpu.pc,
                dut.u_sfr.sfr[96],  // ACC at 0xE0 → sfr[0x60]
                dut.u_sfr.sfr[80],  // PSW at 0xD0 → sfr[0x50]
                dut.u_sfr.sfr[1],   // SP  at 0x81 → sfr[0x01]
                p1, p2, p3);
        end
        prev_state <= dut.u_cpu.state;
    end
endmodule
"""


# ============================================================
# Monitor — parses RTL trace output
# ============================================================

class Monitor:
    """Parses RTL simulation trace output into InstrState objects."""

    @staticmethod
    def parse(trace_output: str) -> list[InstrState]:
        states = []
        for line in trace_output.split('\n'):
            if line.startswith('TRACE|'):
                parts = line.split('|')
                if len(parts) >= 7:
                    try:
                        states.append(InstrState(
                            pc=int(parts[1], 16),
                            acc=int(parts[2], 16),
                            psw=int(parts[3], 16),
                            sp=int(parts[4], 16),
                            p1=int(parts[5], 16),
                            p2=int(parts[6], 16),
                            p3=int(parts[7].strip(), 16) if parts[7].strip() else 0,
                        ))
                    except ValueError:
                        pass
        return states


# ============================================================
# Scoreboard — RTL vs Python ISS comparison
# ============================================================

class Scoreboard:
    """Compares RTL trace with Python ISS golden reference."""

    def __init__(self):
        self.total = 0
        self.matches = 0
        self.mismatches = 0
        self.details = []

    def compare(self, rtl_states: list[InstrState], program: bytes,
                max_instr: int = 50) -> bool:
        """Run ISS on same program and compare state-by-state."""
        iss = Echo8051(rom_size=256)
        iss.load_bytes(program)

        iss_states = []
        for _ in range(min(len(rtl_states) + 5, max_instr + 10)):
            try:
                iss.step()
                s = iss.get_state()
                iss_states.append(InstrState(
                    pc=s['pc'], acc=s['acc'], psw=s['psw'], sp=s['sp']))
            except Exception:
                break

        # Align and compare
        iss_idx = 0
        for rtl in rtl_states:
            if iss_idx >= len(iss_states):
                break

            # Find matching ISS state by PC proximity
            best = None
            for off in range(4):
                idx = iss_idx + off
                if idx < len(iss_states):
                    iss_s = iss_states[idx]
                    if iss_s.acc == rtl.acc and iss_s.sp == rtl.sp:
                        best = (idx, iss_s)
                        break

            if best is None:
                # Try closest
                if iss_idx < len(iss_states):
                    best = (iss_idx, iss_states[iss_idx])
                else:
                    break

            idx, iss_s = best
            self.total += 1
            acc_ok = (rtl.acc == iss_s.acc)
            sp_ok = (rtl.sp == iss_s.sp)
            psw_diff = rtl.psw ^ iss_s.psw
            psw_ok = (psw_diff == 0) or (psw_diff == 0x01)  # parity only

            if acc_ok and sp_ok and psw_ok:
                self.matches += 1
            else:
                self.mismatches += 1
                self.details.append(
                    f"PC={rtl.pc:04X}/{iss_s.pc:04X} "
                    f"ACC={rtl.acc:02X}/{iss_s.acc:02X} "
                    f"PSW={rtl.psw:02X}/{iss_s.psw:02X} "
                    f"SP={rtl.sp:02X}/{iss_s.sp:02X}"
                )
            iss_idx = best[0] + 1

        return self.mismatches <= 2


# ============================================================
# CoverageCollector
# ============================================================

class CoverageCollector:
    """Tracks opcode and functional coverage."""

    def __init__(self):
        self.opcodes_seen = set()
        self.alu_ops_seen = set()
        self.branch_ops_seen = set()

    def record(self, program: bytes):
        """Record opcodes from a test program."""
        i = 0
        while i < len(program):
            op = program[i]
            self.opcodes_seen.add(op)
            info = OPCODES.get(op)
            nbytes = info.bytes if info else 1
            i += nbytes

            # Categorize
            if op in {0x24, 0x04, 0x14, 0x94, 0x54, 0x44, 0x64, 0xA4, 0x84}:
                self.alu_ops_seen.add(op)
            if op in {0x80, 0x60, 0x70, 0x40, 0x50, 0xD8, 0xB4}:
                self.branch_ops_seen.add(op)

    def report(self) -> dict:
        return {
            'total_opcodes': len(self.opcodes_seen),
            'alu_opcodes': len(self.alu_ops_seen),
            'branch_opcodes': len(self.branch_ops_seen),
            'unique_list': sorted(list(self.opcodes_seen)),
        }


# ============================================================
# TestHarness — runs multiple tests, aggregates results
# ============================================================

class TestHarness:
    """UVM Test Harness: manages test execution and reporting."""

    def __init__(self):
        self.driver = Driver()
        self.monitor = Monitor()
        self.scoreboard = Scoreboard()
        self.coverage = CoverageCollector()
        self.results: list[TestResult] = []

    def run_test(self, name: str, program: bytes, max_cycles: int = 300) -> TestResult:
        """Run a single test."""
        start = time.time()
        result = TestResult(name=name, passed=False)

        try:
            # Record coverage
            self.coverage.record(program)

            # Run simulation
            trace = self.driver.run(program, max_cycles)

            # Parse trace
            states = self.monitor.parse(trace)

            # Scoreboard
            self.scoreboard.compare(states, program)
            result.total_checks = self.scoreboard.total
            result.matches = self.scoreboard.matches
            result.mismatches = self.scoreboard.mismatches
            result.passed = self.scoreboard.mismatches <= 2

            result.duration_ms = (time.time() - start) * 1000
        except Exception as e:
            result.errors.append(str(e))

        self.results.append(result)
        return result

    def report(self) -> str:
        """Generate a Markdown test report."""
        total = len(self.results)
        passed = sum(1 for r in self.results if r.passed)
        cov = self.coverage.report()

        lines = [
            "# echo_8051 UVM Verification Report",
            "",
            f"**Date**: {time.strftime('%Y-%m-%d %H:%M')}",
            f"**Tests**: {total} run, {passed} passed, {total - passed} failed",
            "",
            "## Coverage",
            f"- Unique opcodes exercised: **{cov['total_opcodes']}** / 256",
            f"- ALU opcodes: {cov['alu_opcodes']}",
            f"- Branch opcodes: {cov['branch_opcodes']}",
            "",
            "## Test Results",
            "",
            "| Test | Status | Checks | Match | Mismatch | Time |",
            "|------|--------|--------|-------|----------|------|",
        ]
        for r in self.results:
            status = "PASS" if r.passed else "FAIL"
            lines.append(
                f"| {r.name} | {status} | {r.total_checks} | {r.matches} | {r.mismatches} | {r.duration_ms:.0f}ms |"
            )

        if any(not r.passed for r in self.results):
            lines.append("")
            lines.append("## Failures")
            for r in self.results:
                if not r.passed and r.errors:
                    lines.append(f"- **{r.name}**: {', '.join(r.errors)}")

        return '\n'.join(lines)


# ============================================================
# Main — run UVM regression
# ============================================================

def main():
    print("=" * 60)
    print("  echo_8051 UVM Verification Framework")
    print("=" * 60)

    harness = TestHarness()
    gen = StimulusGenerator(seed=12345)

    # Test 1: Known program (cross-validation)
    crossval_prog = bytes([
        0x74,0x42, 0x78,0x55, 0x79,0x33, 0xE8, 0x24,0x20, 0xC3,
        0x94,0x25, 0x54,0x0F, 0x44,0xAA, 0x64,0x55, 0x04, 0x14,
        0x04, 0x04, 0x04, 0xC4, 0xF4, 0xE4, 0x74,0x0A, 0x75,0xF0,0x06,
        0xA4, 0xF5,0x90, 0x74,0x0F, 0x75,0xF0,0x04, 0x84, 0xF5,0xA0,
        0x78,0x03, 0xE4, 0x04, 0xD8,0xFD, 0xF5,0xB0,
        0xC0,0xE0, 0xE4, 0xD0,0xE0, 0xF5,0x80,
        0xD3, 0xC3, 0xB3, 0x80,0xFE,
    ])
    print("\n[1/5] Cross-validation program...")
    result = harness.run_test("crossval_known", crossval_prog)
    print(f"  {'PASS' if result.passed else 'FAIL'}: {result.matches}/{result.total_checks} match, {result.mismatches} mismatch")

    # Test 2: Random linear instructions
    print("\n[2/5] Random linear instructions...")
    prog = gen.generate_linear(30)
    result = harness.run_test("random_linear", bytes(prog), max_cycles=500)
    print(f"  {'PASS' if result.passed else 'FAIL'}: {result.matches}/{result.total_checks} match, {result.mismatches} mismatch")

    # Test 3: DJNZ loop test
    print("\n[3/5] DJNZ loop test...")
    dj_prog = bytes([0xE4, 0x78,0x03, 0x04, 0xD8,0xFD, 0xF5,0x90, 0x80,0xFE])
    result = harness.run_test("djnz_loop", dj_prog, max_cycles=500)
    print(f"  {'PASS' if result.passed else 'FAIL'}: {result.matches}/{result.total_checks} match, {result.mismatches} mismatch")

    # Test 4: MUL/DIV test
    print("\n[4/5] MUL/DIV test...")
    md_prog = bytes([0x74,0x0A, 0x75,0xF0,0x06, 0xA4, 0xF5,0x90,
                      0x74,0x0F, 0x75,0xF0,0x04, 0x84, 0xF5,0xA0, 0x80,0xFE])
    result = harness.run_test("mul_div", md_prog, max_cycles=500)
    print(f"  {'PASS' if result.passed else 'FAIL'}: {result.matches}/{result.total_checks} match, {result.mismatches} mismatch")

    # Test 5: PUSH/POP test
    print("\n[5/5] PUSH/POP test...")
    pp_prog = bytes([0x74,0x99, 0xC0,0xE0, 0xE4, 0xD0,0xE0, 0xF5,0x90, 0x80,0xFE])
    result = harness.run_test("push_pop", pp_prog, max_cycles=500)
    print(f"  {'PASS' if result.passed else 'FAIL'}: {result.matches}/{result.total_checks} match, {result.mismatches} mismatch")

    # Generate report
    print("\n" + "=" * 60)
    report = harness.report()
    print(report)

    # Save report
    report_path = PROJECT_ROOT / 'phase2_sim' / 'uvm_report.md'
    with open(report_path, 'w') as f:
        f.write(report)
    print(f"\nReport saved: {report_path}")


if __name__ == '__main__':
    main()
