/* prj_top_example_pure.v - ili9341_core (Text-Grid) generic demo top, NO PS/BD dependency
 * =====================================================================
 * 任意带 PL 时钟的 FPGA/Zynq(Vivado 工程)都可用: 输入 clk/rst_n + 文本写口即可。
 * 上电自动显示 ascii_default 默认文本; wr_en/addr/data 随时可写, 写后自动重绘整帧。
 * Quartus 用户另见 prj_top_example_quartus.v(含 .sdc 提示)。
 * =====================================================================
 */
module prj_top_example_pure (
    input  wire clk,            /* your clock (CLK_HZ 参数需匹配) */
    input  wire rst_n,          /* async-low reset */
    input  wire       wr_en,    /* text write enable (1-cycle pulse) */
    input  wire [9:0] wr_addr,  /* row*30+col, 0..599 */
    input  wire [7:0] wr_data,  /* ASCII 32..126 */
    input  wire       redraw,   /* optional full redraw pulse */
    output wire [7:0] lcd_db,
    output wire lcd_cs_n,
    output wire lcd_rs,
    output wire lcd_wr_n,
    output wire lcd_rd_n,
    output wire lcd_rst_n,
    output wire lcd_bl,
    output wire busy,
    output wire [7:0] dbg_state
);

    localparam CLK_HZ = 100000000;   /* change to your actual clock */

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
        .dbg_state (dbg_state)
    );

endmodule
