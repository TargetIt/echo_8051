# echo_8051 交付件

## 版图截图 (`images/`)

由 KLayout batch mode 自动生成。芯片尺寸：498µm × 509µm = 0.253 mm²。

| 图片 | 说明 | 大小 |
|------|------|------|
| `01_full_chip.png` | 完整芯片版图 (全部层) | 1.2MB |
| `02_li1.png` | Local Interconnect (本地互联) | 365K |
| `03_licon1.png` | LI Contact (金属接触孔) | 365K |
| `04_met1.png` | Metal 1 | 400K |
| `05_via1.png` | Via1 (M1→M2) | 368K |
| `06_met2.png` | Metal 2 | 433K |
| `07_via2.png` | Via2 (M2→M3) | 239K |
| `08_met3.png` | Metal 3 | 296K |
| `09_via3.png` | Via3 (M3→M4) | 225K |
| `10_met4.png` | Metal 4 | 321K |
| `11_via4.png` | Via4 (M4→M5) | 216K |
| `12_met5.png` | Metal 5 (顶层) | 222K |
| `13_met1_to_met3.png` | M1→M3 堆叠视图 | 629K |
| `14_met3_to_met5.png` | M3→M5 堆叠视图 | 402K |
| `15_detail_top.png` | 顶部区域放大 | 50K |
| `16_detail_center.png` | 中心区域放大 | 32K |
| `17_detail_transistor.png` | 晶体管级 (li1+licon1+met1) | 49K |

## 综合/PnR 结果

| 指标 | 值 |
|------|-----|
| 工艺 | SkyWater 130nm (sky130A) |
| 标准单元数 | 8,924 cells |
| 芯片面积 | 0.253 mm² (die) / 0.095 mm² (core) |
| 目标频率 | 50 MHz |
| 最大频率 | ~48 MHz (Slowest corner setup -0.76ns) |
| DRC | 0 violations |
| LVS | passed |
