/* prj_top_example_pure.v - oled_core 纯 RTL 例化示范(无 PS/system_wrapper 依赖)
 * =====================================================================
 * 用途: 在"任何有 PL 时钟"的板/工程里演示 oled_core —— 顶层只有 clk/rst_n,
 *       不引用 Xilinx PS / block design, 综合即可用。
 *
 * 注意(EBAZ4205 用户): 该板无 PL 晶振, 纯 PL 无时钟 —— 在 EBAZ4205 上请把
 *   clk 接到 PS FCLK_CLK0(需 ps7_init/FSBL), 或直接使用
 *   example/prj_top_example.v (带 system_wrapper 的 EBAZ4205 专用版)。
 *
 * 演示: 每 0.5s 往"行0列0"写入下一个字母 A..Z (循环), 屏幕可见字符滚动;
 *       替换 wr_pulse/wr_addr/wr_data 的产生逻辑即为你的应用。
 * =====================================================================
 */
module prj_top_example_pure #(
    parameter CLK_HZ = 100000000      /* 你的时钟频率(决定演示节拍与 RES 时序) */
) (
    input  wire clk,          /* 任意频率时钟 (必须 == CLK_HZ) */
    input  wire rst_n,        /* 低有效复位; 若无复位源, 用注释里的内部上电复位替代 */

    /* OLED 4线SPI 输出 -> 你的 xdc */
    output wire sclk,
    output wire mosi,
    output wire dc,
    output wire cs,
    output wire res,

    /* 演示心跳(可选, 不需要可删这两口及下方逻辑) */
    output wire led_red,
    output wire led_grn
);

    /* ---- 若你的系统没有外部复位, 用下面两行做内部上电复位并把它当 rst_n 用 ----
    reg r1, r2;
    always @(posedge clk) begin r1 <= 1'b1; r2 <= r1; end
    wire rst_n = r2;                       // 上电后自动拉高
    ------------------------------------------------------------------- */

    /* ---- 演示写口: 每 0.5s 写下一个字母到 行0列0 (addr=0) ---- */
    reg [31:0] tick;
    reg        wr_pulse;
    reg [7:0]  wr_char;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 32'd0; wr_pulse <= 1'b0; wr_char <= 8'h41;   /* 'A' */
        end else begin
            wr_pulse <= 1'b0;                                    /* 默认无写 */
            if (tick == (CLK_HZ/2) - 1) begin                    /* 0.5s */
                tick <= 32'd0;
                wr_pulse <= 1'b1;
                if (wr_char == 8'h5A) wr_char <= 8'h41;          /* A..Z 循环 */
                else wr_char <= wr_char + 8'd1;
            end else tick <= tick + 32'd1;
        end
    end

    /* ---- OLED 核心 (rtl/oled_core.v, 见其注释) ---- */
    oled_core #(.CLK_HZ(CLK_HZ)) u_oled (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_pulse),
        .wr_addr(8'd0),        /* 行0列0 */
        .wr_data(wr_char),
        .rd_addr(8'h0),
        .rd_data(),
        .sclk(sclk), .mosi(mosi), .dc(dc), .cs(cs), .res(res),
        .busy(), .dbg_sstate()
    );

    /* ---- 演示心跳 1Hz (可选) ---- */
    reg [31:0] cnt;
    reg        blinker;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin cnt <= 32'd0; blinker <= 1'b0; end
        else if (cnt == (CLK_HZ/2) - 1) begin cnt <= 32'd0; blinker <= ~blinker; end
        else cnt <= cnt + 32'd1;
    end
    assign led_red =  blinker;
    assign led_grn = ~blinker;

endmodule
