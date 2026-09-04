# ili9341_core — 2.4"/2.8" ILI9341 TFT (8080-8bit) Text-Grid Core for FPGA / Zynq

Low-coupling, plug-and-play display core for the very common 2.4"/2.8" **ILI9341 240×320**
TFT modules wired in **8080-parallel 8-bit** mode ("2.8/2.4 LCD_MODULE" style: `D0..D7 / CS /
RS(A0) / WR / RD / CTR(BL) / RES`; optional XPT2046 touch is not used here).

Give it a clock and an ASCII write port (like a small RAM) — the core drives the panel by
itself: hardware reset, ILI9341 init table (3 passes), clear, a **30×20 text grid** with
8×16 font, and automatic full-frame redraw whenever you write. Same philosophy as the
sibling `0.96OLED` `oled_core`.

低耦合的 2.4"/2.8" ILI9341(8080-8bit 并口)**文本栅格**显示核心：给时钟 + ASCII 写口即可；
初始化/清屏/8×16 字库/整帧重绘全部内置，与同库 0.96OLED 一致。

> ⚠️ 实机提示: 本项目两套独立驱动(STM32 GPIO 模拟 / 本 FPGA 核心)在**同一块被测屏**上都
> 无法显示干净画面, 且该屏对 `0xD3` 读 ID 无应答 → 判定为**屏/控制器坏**。
> 核心本身经 **xsim 全流程仿真 PASS**(字节流精确、写口重绘验证), Vivado 2022.2 构建通过
> (100 MHz 时序收敛); 实机点亮建议先用 `diag/` 验屏再上真机。

---

## Features / 特性

- ✅ **Low coupling / 低耦合**: no PS / AXI / vendor-IP dependency; works on any FPGA/Zynq
  with a clock (EBAZ4205: PS FCLK_CLK0 100 MHz, no PL oscillator; Quartus fine too).
- ✅ **Tiny text write port / 极简写口**: 1-cycle `wr_en/wr_addr/wr_data` (like a small RAM);
  write anything, anytime — the core redraws the whole frame automatically.
- ✅ **Self-contained / 全自动**: power-on = LCD hardware reset → load default text
  (`rtl/ascii_default.v`) → ILI9341 init ×3 → clear → draw frame → idle (`busy=0`).
- ✅ **Text grid / 布局**: 30 cols × 20 rows (240/8 × 320/16), 8×16 ASCII font (32..126),
  `addr = row*30 + col` (0..599). Default page is editable in `ascii_default.v`.
- ✅ **Deterministic 8080 timing / 确定时序**: writes from clock counters (WR low 1 µs,
  setup/hold ~100 ns) — immune to the compiler/jitter bugs that plagued GPIO bit-bang
  drivers on STM32.
- ✅ **Clone-panel quirks built in**: RGB565 **low byte first** (`PIXEL_LO_FIRST`),
  window+RAMWR with **CS held low**, 3× init passes, `0x3A=0x55`, configurable MADCTL.
- ✅ **Verification**: xsim functional sim PASS — boot frame = 314,085 bytes (init+clear+
  grid), each write triggers exactly one full-frame redraw (+160,200 B), out-of-range
  writes ignored; Vivado 2022.2 build PASS on EBAZ4205. Panel ID probe included (`diag/`).

## Interface / 接口

| Port / 端口 | Dir | Width | Description / 说明 |
|---|---|---|---|
| `clk` | in | 1 | Display clock (`CLK_HZ` must match). EBAZ4205: 100 MHz FCLK |
| `rst_n` | in | 1 | Active-low reset |
| `wr_en` | in | 1 | Text write enable, 1-cycle pulse with `wr_addr`/`wr_data` |
| `wr_addr` | in | 10 | Buffer offset `row*COLS+col` (0..599) |
| `wr_data` | in | 8 | ASCII 32..126 (others render as space) |
| `redraw` | in | 1 | Optional full-redraw pulse (tie 0 to ignore) |
| `lcd_db` | out | 8 | LCD D0..D7 (8080 data bus) |
| `lcd_cs_n` | out | 1 | Chip select, active low |
| `lcd_rs` | out | 1 | RS/A0: 0=command 1=data |
| `lcd_wr_n` | out | 1 | Write strobe, active low (latches on rising edge) |
| `lcd_rd_n` | out | 1 | Read strobe (core never reads; high — or tie 3.3 V) |
| `lcd_rst_n` | out | 1 | Panel hardware reset (core pulses it at power-on) |
| `lcd_bl` | out | 1 | Backlight CTR, 1=on |
| `busy` | out | 1 | High while init/drawing a frame; low when idle |
| `dbg_state` | out | 8 | {main[3:0], bus[3:0]} debug |

Parameters: `CLK_HZ`, `LCD_W/LCD_H` (240/320), `COLS/ROWS` (30/20), `MADCTL` (0x00; red↔blue:
0x08; mirror: +0x80/0x40/0x20), `PIXFMT` (0x55), `PIXEL_LO_FIRST` (1), `FG`/`BG` (white/black),
`AUTO_REDRAW_MS` (0 = static until a write), `RST_LOW_MS/RST_HI_MS`.

## Instantiation / 例化

```verilog
ili9341_core #(.CLK_HZ(100000000)) u_lcd (
    .clk       (clk),
    .rst_n     (rst_n),
    .wr_en     (wr_en),          // pulse when writing a char
    .wr_addr   (wr_addr),        // row*30+col, 0..599
    .wr_data   (wr_data),        // ASCII code
    .redraw    (1'b0),
    .lcd_db    (lcd_db), .lcd_rs(lcd_rs), .lcd_cs_n(lcd_cs_n),
    .lcd_wr_n  (lcd_wr_n), .lcd_rd_n(lcd_rd_n),
    .lcd_rst_n (lcd_rst_n), .lcd_bl(lcd_bl),
    .busy      (), .dbg_state()
);
```

