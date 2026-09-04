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
| [2.82.4_ILI9341](2.82.4_ILI9341/) | ILI9341 2.4"/2.8" TFT **8080-8bit** low-coupling **text-grid** core: 30×20 cells × 8×16 font, `wr_en/addr/data` write port, auto init/clear/full-frame redraw; µs-level deterministic bus timing & clone-panel quirks built in; panel ID probe + sim included. 低耦合 ILI9341 并口文本栅格显示核心(带写口/验屏探针/仿真) | any FPGA/Zynq (Vivado & Quartus) | ✅ xsim PASS + EBAZ4205 build PASS; ⏳ HW display to re-verify with a known-good panel (first test panel found dead via ID probe) |
| *(more to come — ADC, FFT, HDMI …)* | 计划: 后续更新 | | |

## Usage / 用法

Every module folder is used the same way:

```
ModuleName/
├── rtl/        module source (+ generated tables)
├── example/    demo top + pin constraints (per board / per tool)
├── README.md   interface, instantiation, wiring
└── LICENSE
```

1. Copy the `rtl/` files into your Vivado/Quartus project (or add as submodule).
   Most cores instantiate their tables/fonts as plain modules — add all files in `rtl/`;
   put `rtl/` on the include path only if a module uses `` `include ``.
2. Instantiate the module (see its README / top-of-file comment example).
3. Copy the example `.xdc`/`.sdc` and adjust pins/clock to your board.
4. Synthesize & enjoy.

Each module documents which boards it was verified on and any board-specific caveats
(e.g. EBAZ4205 has **no PL oscillator** — feed the module from PS FCLK).

## Conventions / 约定

- Pure, synthesizable Verilog-2001 (no SV-only syntax), no vendor IP unless stated.
- Async-low reset `rst_n`; frequency-dependent timing via a `CLK_HZ` parameter.
- Text/font/generated data kept in separate files (plain module instantiations or
  `` `include``) so the core stays readable.
- Chinese + English comments (模块内注释中英混排; README 双语).

## License / 许可

Each module carries its own MIT license (see `ModuleName/LICENSE`).
Unless a module states otherwise, you may use/copy/modify freely with attribution.

## Changelog / 更新记录

- 2026-09: `2.82.4_ILI9341` upgraded to the **Text-Grid edition**: 30×20 grid + `wr_en/
  wr_addr/wr_data` write port (auto full-frame redraw), default text in `ascii_default.v`,
  Quartus example + `.sdc` added, `sim/` testbench added; xsim PASS (frame/redraw verified).
- 2026-09: `2.82.4_ILI9341` added — ILI9341 8080-8bit display core extracted & cleaned from
  EBAZ4205 work (BigLED); includes a controller-ID probe (`diag/`) for panel sanity checks.
- 2026-09: `0.96OLED` added — extracted & cleaned from EBAZ4205 OLED work
  (fixed-content + Linux/AXI dynamic status both verified on hardware).
