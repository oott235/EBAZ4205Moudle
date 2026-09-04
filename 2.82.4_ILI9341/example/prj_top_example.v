/* prj_top_example.v - ili9341_core (Text-Grid) instantiation demo (EBAZ4205)
 * =====================================================================
 * 演示写口用法: 上电自动显示 ascii_default 默认文本; 之后每 0.5s 往
 * 第 2 行第 0 列写下一个字母(A..Z 循环), 每次写入核心自动重绘整帧。
 *
 * 时钟: EBAZ4205 无 PL 晶振 -> 例化 PS7 system_wrapper 取 FCLK_CLK0(100MHz);
 *       其它平台: clk 接你的时钟源即可。
 * 引脚: 屏幕 8080-8bit 13 根输出, Data1 排针 (见 pins_ebaz4205_data1.xdc)。
 * =====================================================================
 */
module prj_top_example (
    output wire [7:0] lcd_db,   /* D0..D7 -> Data1-13..20 (D20 D18 H18 D19 F20 E19 F19 K17) */
    output wire lcd_cs_n,       /* CS   -> A20 (Data1-5),  低有效 */
    output wire lcd_rs,         /* RS/A0-> H16 (Data1-6),  0=命令 1=数据 */
    output wire lcd_wr_n,       /* WR   -> B19 (Data1-7),  低有效 */
    output wire lcd_rd_n,       /* RD   -> H17 (Data1-11), 恒高(可硬接3.3V) */
    output wire lcd_rst_n,      /* RES  -> B20 (Data1-8),  低有效 */
    output wire lcd_bl,         /* CTR  -> C20 (Data1-9),  背光 1=亮 */
    output wire led_red,        /* LED6 红 W14 */
    output wire led_grn         /* LED6 绿 W13 */
);

    wire fclk0;
    system_wrapper u_sys (
        .FCLK_CLK0(fclk0)
    );

    reg r1, r2;
    always @(posedge fclk0) begin
        r1 <= 1'b1; r2 <= r1;
    end
    wire rst_n = r2;

    /* ---- 写口演示: 每 0.5s 写下一个字母到 row1(addr=30..) ---- */
    reg [31:0] tick;
    reg        wr_pulse;
    reg [9:0]  wr_addr;
    reg [7:0]  wr_char;
    always @(posedge fclk0) begin
        if (!rst_n) begin
            tick <= 32'd0; wr_pulse <= 1'b0; wr_addr <= 10'd30; wr_char <= 8'h41;
        end else begin
            wr_pulse <= 1'b0;
            if (tick == 32'd49_999_999) begin
                tick <= 32'd0;
                wr_pulse <= 1'b1;
                wr_addr  <= wr_addr + 10'd1;
                if (wr_addr >= 10'd30 + 10'd25) wr_addr <= 10'd30;   /* 每行只放 25 个字母 */
                if (wr_char == 8'h5A) wr_char <= 8'h41; else wr_char <= wr_char + 8'd1;
            end else tick <= tick + 32'd1;
        end
    end

    /* ---- 屏幕核心(文本栅格 + 写口) ---- */
    ili9341_core #(
        .CLK_HZ         (100000000),
        .MADCTL         (8'h00),   /* 红蓝颠倒改 0x08; 镜像加 0x80/0x40/0x20 */
        .PIXFMT         (8'h55),   /* RGB565 */
        .PIXEL_LO_FIRST (1),       /* 像素低字节先发 */
        .AUTO_REDRAW_MS (0)
    ) u_lcd (
        .clk       (fclk0),
        .rst_n     (rst_n),
        .wr_en     (wr_pulse),
        .wr_addr   (wr_addr),
        .wr_data   (wr_char),
        .redraw    (1'b0),
        .lcd_db    (lcd_db),
        .lcd_rs    (lcd_rs),
        .lcd_cs_n  (lcd_cs_n),
        .lcd_wr_n  (lcd_wr_n),
        .lcd_rd_n  (lcd_rd_n),
        .lcd_rst_n (lcd_rst_n),
        .lcd_bl    (lcd_bl),
        .busy      (),
        .dbg_state ()
    );

    /* LED6 心跳 1Hz */
    reg [31:0] cnt;
    reg        blinker;
    always @(posedge fclk0) begin
        if (cnt == 32'd49_999_999) begin cnt <= 32'd0; blinker <= ~blinker; end
        else cnt <= cnt + 32'd1;
    end
    assign led_red =  blinker;
    assign led_grn = ~blinker;

endmodule