Write a character, e.g. show `'A'` at row 2, col 0 (`addr = 2*30+0 = 60`):

```verilog
// combinational or registered: wr_addr = 10'd60; wr_data = 8'h41; pulse wr_en for 1 cycle
```

## Wiring / 接线 (EBAZ4205 example — Data1 header, 2 mm)

| Signal | Data1 pin | FPGA pin | Signal | Data1 pin | FPGA pin |
|---|---|---|---|---|---|
| D0 | 13 | D20 | CS | 5 | A20 |
| D1 | 14 | D18 | RS/A0 | 6 | H16 |
| D2 | 15 | H18 | WR | 7 | B19 |
| D3 | 16 | D19 | RD | 11 | H17 (high) |
| D4 | 17 | F20 | RES | 8 | B20 |
| D5 | 18 | E19 | CTR | 9 | C20 |
| D6 | 19 | F19 | VCC | 1/2 | 3.3 V |
| D7 | 20 | K17 | GND | 12 | common |

Module side: 8-bit 8080 mode (IM jumpers), 3.3 V logic. Other boards: edit the example XDC.

## Directory / 目录

```
2.82.4_ILI9341/
├── rtl/
│   ├── ili9341_core.v         display core (this is the module)
│   ├── ascii_default.v        power-on default text (30×20 grid, editable)
│   ├── font8x16_rom.v         8×16 ASCII font ROM (0x20..0x7E)
│   └── ili9341_init_seq.v     ILI9341 init command table (3 passes)
├── example/
│   ├── prj_top_example.v          EBAZ4205 demo (PS FCLK via system_wrapper + write demo)
│   ├── prj_top_example_pure.v     generic Vivado top, NO PS/bd — exposes the write port
│   ├── prj_top_example_quartus.v  Intel Quartus top (pure Verilog, + .sdc hint)
│   ├── pins_quartus.sdc           Quartus timing constraint example
│   └── pins_ebaz4205_data1.xdc    EBAZ4205 Data1 pin constraints
├── diag/lcd_id_probe.v         panel sanity: read controller ID → LED result
├── sim/tb_ili9341.v            functional testbench (optional)
├── README.md
└── LICENSE
```

## Quick start / 使用

1. Add **all four** `rtl/*.v` files to your project (core instantiates the other three as
   plain modules; no `` `include `` path needed). Quartus/Vivado both fine.
2. Instantiate per the example above (pick `prj_top_example_pure.v` for a generic Vivado
   project, `prj_top_example_quartus.v` for Quartus, `prj_top_example.v` for EBAZ4205).
3. Constrain the 13 LCD pins (copy an example XDC / .qsf assignments) and add a clock
   constraint (see `pins_quartus.sdc`).
4. On EBAZ4205 remember there is **no PL oscillator**: run `ps7_init` first so FCLK_CLK0
   exists, or feed any other clock.

### Change the default content / 修改默认画面
Edit `rtl/ascii_default.v` (or regenerate) — 30×20 ASCII rows; every non-space cell is drawn.

### Drive text from your logic / 外部改字
Pulse `wr_en` with `wr_addr = row*30+col` and `wr_data = ASCII` — the core redraws the
whole frame automatically (writes made mid-frame are coalesced). Linux/PS users: wrap the
port in a tiny AXI-Lite bridge (like `0.96OLEDDyn/axi_oled.v` in the sibling project).

### New-panel sanity check / 新屏验机(强烈建议)
Run `diag/lcd_id_probe.v` first (same 13 pins; `lcd_db` becomes `inout` for the probe):
- 绿灯常亮 = read `93 41` → standard ILI9341;
- 红灯常亮 = read `94 88` → ILI9488 (needs 18-bpp init, not covered);
- 红灯快闪 = no ID response → panel/controller dead, don't waste time.
A healthy ILI9341 **always** answers `0xD3`.

### If the picture is wrong but the panel answers ID
| Symptom | Fix |
|---|---|
| colours red↔blue swapped | `MADCTL` 0x00 ↔ 0x08 |
| image mirrored/rotated | add `0x80` / `0x40` / `0x20` to `MADCTL` |
| everything garbage even solids | panel dead / interface mode wrong — run the ID probe first |
| white screen (backlight on) | check RD is high (3.3 V) and RES is connected |

## Verified / 验证记录

| Board | How | Result |
|---|---|---|
| — | xsim functional sim: boot frame 314,085 B; write → exactly one full redraw (+160,200 B); OOB write ignored | ✅ PASS |
| EBAZ4205 (Zynq-7010) | Vivado 2022.2 synth/impl, 100 MHz FCLK (demo-page edition) | ✅ 0 errors, DRC clean, WNS ≥ 0 |
| EBAZ4205 + suspect panel | HW display + ID probe | ❌ panel dead (no 0xD3 answer) — core not at fault; re-verify with a known-good module |

## Related / 关联工程 (EBAZ4205)
- `BigLED` — EBAZ4205 demo project (first-generation demo-page core; this Text-Grid core
  supersedes it for library use).
- `0.96OLED` — sibling SSD1306 SPI text core in this library (same write-port style).

## License

MIT — see [LICENSE](LICENSE). Replace the copyright holder with your name before publishing.
