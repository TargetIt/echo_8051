# echo_8051 Peripheral Demo

基于 Python 8051 ISS 的外设演示系统。Flask 后端驱动真实 8051 指令集仿真器，浏览器三面板实时交互。

## 一键启动

```bash
cd system
pip install flask   # 首次运行
python server.py
```

浏览器打开 **http://127.0.0.1:5000**

## 三面板

| 面板 | 功能 | 实现 |
|------|------|------|
| 💡 **LED** | Timer0 中断驱动流水灯，速度滑块调节 | TH0/TL0 重载值 |
| 📟 **UART** | 发送字节到 8051 SBUF，echo 回显 | SCON polling |
| 📊 **Dashboard** | 实时 SFR 面板：PC/ACC/PSW/SP/DPTR/IE/TCON/TMOD/TH0/TL0/SCON/SBUF | 100ms 轮询 |

## 8051 程序

```
ORG 0x0000
    LJMP MAIN
ORG 0x000B          ; Timer0 中断向量
    LJMP ISR_TIMER0

MAIN:
    MOV  IE,   #0x82   ; EA + ET0
    MOV  TMOD, #0x01   ; T0 mode 1 (16-bit)
    MOV  TH0,  #0xFF   ; 快速溢出 (~256 counts)
    MOV  TL0,  #0x00
    MOV  TCON, #0x10   ; TR0 = 1
    MOV  A,    #0x01
    MOV  P1,   A
    SJMP $              ; 等待中断

ISR_TIMER0:
    MOV  TH0,  #0xFF   ; 重载定时器
    MOV  TL0,  #0x00
    MOV  A,    P1
    RL   A             ; 左移 LED
    MOV  P1,   A
    RETI
```

## API

| 端点 | 方法 | 请求 | 响应 |
|------|------|------|------|
| `/api/state` | GET | — | `{p1,p3,acc,psw,pc,sp,ie,tcon,th0,tl0,scon,sbuf,uart_tx,running}` |
| `/api/reset` | POST | — | `{status:"ok"}` |
| `/api/step` | POST | — | `{p1}` |
| `/api/speed` | POST | `{reload: 256}` | `{reload,th0,tl0}` |
| `/api/uart_send` | POST | `{byte: 0x41}` | `{sent}` |

## 文件

```
system/
├── README.md           ← 本文件
├── server.py           ← Flask 服务器 + 8051 程序
└── templates/
    └── index.html      ← 三面板 HTML 前端
```
