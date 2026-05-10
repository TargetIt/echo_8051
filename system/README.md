# echo_8051 流水灯系统

基于 Python 8051 ISS 的流水灯演示，通过 Flask Web 服务器驱动，浏览器实时显示 8 个 LED 状态。

## 快速启动

```bash
cd system
pip install flask
python server.py
```

打开浏览器访问 **http://127.0.0.1:5000**

## 页面功能

| 功能 | 说明 |
|------|------|
| 8 个 LED | 由 P1 端口驱动，RL A 循环左移 |
| 速度滑块 | 调节延时循环计数器 (R0) |
| 启动/暂停/单步 | 控制 8051 执行 |
| 按钮 (P3.0) | 模拟按键输入 |
| 状态显示 | PC、ACC、P1 实时数值 |

## 8051 程序

```
MOV  P1, #0x00     ; 关所有 LED
MOV  A,  #0x01     ; 初始点亮 bit0
main:
MOV  P1, A         ; 输出到 LED
MOV  R0, #5        ; 外层延时
MOV  R1, #16       ; 内层延时
delay:
NOP
DJNZ R1, delay     ; 内循环
DJNZ R0, delay     ; 外循环
RL   A             ; 左移一位
SJMP main          ; 循环
```

## API

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/state` | GET | 返回 P1/P3/ACC/PSW/PC/running |
| `/api/reset` | POST | 重新初始化并启动 |
| `/api/step` | POST | 单步执行 |
| `/api/speed` | POST | 设置速度 `{"speed": 1-255}` |
| `/api/button`| POST | 按钮 `{"pressed": true/false}` |
