#!/bin/bash
# echo_8051 cross-validation: RTL vs Python ISS
# Usage: bash run_crossval.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  echo_8051 Cross-Validation"
echo "  RTL (iverilog) vs Python ISS"
echo "========================================"
echo ""

# 1. Compile RTL
echo "[1/4] Compiling RTL with iverilog..."
iverilog -Wall -o sim_crossval \
    rtl/alu.v rtl/psw.v rtl/reg_file.v rtl/iram.v rtl/prom.v \
    rtl/sfr_block.v rtl/timer.v rtl/uart.v rtl/intc.v rtl/io_ports.v \
    rtl/cpu_core.v rtl/echo_8051_top.v tb/tb_crossval.v \
    2>&1 | grep -v "warning:" || true
echo "  Done."

# 2. Run RTL trace
echo "[2/4] Running RTL trace..."
vvp sim_crossval > /dev/null 2>&1
echo "  Done. ($(wc -l < rtl_trace.txt) lines)"

# 3. Run ISS trace
echo "[3/4] Running Python ISS trace..."
PYTHONPATH="$SCRIPT_DIR/model" python3 scripts/crossval_iss.py > iss_trace.txt 2>&1
echo "  Done. ($(wc -l < iss_trace.txt) lines)"

# 4. Compare
echo "[4/4] Comparing traces..."
python3 scripts/crossval_compare.py iss_trace.txt rtl_trace.txt

echo ""
echo "Files:"
echo "  rtl_trace.txt  — RTL state dump"
echo "  iss_trace.txt  — ISS state dump"
echo "  sim_crossval   — RTL simulation binary"
echo ""
