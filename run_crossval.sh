#!/bin/bash
# echo_8051 cross-validation: RTL vs Python ISS + C++ ISS
# Usage: bash run_crossval.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  echo_8051 Cross-Validation"
echo "  RTL (iverilog) vs Python ISS vs C++ ISS"
echo "========================================"
echo ""

# 1. Compile RTL
echo "[1/6] Compiling RTL with iverilog..."
iverilog -Wall -o sim_crossval \
    rtl/alu.v rtl/psw.v rtl/reg_file.v rtl/iram.v rtl/prom.v \
    rtl/sfr_block.v rtl/timer.v rtl/uart.v rtl/intc.v rtl/io_ports.v \
    rtl/cpu_core.v rtl/echo_8051_top.v tb/tb_crossval.v \
    2>&1 | grep -v "warning:" || true
echo "  Done."

# 2. Run RTL trace
echo "[2/6] Running RTL trace..."
vvp sim_crossval > /dev/null 2>&1
echo "  Done. ($(wc -l < rtl_trace.txt) lines)"

# 3. Run Python ISS trace
echo "[3/6] Running Python ISS trace..."
PYTHONPATH="$SCRIPT_DIR/model" python3 scripts/crossval_iss.py > iss_trace.txt 2>&1
echo "  Done. ($(wc -l < iss_trace.txt) lines)"

# 4. Compare Python ISS vs RTL
echo "[4/6] Python ISS vs RTL:"
python3 scripts/crossval_compare.py iss_trace.txt rtl_trace.txt
echo ""

# 5. Compile & run C++ ISS trace
echo "[5/6] Running C++ ISS trace..."
g++ -std=c++17 -O2 -o cpp_trace \
    -I model/cpp/include \
    scripts/crossval_cpp.cpp \
    model/cpp/src/echo_8051.cpp \
    2>&1
./cpp_trace > cpp_trace.txt 2>&1
echo "  Done. ($(wc -l < cpp_trace.txt) lines)"

# 6. Compare C++ ISS vs RTL
echo "[6/6] C++ ISS vs RTL:"
python3 scripts/crossval_compare.py cpp_trace.txt rtl_trace.txt
echo ""

echo "Files:"
echo "  rtl_trace.txt   — RTL state dump"
echo "  iss_trace.txt   — Python ISS state dump"
echo "  cpp_trace.txt   — C++ ISS state dump"
echo "  sim_crossval    — RTL simulation binary"
echo ""
