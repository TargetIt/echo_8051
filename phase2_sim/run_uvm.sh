#!/bin/bash
# echo_8051 UVM Verification — cocotb + iverilog
set -e
cd "$(dirname "$0")"

echo "========================================"
echo "  echo_8051 UVM ISA Compliance Test"
echo "========================================"

# Clean
rm -rf __pycache__ sim_build *.vcd *.fst 2>/dev/null || true

# Run cocotb
make SIM=icarus 2>&1 | grep -E "INFO|WARNING|ERROR|Results|PASS|FAIL|Coverage|opcode" || true

echo ""
echo "========================================"
echo "  UVM Test Complete"
echo "========================================"
