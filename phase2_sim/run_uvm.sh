#!/bin/bash
# echo_8051 UVM Verification — run in WSL
# Usage: bash phase2_sim/run_uvm.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================"
echo "  echo_8051 UVM Verification"
echo "========================================"

# Clean temp files
rm -f _prom_*.v _tb_*.v sim_*.vvp 2>/dev/null || true

# Run UVM framework (5-test regression)
PYTHONPATH="$PROJECT_DIR/model" python3 "$SCRIPT_DIR/uvm_framework.py"

echo ""
echo "Report: phase2_sim/uvm_report.md"
