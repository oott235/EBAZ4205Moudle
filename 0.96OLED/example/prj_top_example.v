/* prj_top_example.v - oled_core 例化示范 (EBAZ4205) 2026-09
 * =====================================================================
 * 演示: 给 clk + rst_n 即可跑; 内部每 0.5s 往"行0列0"写下一个字母 (A..Z),
 *       说明用户逻辑如何用 wr 口喂内容 (替换成你的逻辑即可)。
 * 时钟: EBAZ4205 无 PL 晶振, 例化 PS7 system_wrapper 取 FCLK_CLK0(100MHz);
 *       其它平台把 clk 接到你的时钟源即可(模块只认一个 clk 输入)。
 * 引脚: OLED 5 根输出 + 可选呼吸灯/心跳(见 pins_ebaz4205_data3.xdc)
 * =====================================================================
 */
module prj_top_example (
    output wire sclk,      /* -> R18 (Data3-13) */
    output wire mosi,      /* -> R19 (Data3-14) */
    output wire dc,        /* -> P19 (Data3-15) */
    output wire cs,        /* -> T20 (Data3-16) */
    output wire res,       /* -> U20 (Data3-17) */
    output wire led_red,   /* LED6 红 W14 */
    output wire led_grn    /* LED6 绿 W13 */
);

    wire fclk0;

    /* EBAZ4205: PS7 FCLK_CLK0 (工程内已有 system.bd 的工程才可直接用;
     * 纯 PL 工程请自备时钟源并替换此块) */
    system_wrapper u_sys (
        .FCLK_CLK0(fclk0)
    );

    /* 上电复位(2拍) */
    reg r1, r2;
    always @(posedge fclk0) begin
        r1 <= 1'b1; r2 <= r1;
    end
    wire rst_n = r2;

    /* ---- 演示写口: 每 0.5s 写下一个字母到 行0列0 (addr=0) ---- */
    reg [31:0] tick;
    reg        wr_pulse;
    reg [7:0]  wr_char;
    always @(posedge fclk0 or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 32'd0; wr_pulse <= 1'b0; wr_char <= 8'h41; /* 'A' */
        end else begin
            wr_pulse <= 1'b0;                      /* 默认无写 */
            if (tick == 32'd49_999_999) begin      /* 100MHz * 0.5s */
                tick <= 32'd0;
                wr_pulse <= 1'b1;
                if (wr_char == 8'h5A) wr_char <= 8'h41;   /* A..Z 循环 */
                else wr_char <= wr_char + 8'd1;
            end else tick <= tick + 32'd1;
        end
    end

    /* ---- OLED 核心 ---- */
    oled_core #(.CLK_HZ(100000000)) u_oled (
        .clk(fclk0),
        .rst_n(rst_n),
        .wr_en(wr_pulse),
        .wr_addr(8'd0),          /* 行0列0 */
        .wr_data(wr_char),
        .rd_addr(8'h0),
        .rd_data(),
        .sclk(sclk), .mosi(mosi), .dc(dc), .cs(cs), .res(res),
        .busy(), .dbg_sstate()
    );

    /* LED 心跳 1Hz */
    reg [31:0] cnt;
    reg        blinker;
    always @(posedge fclk0) begin
        if (cnt == 32'd49_999_999) begin cnt <= 32'd0; blinker <= ~blinker; end
        else cnt <= cnt + 32'd1;
    end
    assign led_red =  blinker;
    assign led_grn = ~blinker;

endmodule
