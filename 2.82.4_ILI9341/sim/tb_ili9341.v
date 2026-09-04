/* tb_ili9341.v - ili9341_core (Text-Grid) functional sim
 * CLK_HZ=1MHz 加速; 检查: 首帧完成(busy 0) / 写口后 busy 重绘一次 / 字节数单调增加。
 */
`timescale 1ns/1ps
module tb_ili9341;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg redraw = 1'b0;
    reg wr_en = 1'b0;
    reg [9:0] wr_addr = 10'd0;
    reg [7:0] wr_data = 8'h20;
    wire [7:0] lcd_db;
    wire lcd_rs, lcd_cs_n, lcd_wr_n, lcd_rd_n, lcd_rst_n, lcd_bl;
    wire busy;
    wire [7:0] dbg_state;

    ili9341_core #(
        .CLK_HZ        (1000000),
        .RST_LOW_MS    (1),
        .RST_HI_MS     (1),
        .AUTO_REDRAW_MS(0)
    ) dut (
        .clk(clk), .rst_n(rst_n), .redraw(redraw),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .lcd_db(lcd_db), .lcd_rs(lcd_rs), .lcd_cs_n(lcd_cs_n),
        .lcd_wr_n(lcd_wr_n), .lcd_rd_n(lcd_rd_n),
        .lcd_rst_n(lcd_rst_n), .lcd_bl(lcd_bl),
        .busy(busy), .dbg_state(dbg_state)
    );

    always #5 clk = ~clk;

    integer wrcnt = 0;
    always @(posedge lcd_wr_n) wrcnt = wrcnt + 1;

    integer w1, w2;
    reg saw_dirty_rise = 0;
    integer rises = 0;
    reg busy_prev = 1'b0;
    always @(posedge clk) begin
        if (busy && !busy_prev) rises = rises + 1;
        busy_prev <= busy;
    end

    initial begin
        #50; rst_n = 1'b1;
        wait (busy === 1'b0);                      /* 首帧完成 */
        w1 = wrcnt;
        $display("TB: FRAME1 done t=%0t wrcnt=%0d", $time, wrcnt);

        #2000;
        /* 写一个 'Z' 到 第1行第1列 (addr=0) */
        wr_data <= 8'h5A;
        wr_addr <= 10'd0;
        @(posedge clk); wr_en <= 1'b1;
        @(posedge clk); wr_en <= 1'b0;
        wait (busy === 1'b1);                      /* 开始重绘 */
        wait (busy === 1'b0);                      /* 重绘完成 */
        w2 = wrcnt;
        $display("TB: FRAME2 done t=%0t wrcnt=%0d (delta=%0d)", $time, wrcnt, w2 - w1);

        /* 越界写应被忽略(不触发重绘) */
        wr_addr <= 10'd700;
        @(posedge clk); wr_en <= 1'b1;
        @(posedge clk); wr_en <= 1'b0;
        #5000;
        $display("TB: after OOB write busy=%b", busy);

        if (w1 < 100000)              $display("TB: FAIL frame1 bytes too low (%0d)", w1);
        else if (w2 - w1 < 10000)     $display("TB: FAIL no redraw after write (delta %0d)", w2 - w1);
        else if (busy !== 1'b0)       $display("TB: FAIL busy stuck after OOB write");
        else                          $display("TB: PASS w1=%0d delta=%0d", w1, w2 - w1);
        $finish;
    end

    initial begin
        #2000000000;   /* 2s 兜底超时 */
        $display("TB: TIMEOUT busy=%b wrcnt=%0d mst=%0d ex=%0d", busy, wrcnt, dut.mst, dut.ex);
        $finish;
    end

endmodule
