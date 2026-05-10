# echo_8051

兼容 Intel MCS-51 (8051) 指令集的 8 位微控制器芯片 — 从建模到 GDSII 的完整开源实现。

## 状态

- ✅ Phase 0: 需求/调研/设计 (100%)
- ✅ 建模: Python ISS + C++ ISS (100%)
- ✅ Phase 1: RTL 实现 (~165/256 操作码, 覆盖全部真实 8051 指令, 13 项链式回归全通过)
- ⬜ Phase 2: UVM 验证 (0%)
- ⬜ Phase 3: 综合 (0%)
- ⬜ Phase 4-6: PnR/验证/GDS (0%)

## 已验证指令 (21 条)

`MOV A,#imm` `MOV direct,A` `MOV Rn,#imm` `MOV A,Rn`
`MOV @R0,A` `MOV A,@R0` `MOV direct,#imm` `ADD A,#imm`
`SUBB A,#imm` `ANL A,#imm` `ORL A,#imm` `XRL A,#imm`
`INC A` `DEC A` `CLR A` `MUL AB` `PUSH ACC` `POP ACC`
`CLR C` `DJNZ Rn,rel` `SJMP $`

## 项目结构

```
echo_8051/
├── phase0_spec/          ← 设计方案与架构文档
├── phase1_rtl/           ← Verilog RTL 实现
├── phase2_sim/           ← 仿真与 UVM 验证
├── phase3_synthesis/     ← 逻辑综合（OpenLane + Yosys）
├── phase4_pnr/           ← 布局布线（OpenLane + OpenROAD）
├── phase5_verification/  ← 物理验证（DRC/LVS）
├── phase6_gds/           ← GDSII 输出与签核
├── model/                ← 行为级建模
│   ├── python/           ← Python ISS（指令集仿真器）
│   └── cpp/              ← C++ 高性能 ISS
├── rtl/                  ← RTL 源码（开发用）
├── tb/                   ← Testbench
├── scripts/              ← 自动化脚本
├── doc/                  ← 文档
├── requirements/         ← 需求文档与调研报告
└── delivery/             ← 最终交付件
```

## 阶段规划

| Phase | 名称 | 内容 | 交付件 |
|-------|------|------|--------|
| 0 | Spec | 架构设计, 模块分解, 验证方案 | design_spec.md |
| 1 | RTL | Verilog 实现全部模块 | *.v 源码 |
| 2 | Sim | 模块级 + 系统级 + UVM 验证 | 验证报告, 覆盖率 |
| 3 | Synthesis | Yosys 综合, STA | 门级网表 + SDF |
| 4 | PnR | OpenROAD 布局布线 | DEF + 版图截图 |
| 5 | Verify | DRC/LVS/ANT 检查 | 签核报告 |
| 6 | GDS | GDSII 输出 | GDS + LEF + LIB + SPICE |

## 参考项目

- [OC8051 (OpenCores)](https://opencores.org/project/8051) — 最成熟的 Verilog 8051
- [R8051 (risclite)](https://github.com/risclite/R8051) — 700 行精简实现
- [GOWIN OC8051](https://github.com/GOWIN-FPGA/OC8051_V1.0) — 2024 年工业级移植
- [PulseRain FP51-1T](https://github.com/PulseRain) — 最高性能 1T 架构

## 工具链

| 工具 | 用途 |
|------|------|
| Icarus Verilog / Verilator | RTL 仿真 |
| Yosys | 逻辑综合 |
| OpenROAD | 布局布线 |
| Magic / KLayout | 物理验证 |
| SDCC | C 编译器（8051） |
