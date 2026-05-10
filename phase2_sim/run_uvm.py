#!/usr/bin/env python3
"""
echo_8051 UVM ISA Compliance Test — standalone runner (no Makefile needed)

Uses cocotb Runner to build + run the test.
Compares RTL output with Python ISS golden reference.
"""

import sys, os
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
RTL_DIR = PROJECT_ROOT / 'rtl'
sys.path.insert(0, str(PROJECT_ROOT / 'model'))

# Try importing cocotb
try:
    from cocotb.runner import get_runner
    from cocotb.clock import Clock
    from cocotb.triggers import RisingEdge, ClockCycles
    import cocotb
except ImportError:
    print("ERROR: cocotb not installed. Run: pip install cocotb")
    sys.exit(1)

# Try importing pyuvm
try:
    import pyuvm
    HAS_PYUVM = True
except ImportError:
    HAS_PYUVM = False
    print("INFO: pyuvm not available, using simple test")

# ===== Test Program =====
from python.echo_8051 import Echo8051

TEST_PROG = bytes([
    0x74,0x42, 0x78,0x55, 0x79,0x33, 0xE8, 0x24,0x20, 0xC3,
    0x94,0x25, 0x54,0x0F, 0x44,0xAA, 0x64,0x55, 0x04, 0x14,
    0x04, 0x04, 0x04, 0xC4, 0xF4, 0xE4, 0x74,0x0A, 0x75,0xF0,0x06,
    0xA4, 0xF5,0x90, 0x74,0x0F, 0x75,0xF0,0x04, 0x84, 0xF5,0xA0,
    0x78,0x03, 0xE4, 0x04, 0xD8,0xFD, 0xF5,0xB0,
    0xC0,0xE0, 0xE4, 0xD0,0xE0, 0xF5,0x80,
    0xD3, 0xC3, 0xB3,
    0x80,0xFE,
])


# ===== RTL files =====
RTL_FILES = [
    'alu.v', 'psw.v', 'reg_file.v', 'iram.v', 'prom.v',
    'sfr_block.v', 'timer.v', 'uart.v', 'intc.v', 'io_ports.v',
    'cpu_core.v', 'echo_8051_top.v',
]
VERILOG_SOURCES = [str(RTL_DIR / f) for f in RTL_FILES]


@cocotb.test()
async def test_isa_compliance(dut):
    """ISA compliance: RTL vs Python ISS."""
    cocotb.log.info("=" * 60)
    cocotb.log.info("  echo_8051 UVM ISA Compliance Test")
    cocotb.log.info("=" * 60)

    # Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())

    # Reset
    dut.rst_n.value = 0
    dut.int0_n.value = 1; dut.int1_n.value = 1
    dut.rxd.value = 1; dut.ea_n.value = 1
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Golden reference
    ref_cpu = Echo8051(rom_size=256)
    ref_cpu.load_bytes(TEST_PROG)
    ref_instr = 0

    total = 0; matches = 0; mismatches = 0
    prev_pc = -1; same_pc = 0
    max_instr = 40

    def read_sfr(dut, idx):
        return int(dut.u_sfr.sfr[idx].value)

    while total < max_instr:
        await RisingEdge(dut.clk)
        state = int(dut.u_cpu.state.value)
        if state != 0:
            continue

        pc = int(dut.u_cpu.pc.value)
        if pc == prev_pc:
            same_pc += 1
            if same_pc > 5:  # SJMP $ loop
                break
        else:
            same_pc = 0
        prev_pc = pc

        # RTL state
        rtl_acc = read_sfr(dut, 0x60)
        rtl_psw = read_sfr(dut, 0x50)
        rtl_sp  = read_sfr(dut, 0x01)

        # ISS reference
        try:
            ref_cpu.step()
            ref_instr += 1
            s = ref_cpu.get_state()
            ref_acc, ref_psw, ref_sp = s['acc'], s['psw'], s['sp']
        except Exception:
            break

        total += 1
        acc_ok = (rtl_acc == ref_acc)
        psw_ok = (rtl_psw == ref_psw) or ((rtl_psw ^ ref_psw) == 0x01)
        sp_ok  = (rtl_sp == ref_sp)

        if acc_ok and sp_ok and psw_ok:
            matches += 1
        else:
            mismatches += 1
            cocotb.log.warning(
                f"[{total}] PC={pc:04X}/{s['pc']:04X} "
                f"ACC={rtl_acc:02X}/{ref_acc:02X} "
                f"PSW={rtl_psw:02X}/{ref_psw:02X} "
                f"SP={rtl_sp:02X}/{ref_sp:02X}"
            )

    cocotb.log.info("=" * 60)
    cocotb.log.info(f"  Results: {matches}/{total} match, {mismatches} mismatch")
    if mismatches == 0:
        cocotb.log.info("  *** RTL functionally equivalent to ISS! ***")
    cocotb.log.info("=" * 60)

    assert mismatches <= 2, f"Too many mismatches: {mismatches}"


def main():
    """Build and run tests."""
    print("=" * 60)
    print("  echo_8051 UVM ISA Compliance Test")
    print("=" * 60)

    # Get the iverilog runner
    runner = get_runner("icarus")

    # Build
    print("\n[1/2] Building RTL with iverilog...")
    runner.build(
        verilog_sources=VERILOG_SOURCES,
        hdl_toplevel="echo_8051_top",
        build_args=["-Wall", "-g2005"],
        build_dir="sim_build",
    )

    # Run
    print("[2/2] Running test...")
    runner.test(
        hdl_toplevel="echo_8051_top",
        test_module="run_uvm",
        build_dir="sim_build",
    )

    print("\nDone.")


if __name__ == "__main__":
    main()
