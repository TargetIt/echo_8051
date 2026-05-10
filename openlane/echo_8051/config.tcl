# echo_8051 OpenLane Configuration
# 8051 MCU — Sky130A, target 50MHz

set ::env(DESIGN_NAME) echo_8051_top
set ::env(VERILOG_FILES) [glob $::env(DESIGN_DIR)/src/*.v]
set ::env(CLOCK_PORT) clk
set ::env(CLOCK_PERIOD) 20.0
set ::env(CLOCK_NET) clk

# PDK
set ::env(PDK) sky130A
set ::env(PDK_ROOT) /root/.volare/volare/sky130/versions/c6d73a35f524070e85faff4a6a9eef49553ebc2b
set ::env(STD_CELL_LIBRARY) sky130_fd_sc_hd

# Synthesis
set ::env(SYNTH_STRATEGY) "AREA 0"
set ::env(SYNTH_MAX_FANOUT) 20
set ::env(SYNTH_CAP_LOAD) 33.0
set ::env(QUIT_ON_SYNTH_CHECKS) 0
set ::env(QUIT_ON_LINTER_ERRORS) 0
set ::env(QUIT_ON_LINTER_WARNINGS) 0

# Floorplan — conservative for 8051 (8-12K gates + memories)
set ::env(FP_CORE_UTIL) 40
set ::env(FP_ASPECT_RATIO) 1.0
set ::env(FP_PDN_VOFFSET) 10
set ::env(FP_PDN_HOFFSET) 10

# Placement
set ::env(PL_TARGET_DENSITY) 0.50
set ::env(PL_TIME_DRIVEN) 1

# Routing
set ::env(GLB_RT_ADJUSTMENT) 0.15
set ::env(GLB_RT_OVERFLOW_ITERS) 50

# Magic DRC/LVS
set ::env(RUN_MAGIC) 1
set ::env(RUN_MAGIC_DRC) 1
set ::env(MAGIC_DRC_USE_GDS) 1

# Reports
set ::env(QUIT_ON_TIMING_VIOLATIONS) 0
set ::env(QUIT_ON_HOLD_VIOLATIONS) 0

# Power
set ::env(RUN_CVC) 0
