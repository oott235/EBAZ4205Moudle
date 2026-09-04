/* lcd_id_probe.v - 8080-8bit 屏控制器 ID 读取诊断(EBAZ4205, Data1)
 * =====================================================================
 * 流程: LCD 硬件复位 -> 对 0xD3(4B)/0x04(3B)/0xDA(3B)/0xDB(3B) 顺序发读命令,
 *       RD 低电平期间采样 D0..D7(本模块释放总线为高阻)。
 * 判定(板上 LED6 红/绿, 低电平点亮):
 *   - 读到相邻字节 93 41        -> 绿灯常亮  = ILI9341
 *   - 读到相邻字节 94 88        -> 红灯常亮  = ILI9488
 *   - 其它/无响应               -> 红灯快闪(0.2s 周期)  [基本可判屏/控制器坏]
 * 接线沿用 Data1: CS=A20 RS=H16 WR=B19 RD=H17 RES=B20 CTR=C20 D0..D7=13..20
 * =====================================================================
 */
`timescale 1ns/1ps
module lcd_id_probe #(
    parameter CLK_HZ = 100000000
) (
    input  wire clk,
    input  wire rst_n,
    inout  wire [7:0] lcd_db,
    output reg  lcd_cs_n,
    output reg  lcd_rs,
    output reg  lcd_wr_n,
    output reg  lcd_rd_n,
    output reg  lcd_rst_n,
    output reg  lcd_bl,
    output reg  led_red,    /* LED6 红, 低电平点亮 */
    output reg  led_grn     /* LED6 绿, 低电平点亮 */
);

    localparam [31:0] MS_TICKS = (CLK_HZ / 1000);
    localparam [6:0] WSU = 7'd10;    /* 数据建立 100ns */
    localparam [6:0] WTW = 7'd100;   /* WR 低 1us */
    localparam [6:0] WHD = 7'd10;
    localparam [7:0] RDL = 8'd100;   /* RD 低 1us */
    localparam [7:0] RDS = 8'd60;    /* 采样点(600ns 后) */
    localparam [7:0] RDH = 8'd30;

    localparam [3:0] P_RESET = 0, P_CMD0 = 1, P_CMDW = 2, P_RD0 = 3,
                     P_RDWAIT = 4, P_RDHLD = 5, P_NEXTB = 6, P_NEXTCMD = 7,
                     P_END = 8;

    reg [3:0] ph;
    reg [31:0] cnt;
    reg [7:0]  out_dat;          /* 当前写字节 */
    reg        rd_active;        /* 1=读相(释放总线) */
    reg [7:0]  db_in;
    reg [7:0]  cmd;              /* 当前命令 */
    reg [3:0]  nbytes;           /* 期望字节数 */
    reg [3:0]  b_idx;
    reg [3:0]  cmd_idx;
    reg [7:0]  rbuf [0:15];
    reg [4:0]  rbuf_n;
    reg [1:0]  verdict;          /* 0=unknown 1=9341 2=9488 */
    reg [31:0] blinkcnt;
    reg        blink;

    assign lcd_db = rd_active ? 8'bz : out_dat;

    /* 扫描 rbuf 是否含相邻对 a1 a2 */
    function found_pair;
        input [7:0] a1;
        input [7:0] a2;
        integer i;
        begin
            found_pair = 1'b0;
            for (i = 0; i + 1 < rbuf_n && i < 15; i = i + 1)
                if (rbuf[i] == a1 && rbuf[i+1] == a2) found_pair = 1'b1;
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            ph        <= P_RESET;
            cnt       <= 32'd0;
            lcd_cs_n  <= 1'b1;
            lcd_rs    <= 1'b1;
            lcd_wr_n  <= 1'b1;
            lcd_rd_n  <= 1'b1;
            lcd_rst_n <= 1'b0;
            lcd_bl    <= 1'b1;
            rd_active <= 1'b0;
            out_dat   <= 8'h00;
            db_in     <= 8'h00;
            cmd       <= 8'h00;
            nbytes    <= 4'd0;
            b_idx     <= 4'd0;
            cmd_idx   <= 4'd0;
            rbuf_n     <= 5'd0;
            verdict   <= 2'd0;
            blinkcnt  <= 32'd0;
            blink     <= 1'b0;
            led_red   <= 1'b1;
            led_grn   <= 1'b1;
        end else begin
            case (ph)
                /* ---------- 硬件复位: RST 低 20ms -> 高 5ms ---------- */
                P_RESET: begin
                    if (cnt >= (20 * MS_TICKS - 1)) begin
                        cnt <= 32'd0;
                        lcd_rst_n <= 1'b1;
                        ph <= P_END;   /* 占位, 实际下一步是发命令 */
                        /* 进入命令1 */
                        ph <= P_CMD0;
                    end else cnt <= cnt + 1'b1;
                end

                /* ---------- 发命令: 切到命令0xD3, 等待建立后 WR ---------- */
                P_CMD0: begin
                    lcd_cs_n  <= 1'b0;
                    lcd_rs    <= 1'b0;
                    rd_active <= 1'b0;
                    case (cmd_idx)
                        4'd0: begin cmd <= 8'hD3; nbytes <= 4'd4; end
                        4'd1: begin cmd <= 8'h04; nbytes <= 4'd3; end
                        4'd2: begin cmd <= 8'hDA; nbytes <= 4'd3; end
                        4'd3: begin cmd <= 8'hDB; nbytes <= 4'd3; end
                        default: begin cmd <= 8'h00; nbytes <= 4'd0; end
                    endcase
                    if (cmd_idx >= 4'd4) begin
                        ph <= P_END;
                    end else begin
                        out_dat <= cmd;
                        cnt     <= 32'd0;
                        ph      <= P_CMDW;   /* 下面直接执行写命令字节 */
                    end
                end

                /* ---------- 写命令字节: 建立 -> WR低 -> WR高 ---------- */
                P_CMDW: begin
                    if (cnt == WSU) begin
                        lcd_wr_n <= 1'b0;
                    end else if (cnt == (WSU + WTW)) begin
                        lcd_wr_n <= 1'b1;
                    end else if (cnt == (WSU + WTW + WHD)) begin
                        /* 命令写完, 转数据读: RS=1, RD 拉低 */
                        lcd_rs    <= 1'b1;
                        rd_active <= 1'b1;
                        b_idx     <= 4'd0;
                        rbuf_n     <= 5'd0;
                        cnt       <= 32'd0;
                        ph        <= P_RD0;
                    end
                    cnt <= cnt + 1'b1;
                end

                /* ---------- 读一个字节: RD 低 -> 采样 -> RD 高 ---------- */
                P_RD0: begin
                    lcd_rd_n <= 1'b0;
                    cnt <= 32'd0;
                    ph  <= P_RDWAIT;
                end
                P_RDWAIT: begin
                    if (cnt == RDS) begin
                        db_in <= lcd_db;          /* 采样 */
                    end else if (cnt == RDL) begin
                        lcd_rd_n <= 1'b1;
                        cnt <= 32'd0;
                        ph  <= P_RDHLD;
                    end
                    cnt <= cnt + 1'b1;
                end
                P_RDHLD: begin
                    if (cnt >= RDH) begin
                        rbuf[rbuf_n[3:0]] <= db_in;
                        rbuf_n <= rbuf_n + 1'b1;
                        b_idx <= b_idx + 1'b1;
                        cnt   <= 32'd0;
                        if (b_idx + 1 >= nbytes) ph <= P_NEXTCMD;
                        else ph <= P_RD0;
                    end else cnt <= cnt + 1'b1;
                end

                /* ---------- 判定 & 下一命令 ---------- */
                P_NEXTCMD: begin
                    lcd_cs_n <= 1'b1;
                    if (found_pair(8'h93, 8'h41)) begin
                        verdict <= 2'd1;   /* ILI9341 */
                        ph <= P_END;
                    end else if (found_pair(8'h94, 8'h88)) begin
                        verdict <= 2'd2;   /* ILI9488 */
                        ph <= P_END;
                    end else begin
                        cmd_idx <= cmd_idx + 4'd1;
                        ph <= P_CMD0;
                    end
                end

                /* ---------- 结束: LED 报结果 ---------- */
                P_END: begin
                    lcd_cs_n  <= 1'b1;
                    lcd_rs    <= 1'b1;
                    rd_active <= 1'b0;
                    lcd_bl    <= 1'b1;
                    case (verdict)
                        2'd1: begin                 /* ILI9341 -> 绿灯常亮 */
                            led_grn <= 1'b0;
                            led_red <= 1'b1;
                        end
                        2'd2: begin                 /* ILI9488 -> 红灯常亮 */
                            led_grn <= 1'b1;
                            led_red <= 1'b0;
                        end
                        default: begin              /* 未知 -> 红灯快闪 0.2s */
                            blinkcnt <= blinkcnt + 1'b1;
                            if (blinkcnt >= (CLK_HZ / 10)) begin
                                blinkcnt <= 32'd0;
                                blink <= ~blink;
                            end
                            led_red <= ~blink;      /* 低电平点亮: blink=1 灭 */
                            led_grn <= 1'b1;
                        end
                    endcase
                end

                default: ph <= P_END;
            endcase
        end
    end

endmodule
