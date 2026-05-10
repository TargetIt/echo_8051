# echo_8051 建模方案

## 概述

在 RTL 开发之前，先用 Python 和 C++ 建立 8051 指令集仿真器（ISS），作为：
1. 架构验证的黄金参考模型
2. RTL 验证的自动比对基准
3. 固件/软件开发的目标平台

## Python ISS 设计

### 文件结构

```
model/python/
├── __init__.py
├── cpu.py          ← CPU 核（寄存器、PC、执行循环）
├── memory.py       ← 存储器模型（ROM/RAM/SFR）
├── alu.py          ← ALU 运算（ADD/ADDC/SUBB/MUL/DIV/LOGIC/ROTATE）
├── decoder.py      ← 指令译码（操作码 → 操作类型+操作数）
├── peripherals.py  ← 外设模型（Timer/UART/IntC/Ports）
├── isa_test.py     ← ISA 合规测试生成器
└── main.py         ← 入口：加载 hex 文件并执行
```

### 设计要点

- **周期精确**：每个指令的执行周期数与真实 8051 一致
- **SFR 完整**：所有 128B SFR 空间建模
- **中断建模**：周期级中断响应（当前指令完成后响应）
- **外设建模**：Timer 自动计数、UART 收发缓冲

### API 接口

```python
class Echo8051:
    def __init__(self, rom_size=4096):
        """初始化 CPU 状态"""

    def load_hex(self, hex_file: str):
        """加载 Intel HEX 格式程序"""

    def step(self) -> int:
        """执行一条指令，返回消耗的周期数"""

    def run(self, max_cycles: int = -1):
        """运行直到 max_cycles 或遇到断点"""

    def get_state(self) -> dict:
        """返回完整 CPU 状态 {ACC, PSW, PC, SP, RAM, SFR, ...}"""

    def set_irq(self, irq_num: int):
        """触发中断请求"""

    def read_port(self, port: int) -> int:
        """读取 I/O 端口状态"""

    def write_port(self, port: int, value: int):
        """写入 I/O 端口"""
```

## C++ ISS 设计

### 文件结构

```
model/cpp/
├── include/
│   ├── echo_8051.h      ← 主类声明
│   ├── types.h           ← 类型定义（u8, u16, s8, s16）
│   ├── cpu.h             ← CPU 核
│   ├── memory.h          ← 存储器
│   ├── alu.h             ← ALU
│   ├── decoder.h         ← 译码器（switch-based）
│   └── peripherals.h     ← 外设
├── src/
│   ├── echo_8051.cpp
│   ├── cpu.cpp
│   ├── memory.cpp
│   ├── alu.cpp
│   ├── decoder.cpp
│   └── peripherals.cpp
├── test/
│   ├── test_isa.cpp      ← ISA 测试
│   ├── test_alu.cpp      ← ALU 单元测试
│   └── test_perf.cpp     ← 性能基准
└── CMakeLists.txt
```

### 设计要点

- **高性能**：使用 switch-case 译码、内联函数、查表法优化
- **C++17**：使用 `std::array`, `constexpr`, `std::optional`
- **可嵌入**：可被 Verilator 或其他仿真器调用（C API）
- **线程安全**：单实例无锁设计

### C API（供外部调用）

```c
// C linkage for Verilator/UVM integration
extern "C" {
    void*  echo_8051_create();
    void   echo_8051_destroy(void* cpu);
    void   echo_8051_reset(void* cpu);
    int    echo_8051_load_hex(void* cpu, const char* filename);
    int    echo_8051_step(void* cpu);
    void   echo_8051_get_state(void* cpu, uint8_t* state_buf);
    void   echo_8051_set_irq(void* cpu, int irq);
}
```

## 与 RTL 交叉验证

```
  ┌─────────────────┐
  │ 随机指令生成器    │
  └────────┬────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────┐
│ C++ ISS │ │ RTL DUT │
└────┬────┘ └────┬────┘
     │           │
     └─────┬─────┘
           ▼
    ┌────────────┐
    │ Scoreboard │
    │ 逐周期比对  │
    └────────────┘
```

比对项目（每个指令执行后）：
1. ACC 值
2. PSW 全部标志位（CY, AC, OV, P）
3. SP 值
4. 写入 RAM/SFR 的值和地址
5. PC 值
6. 外设状态（Timer 计数值、UART 状态等）
