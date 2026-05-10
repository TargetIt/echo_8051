# Phase 2 — UVM 验证

## 运行

```bash
# 在 WSL 中运行
bash phase2_sim/run_uvm.sh
```

或直接在 WSL 中：
```bash
cd echo_8051
PYTHONPATH=model python3 phase2_sim/uvm_framework.py
```

## 框架组件

| 组件 | 文件 | 说明 |
|------|------|------|
| StimulusGenerator | `uvm_framework.py` | 约束随机 8051 指令序列生成 |
| Driver | `uvm_framework.py` | 加载程序到 PROM，iverilog 编译+仿真 |
| Monitor | `uvm_framework.py` | 解析 RTL trace 输出为 InstrState |
| Scoreboard | `uvm_framework.py` | RTL vs Python ISS 黄金参考比对 |
| CoverageCollector | `uvm_framework.py` | 操作码/功能覆盖率追踪 |
| TestHarness | `uvm_framework.py` | 多测试回归 + Markdown 报告 |

## 测试用例

1. **crossval_known** — 交叉验证已知程序 (MOV/ADD/SUBB/ANL/ORL/XRL/MUL/DIV/PUSH/POP/DJNZ)
2. **random_linear** — 随机线性指令序列
3. **djnz_loop** — DJNZ 循环测试
4. **mul_div** — 乘除法测试
5. **push_pop** — 栈操作测试
