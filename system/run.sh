#!/bin/bash
# echo_8051 Peripheral Demo — one-click launcher
set -e
cd "$(dirname "$0")"

echo "========================================"
echo "  echo_8051 Peripheral Demo"
echo "  Timer Interrupt LED + UART + Dashboard"
echo "========================================"

# Check Python
if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
    echo "ERROR: Python not found. Install Python 3.8+ first."
    exit 1
fi
PY=$(command -v python3 || command -v python)

# Check Flask
if ! $PY -c "import flask" 2>/dev/null; then
    echo "Installing Flask..."
    $PY -m pip install flask -q
fi

echo ""
echo "Starting server at http://127.0.0.1:5000"
echo "Press Ctrl+C to stop"
echo ""

$PY server.py
