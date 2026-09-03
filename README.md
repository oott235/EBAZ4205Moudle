# FPGA / HDL Module Library (Verilog)

个人 FPGA/Zynq 复用模块库 —— 每个模块**自包含**(rtl + example + README + LICENSE),
拷进工程即可用,不依赖本仓库其它文件。

A personal collection of reusable FPGA/Zynq modules in Verilog. Each module folder is
**self-contained** (`rtl/` + `example/` + `README.md` + `LICENSE`) — copy it into your
project and go; modules never depend on each other or on this repo at runtime.

---

## Modules / 模块列表

| Module | Description / 说明 | Target | Status / 状态 |
|---|---|---|---|
| [0.96OLED](0.96OLED/) | SSD1306 128×64 SPI OLED low-coupling text display core (8 rows × 20 chars, 6×8 font; init/refresh automatic). 低耦合 OLED 文本显示核心 | any FPGA/Zynq with a clock | ✅ HW verified (EBAZ4205: bit / SD boot / Linux-drive) |
| *(more to come — ADC, FFT, HDMI …)* | 计划: 后续更新 | | |

## Usage / 用法

Every module folder is used the same way:

```
ModuleName/
├── rtl/        module source (+ generated tables)
├── example/    demo top + pin constraints (per board)
├── README.md   interface, instantiation, wiring
└── LICENSE
```

1. Copy the `rtl/` files into your Vivado/Quartus project (or add as submodule),
   and put `rtl/` on the include path if the module uses `` `include ``.
2. Instantiate the module (see its README / top-of-file comment example).
3. Copy the example `.xdc` and adjust pins to your board.
4. Synthesize & enjoy.

Each module documents which boards it was verified on and any board-specific caveats
(e.g. EBAZ4205 has **no PL oscillator** — feed the module from PS FCLK).

## Conventions / 约定

- Pure, synthesizable Verilog-2001 (no SV-only syntax), no vendor IP unless stated.
- Async-low reset `rst_n`; frequency-dependent timing via a `CLK_HZ` parameter.
- Text/font/generated data kept in separate `` `include`` files so the core stays readable.
- Chinese + English comments (模块内注释中英混排; README 双语).

## License / 许可

Each module carries its own MIT license (see `ModuleName/LICENSE`).
Unless a module states otherwise, you may use/copy/modify freely with attribution.

## Changelog / 更新记录

- 2026-09: `0.96OLED` added — extracted & cleaned from EBAZ4205 OLED work
  (fixed-content + Linux/AXI dynamic status both verified on hardware).
