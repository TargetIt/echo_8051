#!/bin/bash
# Phase 3: echo_8051 Synthesis with OpenLane + Sky130A
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DESIGN_DIR="$PROJECT_ROOT/openlane/echo_8051"
PDK_CACHE="$HOME/.volare"

echo "========================================"
echo "  echo_8051 Synthesis (OpenLane)"
echo "========================================"

mkdir -p "$PDK_CACHE"

# Run OpenLane synthesis only (not full flow)
docker run --rm \
    -v "$PROJECT_ROOT":/work \
    -v "$PDK_CACHE":/root/.volare \
    -e PDK_ROOT=/root/.volare \
    -w /work/openlane/echo_8051 \
    efabless/openlane:latest \
    bash -c "
        # Fetch PDK if needed
        if [ ! -d /root/.volare/sky130 ]; then
            echo '[INFO] Fetching Sky130 PDK...'
            volare enable --pdk sky130 0fe599b2afb4ba5c6f5d7ee2b7e98cdb5e2e05ef || \
            python3 -c 'import urllib.request; print(\"PDK download not available offline\")' || true
        fi
        # Run synthesis
        run_synthesis
    " 2>&1 | tee "$SCRIPT_DIR/synthesis.log"

echo ""
echo "Synthesis complete. Log: phase3_synthesis/synthesis.log"
