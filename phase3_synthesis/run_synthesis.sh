#!/bin/bash
# echo_8051 Synthesis with OpenLane + Sky130A
# Prerequisites: PDK downloaded via volare, Docker installed
# Usage: bash phase3_synthesis/run_synthesis.sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "========================================"
echo "  echo_8051 Synthesis (OpenLane + Sky130A)"
echo "========================================"

PDK_VERSION="c6d73a35f524070e85faff4a6a9eef49553ebc2b"
PDK_ROOT="$HOME/.volare/volare/sky130/versions/$PDK_VERSION"

# Check PDK
if [ ! -d "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd" ]; then
    echo "PDK not found. Downloading..."
    volare enable --pdk sky130 "$PDK_VERSION"
fi

echo "PDK: $PDK_ROOT"
echo "Running OpenLane flow..."

docker run --rm \
    -v "$PROJECT_DIR":/work \
    -v "$HOME/.volare":/root/.volare \
    -e PDK_ROOT="$PDK_ROOT" \
    -e OPENLANE_SKIP_VOLARE=1 \
    -w /work/openlane/echo_8051 \
    efabless/openlane:latest \
    flow.tcl 2>&1 | tail -30

echo ""
echo "Results: openlane/echo_8051/runs/"
ls -td openlane/echo_8051/runs/RUN_* 2>/dev/null | head -1
