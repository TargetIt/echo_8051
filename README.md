# echo_8051

兼容 Intel MCS-51 (8051) 指令集的 8 位微控制器芯片 — 从建模到 GDSII 的完整开源实现。

## 状态

| Phase | 内容 | 状态 |
|-------|------|:---:|
| 0 | 需求/调研/设计 | ✅ |
| — | Python ISS + C++ ISS 建模 | ✅ |
| 1 | RTL 实现 (~165 opcode, 13 项链式回归) | ✅ |
| 2 | UVM 验证框架 | ✅ |
| 3 | OpenLane 综合 (8,924 cells, 0.095mm², DRC=0) | ✅ |
| 4-6 | PnR / 物理验证 / GDS (OpenLane 全流程通过) | ✅ |

## 一键运行

| 命令 | 功能 | 依赖 |
|------|------|------|
| `bash run_crossval.sh` | RTL vs Python/C++ ISS 交叉验证 | iverilog (WSL) |
| `bash system/run.sh` | 外设演示 (Timer中断 LED + UART + Dashboard) | Flask |
| `bash phase2_sim/run_uvm.sh` | UVM 验证框架 (5-test regression) | iverilog (WSL) |
| `bash phase3_synthesis/run_synthesis.sh` | OpenLane 综合 (RTL→GDS) | Docker + PDK |

## 交叉验证

42/43 匹配 (98%)，RTL 与 Python/C++ ISS 功能一致。详见 `run_crossval.sh`。

## 综合结果

| 指标 | 值 |
|------|-----|
| 工艺 | SkyWater 130nm (sky130A) |
| 标准单元 | 8,924 cells |
| 面积 | 0.095 mm² (core) / 0.253 mm² (die) |
| 频率 | ~48 MHz (时序违例 -0.76ns @ 50MHz) |
| DRC | 0 violations |

## 目录

```
echo_8051/
├── requirements/      ← 需求 + 调研 + 遗留问题
├── phase0_spec/       ← 设计方案 + 验证方案 + 建模方案
├── model/             ← Python ISS + C++ ISS
├── rtl/               ← Verilog RTL (12 modules)
├── phase1_rtl/src/    ← RTL 交付版
├── phase2_sim/        ← UVM 验证框架
├── phase3_synthesis/  ← OpenLane 综合
├── phase4_pnr/        ← 布局布线
├── phase5_verification/← 物理验证
├── phase6_gds/        ← GDS 输出
├── openlane/          ← OpenLane 配置 + src
├── system/            ← Flask Web 演示 (流水灯 + 外设)
├── delivery/          ← 交付件 (版图截图 + 综合报告)
├── scripts/           ← 交叉验证脚本 + 版图渲染
├── tb/                ← testbench
└── run_crossval.sh    ← 一键交叉验证
```
