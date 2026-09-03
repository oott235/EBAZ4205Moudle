# oled_core — 0.96" SSD1306 OLED Display Core for FPGA / Zynq

Low-coupling, plug-and-play text display core for the common 0.96" **SSD1306 128×64 SPI** OLED.
Give it a clock, write ASCII bytes, and it drives the panel by itself — init sequence, 6×8 font
rendering and 0.5 s full-frame refresh are all handled internally.

低耦合的 0.96" SSD1306 文本显示核心：给个时钟、往里写 ASCII 即可，初始化/字库渲染/整帧刷新全部内置。

---

## Features / 特性

- ✅ **Low coupling / 低耦合**: no PS / AXI / vendor-IP / soft-core dependency — works on any
  FPGA/Zynq design that has a clock (EBAZ4205 上由 PS FCLK_CLK0 或任意时钟提供).
- ✅ **Tiny user interface / 极简接口**: synchronous 1-cycle `wr_en/wr_addr/wr_data` ASCII
  write port (like a small RAM) + 5 OLED output pins. Optional async readback for debug.
- ✅ **Self-contained / 全自动**: SSD1306 init commands, 6×8 column-font rendering, page
  addressing and 0.5 s refresh are internal; writes appear within ≤0.5 s.
- ✅ **Layout / 布局**: 8 text rows × 20 chars (row = page), char cell 6×8 px (5×7 glyph +
  spacing), ASCII 32–126; 120 px of the 128 px width used.
- ✅ **Verified on hardware / 实机验证**: EBAZ4205 (Zynq-7010) — JTAG direct bit, SD-card
  self-boot, and live Linux status driven through an AXI3 bridge (see *Related*).

## Interface / 接口

| Port / 端口 | Dir | Width | Description / 说明 |
|---|---|---|---|
| `clk` | in | 1 | Display clock (any frequency, `CLK_HZ` parameter must match). EBAZ4205: PS FCLK_CLK0 100 MHz |
| `rst_n` | in | 1 | Active-low reset |
| `wr_en` | in | 1 | Write enable, 1-cycle pulse with `wr_addr`/`wr_data` |
| `wr_addr` | in | 8 | ASCII buffer offset: `row*20 + col` (0..159 shown; 8-bit) |
| `wr_data` | in | 8 | ASCII code 32..126 (others render blank) |
| `rd_addr` | in | 8 | Read address (optional) |
| `rd_data` | out | 8 | Combinational read of `ascii_buf[rd_addr]` (debug; leave open if unused) |
| `sclk/mosi/dc/cs/res` | out | 1 | SSD1306 4-wire SPI pins — wire these to your header; physical pins live in your XDC |
| `busy` | out | 1 | High while init/data frame is being sent (writes are always allowed) |
| `dbg_sstate` | out | 2 | Internal state (optional scope) |

Module parameters: `CLK_HZ` (default 100000000) — used for RES pulse and refresh timing.

## Instantiation / 例化

```verilog
oled_core #(.CLK_HZ(100000000)) u_oled (
    .clk(clk), .rst_n(rst_n),
    .wr_en(wr_en), .wr_addr(addr), .wr_data(data),      // text write port
    .rd_addr(8'h0), .rd_data(),                         // optional readback
    .sclk(sclk), .mosi(mosi), .dc(dc), .cs(cs), .res(res),
    .busy(), .dbg_sstate()
);
```

Write a character:

```verilog
// show 'A' at row 2, col 0  →  addr = 2*20+0 = 40, data = 8'h41
assign wr_addr = 8'd40;
assign wr_data = 8'h41;        // 'A'
// pulse wr_en high for one clock cycle when you want the screen to update
```

## Wiring / 接线 (EBAZ4205 example — Data3 header, 2 mm)

| Signal | Data3 pin | FPGA pin |
|---|---|---|
| SCLK (D0) | 13 | R18 |
| MOSI (D1) | 14 | R19 |
| DC | 15 | P19 |
| CS | 16 | T20 |
| RES | 17 | U20 |
| VCC | 1/2 (3.3 V) | — |
| GND | 12 | — |

Other boards: change `example/pins_ebaz4205_data3.xdc` `PACKAGE_PIN`s to your schematic —
the core itself is board-agnostic (outputs are just 5 pins).

## Directory / 目录

```
0.96OLED/
├── rtl/
│   ├── oled_core.v         display core (this is the module)
│   ├── font_data.v         6×8 column font table (generated, ASCII 32..126)
│   └── ascii_default.v     power-on default text (8 rows × 20 chars)
├── example/
│   ├── prj_top_example.v         EBAZ4205 demo top (PS FCLK via system_wrapper): blinks A..Z
│   ├── prj_top_example_pure.v    generic demo top, NO PS/bd dependency — any board with a PL clock
│   └── pins_ebaz4205_data3.xdc
├── README.md
└── LICENSE
```

## Quick start / 使用

1. Add `rtl/oled_core.v` (and `font_data.v`, `ascii_default.v`) to your project;
   put `rtl/` on the include path (the core uses `` `include "font_data.v" `` etc.).
2. Instantiate per the example above.
3. Constrain the 5 OLED pins in your XDC (copy the example file and edit pins).
4. On EBAZ4205 remember there is **no PL oscillator**: clock the core from PS `FCLK_CLK0`
   after `ps7_init` (or any PL clock source you add).

> Two examples are provided: `prj_top_example_pure.v` is fully generic (external `clk`/`rst_n`
> only, no Xilinx PS/BD dependency — pick this for other boards); `prj_top_example.v` is the
> EBAZ4205 variant that takes its clock from the PS7 block design.

### Change the default text / 修改开机默认文本
Edit/generate `rtl/ascii_default.v` — one `initial` assignment per shown byte,
offset = `row*20+col`, e.g. `ascii_buf[0]=8'h45; // 'E'`.

### Custom font / 自定义字库
`font_data.v` stores 5 column bytes per ASCII code (`font[col][ascii]`, bit0 = top row).
Regenerate from any raster font with a small script if you need a different style.

## Verified / 实测记录

| Board | How | Result |
|---|---|---|
| EBAZ4205 (Zynq-7010) | JTAG program bit | ✅ default text shown on Data3 header |
| EBAZ4205 | SD-card self boot (FSBL+bit+U-Boot+Linux) | ✅ boots, OLED lit |
| EBAZ4205 | Linux `devmem` → AXI3 bridge → core | ✅ live status (time/load/mem) refreshes every second |

Timing: 100 MHz FCLK, all constraints met (0.96 OLEDDyn/SD projects reference this core).

## Related / 关联工程 (EBAZ4205)

- `0.96OLEDDyn` — Linux/u-boot writable OLED: same core behind an AXI3 thin wrapper
  (`axi_oled.v` translates AXI writes into the text port; address `0x40000000 + row*20+col`).
- `0.96OLEDSD` — fixed-content OLED project: instantiates the same core with no writer.
- Linux demo loop (on the board): `sh /mnt/mmcblk0p1/dyn.sh &` (device path may vary).

## License

MIT — see [LICENSE](LICENSE). Replace the copyright holder with your name before publishing.
