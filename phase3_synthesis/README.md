# Phase 3 — 综合

## 运行

```bash
# 前提: PDK 已下载, Docker 已安装
bash phase3_synthesis/run_synthesis.sh
```

首次运行需下载 PDK:
```bash
volare enable --pdk sky130 c6d73a35f524070e85faff4a6a9eef49553ebc2b
```

## 结果 (RUN_2026.05.10_11.00.16)

| 指标 | 值 |
|------|-----|
| 标准单元数 | 8,924 cells |
| 芯片面积 | 0.095 mm² (core) / 0.253 mm² (die) |
| 最大频率 | ~48 MHz (20.76ns 关键路径) |
| 目标频率 | 50 MHz (20ns) |
| Setup Slack (slowest) | -0.76 ns |
| DRC violations | 0 |
| LVS | passed |

## 配置

- 工艺: SkyWater 130nm (sky130A)
- 标准单元库: sky130_fd_sc_hd
- 时钟周期: 20ns
- 利用率: 40%, 目标密度: 50%

## 文件

- `config.tcl` → `../openlane/echo_8051/config.tcl`
- RTL 源文件 → `../openlane/echo_8051/src/`
- 运行结果 → `../openlane/echo_8051/runs/`
