# echo_8051 UVM Verification Report

**Date**: 2026-05-10 20:33
**Tests**: 5 run, 0 passed, 5 failed

## Coverage
- Unique opcodes exercised: **34** / 256
- ALU opcodes: 9
- Branch opcodes: 2

## Test Results

| Test | Status | Checks | Match | Mismatch | Time |
|------|--------|--------|-------|----------|------|
| crossval_known | FAIL | 0 | 0 | 0 | 0ms |
| random_linear | FAIL | 0 | 0 | 0 | 0ms |
| djnz_loop | FAIL | 0 | 0 | 0 | 0ms |
| mul_div | FAIL | 0 | 0 | 0 | 0ms |
| push_pop | FAIL | 0 | 0 | 0 | 0ms |

## Failures
- **crossval_known**: Command '['vvp', '/mnt/d/work/qpwork/github/TargetIt/echo_8051/sim_b61b8231.vvp']' timed out after 30 seconds
- **random_linear**: Command '['vvp', '/mnt/d/work/qpwork/github/TargetIt/echo_8051/sim_644235a1.vvp']' timed out after 30 seconds
- **djnz_loop**: Command '['vvp', '/mnt/d/work/qpwork/github/TargetIt/echo_8051/sim_de40df3d.vvp']' timed out after 30 seconds
- **mul_div**: Command '['vvp', '/mnt/d/work/qpwork/github/TargetIt/echo_8051/sim_c7a921e2.vvp']' timed out after 30 seconds
- **push_pop**: Command '['vvp', '/mnt/d/work/qpwork/github/TargetIt/echo_8051/sim_820cd71d.vvp']' timed out after 30 seconds