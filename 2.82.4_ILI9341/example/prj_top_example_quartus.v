/* prj_top_example_quartus.v - ili9341_core (Text-Grid) for Intel Quartus
 * =====================================================================
 * Quartus 用法:
 *   1. 新建工程选好器件(如 Cyclone/MAX10/Arria); 把 rtléçå¨é¨ .v æä»¶ 全部加入工程。
 *   2. 本文件设为顶层(或用你自己的顶层例化 ili9341_core)。
 *   3. 引脚约束: Quartus 里 Assignments -> Pin Planner, 或写 .qsf set_location_assignment。
 *   4. 时序约束(可选但推荐) example/pins_quartus.sdc:
 *        create_clock -name sys_clk -period 10.000 [get_ports clk]
 *   5. 综合/布局布线/Programmer 下载。没有板载晶振的板子请给 clk 供外部时钟。
 * 说明: 核心是纯 Verilog-2001, 无任何厂商原语, Quartus/Vivado 通用。
 * =====================================================================
 */
module prj_top_example_quartus (
    input  wire clk,            /* e.g. 100 MHz from a PLL pin */
    input  wire rst_n,
    input  wire       wr_en,
    input  wire [9:0] wr_addr,  /* row*30+col, 0..599 */
    input  wire [7:0] wr_data,
    input  wire       redraw,
    output wire [7:0] lcd_db,
    output wire lcd_cs_n,
    output wire lcd_rs,
    output wire lcd_wr_n,
    output wire lcd_rd_n,
    output wire lcd_rst_n,
    output wire lcd_bl,
    output wire busy
);

    localparam CLK_HZ = 100000000;   /* set to your clk frequency */

    ili9341_core #(
        .CLK_HZ         (CLK_HZ),
        .MADCTL         (8'h00),
        .PIXFMT         (8'h55),
        .PIXEL_LO_FIRST (1),
        .AUTO_REDRAW_MS (0)
    ) u_lcd (
        .clk       (clk),
        .rst_n     (rst_n),
        .wr_en     (wr_en),
        .wr_addr   (wr_addr),
        .wr_data   (wr_data),
        .redraw    (redraw),
        .lcd_db    (lcd_db),
        .lcd_rs    (lcd_rs),
        .lcd_cs_n  (lcd_cs_n),
        .lcd_wr_n  (lcd_wr_n),
        .lcd_rd_n  (lcd_rd_n),
        .lcd_rst_n (lcd_rst_n),
        .lcd_bl    (lcd_bl),
        .busy      (busy),
        .dbg_state ()
    );

endmodule
