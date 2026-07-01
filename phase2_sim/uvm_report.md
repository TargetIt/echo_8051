# echo_8051 UVM Verification Report

**Date**: 2026-07-01 21:16
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
- **crossval_known**: Command '['vvp', '/Users/jiuri/data/targetIt/echo_8051/sim_6f39a909.vvp']' timed out after 30 seconds
- **random_linear**: Command '['vvp', '/Users/jiuri/data/targetIt/echo_8051/sim_45fc77c5.vvp']' timed out after 30 seconds
- **djnz_loop**: Command '['vvp', '/Users/jiuri/data/targetIt/echo_8051/sim_7767054c.vvp']' timed out after 30 seconds
- **mul_div**: Command '['vvp', '/Users/jiuri/data/targetIt/echo_8051/sim_d53c104a.vvp']' timed out after 30 seconds
- **push_pop**: Command '['vvp', '/Users/jiuri/data/targetIt/echo_8051/sim_8d59b1f1.vvp']' timed out after 30 seconds