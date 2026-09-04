/* ili9341_core.v - 2.4"/2.8" ILI9341 TFT (8080-8bit) 文本栅格显示核心  (Text-Grid Edition)
 * =====================================================================================
 * 低耦合即插即用: 给一个时钟 + 一个"像小 RAM 一样"的 ASCII 写口即可驱动屏幕;
 * 初始化/清屏/8x16 字库渲染/整帧重绘全部内置。与同库 0.96OLED 的 oled_core 思路一致,
 * 只是总线的 8080-8bit 并口 + 30x20 文本栅格(240/8 x 320/16)。
 *
 * 上电自动: LCD 硬件复位 -> 从 rtl/ascii_default.v 载入默认文本(30x20)
 *           -> ILI9341 初始化表 x3(与 STM32 参考驱动逐条一致) -> 清屏黑
 *           -> 绘制整帧文本(busy 变低) -> 此后任何 wr 写口/redraw 都会自动重绘整帧。
 *
 * 总线要点(克隆屏实测经验): 像素 RGB565 低字节先发(PIXEL_LO_FIRST);
 * 窗口(0x2A/0x2B)+RAMWR(0x2C) 期间 CS 全程低电平; WR 低 >=1us/建立保持 ~100ns
 * (确定性时钟计数, 不受软件/编译优化影响)。
 *
 * 接线: 13 根输出引脚(lcd_db[7:0]/cs/rs/wr/rd/rst/bl)物理位置由你的工程 XDC 决定,
 *      本模块与板卡无关(EBAZ4205 例子见 example/, Data1 排针)。
 * =====================================================================================
 */
`timescale 1ns/1ps
module ili9341_core #(
    parameter CLK_HZ          = 100000000,   /* 驱动时钟频率(需与 clk 实际一致) */
    parameter [15:0] LCD_W    = 240,
    parameter [15:0] LCD_H    = 320,
    parameter [7:0]  COLS     = 30,          /* 文本栅格列数 = LCD_W/8 */
    parameter [7:0]  ROWS     = 20,          /* 文本栅格行数 = LCD_H/16 */
    parameter [7:0]  MADCTL   = 8'h00,       /* 红蓝颠倒改 0x08; 镜像加 0x80/0x40/0x20 */
    parameter [7:0]  PIXFMT   = 8'h55,       /* 16bpp RGB565 */
    parameter        PIXEL_LO_FIRST = 1,     /* 1=像素低字节先发(实测克隆屏要求) */
    parameter [15:0] FG       = 16'hFFFF,    /* 文字前景色 */
    parameter [15:0] BG       = 16'h0000,    /* 背景色 */
    parameter        AUTO_REDRAW_MS = 0,     /* >0: 空闲后每 N ms 整帧重绘(自检) */
    parameter [15:0] RST_LOW_MS = 20,
    parameter [15:0] RST_HI_MS  = 30
) (
    input  wire clk,
    input  wire rst_n,          /* 低有效复位 */
    /* ---- 文本写口(1 拍脉冲, 像小 RAM; 任意时刻可写) ---- */
    input  wire       wr_en,    /* 写使能脉冲 */
    input  wire [9:0] wr_addr,  /* 缓冲偏移 row*COLS+col (0..599) */
    input  wire [7:0] wr_data,  /* ASCII 32..126(其它按空格处理) */
    input  wire       redraw,   /* 高脉冲: 整帧重绘 */
    /* ---- LCD 8080-8bit 引脚 ---- */
    output reg  [7:0] lcd_db,
    output reg  lcd_rs,         /* 0=命令 1=数据 */
    output reg  lcd_cs_n,       /* 片选低有效 */
    output reg  lcd_wr_n,       /* 写低有效(上升沿锁存) */
    output reg  lcd_rd_n,       /* 读(未用, 恒高; 可硬接 3.3V) */
    output reg  lcd_rst_n,      /* LCD 硬件复位, 低有效(上电自动脉冲) */
    output reg  lcd_bl,         /* 背光 1=亮 */
    output reg  busy,           /* 1=初始化/绘帧中 */
    output wire [7:0] dbg_state /* {mst[3:0], ex[3:0]} */
);

    localparam [15:0] C_BLACK = 16'h0000;

    /* 总线时序(100MHz, 10ns/周期): 建立 100ns / WR低 1000ns / 保持 100ns */
    localparam [6:0] WB_SU_CLK  = 7'd10;
    localparam [6:0] WB_TWR_CLK = 7'd100;
    localparam [6:0] WB_HD_CLK  = 7'd10;
    localparam [31:0] MS_TICKS  = (CLK_HZ / 1000);

    /* ======================== 1) 字节写引擎 ============================= */
    reg [7:0]  wb_dat;
    reg        wb_rs;
    reg        wb_go;
    reg        wb_busy;
    reg [6:0]  wb_cnt;
    reg [1:0]  wb_st;
    reg        wb_done;

    always @(posedge clk) begin
        if (!rst_n) begin
            lcd_db   <= 8'h00;
            lcd_rs   <= 1'b1;
            lcd_wr_n <= 1'b1;
            wb_busy  <= 1'b0;
            wb_cnt   <= 7'd0;
            wb_st    <= 2'd0;
            wb_done  <= 1'b0;
        end else begin
            wb_done <= 1'b0;
            case (wb_st)
                2'd0: if (wb_go) begin
                          lcd_db   <= wb_dat;
                          lcd_rs   <= wb_rs;
                          wb_busy  <= 1'b1;
                          wb_cnt   <= 7'd0;
                          wb_st    <= 2'd1;
                      end
                2'd1: if (wb_cnt == WB_SU_CLK) begin
                          lcd_wr_n <= 1'b0;
                          wb_cnt   <= 7'd0;
                          wb_st    <= 2'd2;
                      end else wb_cnt <= wb_cnt + 1'b1;
                2'd2: if (wb_cnt == WB_TWR_CLK) begin
                          lcd_wr_n <= 1'b1;
                          wb_cnt   <= 7'd0;
                          wb_st    <= 2'd3;
                      end else wb_cnt <= wb_cnt + 1'b1;
                2'd3: if (wb_cnt == WB_HD_CLK) begin
                          wb_busy  <= 1'b0;
                          wb_done  <= 1'b1;
                          wb_cnt   <= 7'd0;
                          wb_st    <= 2'd0;
                      end else wb_cnt <= wb_cnt + 1'b1;
            endcase
        end
    end

    /* ======================== 2) 操作执行器 ============================= */
    localparam [3:0] OP_NONE = 0, OP_CMD = 1, OP_DAT = 2, OP_MS = 3,
                     OP_FILL = 4, OP_CELL = 5;

    reg [3:0]  opcode;
    reg        op_go;
    reg        op_run;
    reg [3:0]  ex;
    reg [15:0] rx0, ry0, rx1, ry1;
    reg [15:0] rcolor, rbg;
    reg [3:0]  rzoom;
    reg [7:0]  rch;
    reg [23:0] rms;
    reg [23:0] ftotal;
    reg [31:0] rcnt;
    reg [7:0]  rk;
    reg [7:0]  px_col, px_row;
    reg        pb;
    reg [10:0] faddr_q;
    reg [7:0]  msk_q;
    reg [7:0]  fb_q;
    reg [7:0]  pb0q, pb1q;

    localparam EX_IDLE = 0, EX_CMD_S = 1, EX_CMD_W = 2, EX_DAT_S = 3, EX_DAT_W = 4,
               EX_WIN_S = 5, EX_WIN_W = 6, EX_PIX_S = 7, EX_PIX_W = 8,
               EX_MS_S = 9, EX_MS_W = 10,
               EX_PP_A = 11, EX_PP_B = 12, EX_PP_C = 13, EX_PP_D = 14;

    function win_rs;
        input [7:0] k;
        begin
            win_rs = (k == 0 || k == 5 || k == 10) ? 1'b0 : 1'b1;
        end
    endfunction

    function [7:0] win_val;
        input [7:0]  k;
        input [15:0] x0, y0, x1, y1;
        begin
            case (k)
                8'd0:  win_val = 8'h2A;
                8'd1:  win_val = x0[15:8];
                8'd2:  win_val = x0[7:0];
                8'd3:  win_val = x1[15:8];
                8'd4:  win_val = x1[7:0];
                8'd5:  win_val = 8'h2B;
                8'd6:  win_val = y0[15:8];
                8'd7:  win_val = y0[7:0];
                8'd8:  win_val = y1[15:8];
                8'd9:  win_val = y1[7:0];
                default: win_val = 8'h2C;
            endcase
        end
    endfunction

    /* v/z, z=1..4, v<=63: 移位/乘常数实现(无进位链) */
    function [7:0] div_small;
        input [7:0] v;
        input [3:0] z;
        begin
            case (z)
                4'd1: div_small = v;
                4'd2: div_small = v >> 1;
                4'd4: div_small = v >> 2;
                default: div_small = ((v + 8'd1) * 8'd85) >> 8;
            endcase
        end
    endfunction

    wire [7:0] cell_w = (rzoom == 4'd1) ? 8'd8  : (rzoom == 4'd2) ? 8'd16 :
                        (rzoom == 4'd3) ? 8'd24 : 8'd32;
    wire [7:0] cell_h = (rzoom == 4'd1) ? 8'd16 : (rzoom == 4'd2) ? 8'd32 :
                        (rzoom == 4'd3) ? 8'd48 : 8'd64;

    wire [7:0]  src_row = div_small(px_row, rzoom);
    wire [7:0]  src_col = div_small(px_col, rzoom);
    wire [7:0]  ch_eff  = (rch >= 8'h20 && rch <= 8'h7E) ? rch : 8'h3F;
    wire [10:0] faddr   = ((ch_eff - 8'd32) * 11'd16) + src_row;
    wire [7:0]  fbyte;
    wire        fbit    = fbyte[7 - src_col];
    wire [15:0] pixw    = (opcode == OP_FILL) ? rcolor : (fbit ? rcolor : rbg);
    wire [7:0]  p_b0    = PIXEL_LO_FIRST ? pixw[7:0]  : pixw[15:8];
    wire [7:0]  p_b1    = PIXEL_LO_FIRST ? pixw[15:8] : pixw[7:0];

    font8x16_rom u_font (
        .addr(faddr),
        .data(fbyte)
    );

    wire [7:0] fbyte_async;
    font8x16_rom u_font2 (
        .addr(faddr_q),
        .data(fbyte_async)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            op_run   <= 1'b0;
            op_go    <= 1'b0;
            ex       <= EX_IDLE;
            lcd_cs_n <= 1'b1;
            rcnt     <= 32'd0;
            rk       <= 8'd0;
            px_col   <= 8'd0;
            px_row   <= 8'd0;
            pb       <= 1'b0;
            faddr_q  <= 11'd0;
            msk_q    <= 8'h00;
            fb_q     <= 8'h00;
            pb0q     <= 8'h00;
            pb1q     <= 8'h00;
        end else begin
            wb_go <= 1'b0;
            case (ex)
                EX_IDLE: begin
                    if (op_go && !op_run && opcode != OP_NONE) begin
                        op_run <= 1'b1;
                        rcnt   <= 32'd0;
                        rk     <= 8'd0;
                        px_col <= 8'd0;
                        px_row <= 8'd0;
                        pb     <= 1'b0;
                        case (opcode)
                            OP_CMD:  begin lcd_cs_n <= 1'b0; ex <= EX_CMD_S; end
                            OP_DAT:  begin lcd_cs_n <= 1'b0; ex <= EX_DAT_S; end
                            OP_MS:   begin ex <= EX_MS_S; end
                            default: begin
                                if (opcode == OP_FILL)
                                    ftotal <= (rx1 - rx0 + 1) * (ry1 - ry0 + 1);
                                else
                                    ftotal <= cell_w * cell_h;
                                lcd_cs_n <= 1'b0;
                                ex <= EX_WIN_S;
                            end
                        endcase
                    end
                end
                EX_CMD_S: if (!wb_busy) begin
                              wb_rs  <= 1'b0;
                              wb_dat <= rch;
                              wb_go  <= 1'b1;
                              ex     <= EX_CMD_W;
                          end
                EX_CMD_W: if (wb_done) begin
                              lcd_cs_n <= 1'b1;
                              op_run   <= 1'b0;
                              ex       <= EX_IDLE;
                          end
                EX_DAT_S: if (!wb_busy) begin
                              wb_rs  <= 1'b1;
                              wb_dat <= rch;
                              wb_go  <= 1'b1;
                              ex     <= EX_DAT_W;
                          end
                EX_DAT_W: if (wb_done) begin
                              lcd_cs_n <= 1'b1;
                              op_run   <= 1'b0;
                              ex       <= EX_IDLE;
                          end
                EX_WIN_S: if (!wb_busy) begin
                              wb_rs  <= win_rs(rk);
                              wb_dat <= win_val(rk, rx0, ry0, rx1, ry1);
                              wb_go  <= 1'b1;
                              rk     <= rk + 8'd1;
                              ex     <= EX_WIN_W;
                          end
                EX_WIN_W: if (wb_done) begin
                              if (rk < 8'd11) ex <= EX_WIN_S;
                              else begin
                                  rcnt   <= 32'd0;
                                  px_col <= 8'd0;
                                  px_row <= 8'd0;
                                  ex     <= EX_PIX_S;
                              end
                          end
                EX_PIX_S: begin
                    if (rcnt >= ftotal) begin
                        lcd_cs_n <= 1'b1;
                        op_run   <= 1'b0;
                        ex       <= EX_IDLE;
                    end else begin
                        ex <= EX_PP_A;
                    end
                end
                EX_PP_A: begin
                    faddr_q <= ((ch_eff - 8'd32) * 11'd16) + div_small(px_row, rzoom);
                    msk_q   <= 8'h80 >> div_small(px_col, rzoom);
                    ex      <= EX_PP_B;
                end
                EX_PP_B: begin
                    fb_q <= fbyte_async;
                    ex   <= EX_PP_C;
                end
                EX_PP_C: begin
                    if ((fb_q & msk_q) != 8'h00) begin
                        pb0q <= PIXEL_LO_FIRST ? rcolor[7:0]  : rcolor[15:8];
                        pb1q <= PIXEL_LO_FIRST ? rcolor[15:8] : rcolor[7:0];
                    end else begin
                        pb0q <= PIXEL_LO_FIRST ? rbg[7:0]  : rbg[15:8];
                        pb1q <= PIXEL_LO_FIRST ? rbg[15:8] : rbg[7:0];
                    end
                    ex <= EX_PP_D;
                end
                EX_PP_D: begin
                    pb     <= 1'b0;
                    wb_rs  <= 1'b1;
                    wb_dat <= pb0q;
                    wb_go  <= 1'b1;
                    ex     <= EX_PIX_W;
                end
                EX_PIX_W: if (wb_done) begin
                    if (!pb) begin
                        pb     <= 1'b1;
                        wb_rs  <= 1'b1;
                        wb_dat <= pb1q;
                        wb_go  <= 1'b1;
                    end else begin
                        rcnt <= rcnt + 1'b1;
                        if (px_row >= cell_h - 1) begin
                            px_row <= 8'd0;
                            px_col <= px_col + 1'b1;
                        end else px_row <= px_row + 1'b1;
                        ex <= EX_PIX_S;
                    end
                end
                EX_MS_S: begin
                    if (rcnt >= (rms * MS_TICKS - 1)) begin
                        op_run <= 1'b0;
                        ex     <= EX_IDLE;
                    end else rcnt <= rcnt + 1'b1;
                end
                default: begin
                    op_run <= 1'b0;
                    ex     <= EX_IDLE;
                end
            endcase
        end
    end

    /* ======================== 3) 文本缓冲 ===============================
     * 600 字节(30x20); 单写口: 外部 wr_en 优先, 否则上电由 ascii_default 载入 */
    reg [7:0] ascii_buf [0:599];
    reg       load_en;
    reg [9:0] ld;
    reg       buf_dirty;   /* 有外部写入待重绘 */

    wire [7:0] def_byte;
    ascii_default u_def (
        .addr (ld),
        .data (def_byte)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            load_en   <= 1'b0;
            ld        <= 10'd0;
            buf_dirty <= 1'b0;
        end else begin
            if (wr_en && wr_addr < 10'd600) begin
                ascii_buf[wr_addr] <= wr_data;
                buf_dirty <= 1'b1;
            end else if (load_en) begin
                ascii_buf[ld] <= def_byte;
                if (ld == 10'd599) load_en <= 1'b0;
                else ld <= ld + 10'd1;
            end
        end
    end

    /* ======================== 4) 主状态机 =============================== */
    localparam M_RSTL  = 0, M_RSTH  = 1, M_LOAD1 = 2,
               M_INROW = 3, M_INNXT = 4, M_INIT2 = 5,
               M_CLEAR0 = 6, M_END1 = 7, M_DRAW0 = 8, M_CELLA = 9,
               M_CELLB = 10, M_CELLN = 11, M_WAIT = 12, M_IDLE = 13;

    reg [4:0]  mst;
    reg [4:0]  next_st;
    reg [2:0]  pass;
    reg [7:0]  row;
    reg [7:0]  rr;      /* 文本行 0..19 */
    reg [7:0]  cc;      /* 文本列 0..29 */
    reg [7:0]  ch_q;
    reg [31:0] mcnt;
    reg        op_was_run;
    reg        redraw_q1, redraw_q2, redraw_prev;

    wire [6:0] seq_addr = {1'b0, row[6:0]};
    wire [2:0] seq_kind;
    wire [23:0] seq_val;
    ili9341_init_seq u_seq (
        .addr (seq_addr),
        .kind (seq_kind),
        .val  (seq_val)
    );

    /* 单元格缓冲地址 = r*30+c = (r<<5)-(r<<1)+c */
    wire [9:0] cell_addr = (rr[4:0] << 5) - (rr[4:0] << 1) + cc;
    wire [7:0] cell_ch   = ascii_buf[cell_addr];
    wire [15:0] cell_x   = {8'd0, cc} << 3;      /* c*8 */
    wire [15:0] cell_y   = {8'd0, rr} << 4;      /* r*16 */

    always @(posedge clk) begin
        if (!rst_n) begin
            mst        <= M_RSTL;
            next_st    <= M_RSTL;
            pass       <= 3'd0;
            row        <= 8'd0;
            rr         <= 8'd0;
            cc         <= 8'd0;
            ch_q       <= 8'h20;
            mcnt       <= 32'd0;
            op_was_run <= 1'b0;
            lcd_rst_n  <= 1'b0;
            lcd_bl     <= 1'b0;
            lcd_rd_n   <= 1'b1;
            busy       <= 1'b1;
            redraw_q1  <= 1'b0;
            redraw_q2  <= 1'b0;
            redraw_prev<= 1'b0;
            opcode     <= OP_NONE;
            op_go      <= 1'b0;
        end else begin
            redraw_q1  <= redraw;
            redraw_q2  <= redraw_q1;
            redraw_prev<= redraw_q2;
            op_go      <= 1'b0;      /* go 单拍 */

            case (mst)
                M_RSTL: begin
                    busy <= 1'b1;
                    if (mcnt >= (RST_LOW_MS * MS_TICKS - 1)) begin
                        mcnt <= 32'd0;
                        lcd_rst_n <= 1'b1;
                        mst  <= M_RSTH;
                    end else mcnt <= mcnt + 1'b1;
                end
                M_RSTH: begin
                    busy <= 1'b1;
                    if (mcnt >= (RST_HI_MS * MS_TICKS - 1)) begin
                        mcnt   <= 32'd0;
                        load_en <= 1'b1;
                        ld     <= 10'd0;
                        mst    <= M_LOAD1;
                    end else mcnt <= mcnt + 1'b1;
                end
                /* 载入默认文本(600 拍)后进入初始化表 */
                M_LOAD1: begin
                    busy <= 1'b1;
                    if (!load_en) begin
                        pass <= 3'd0;
                        row  <= 8'd0;
                        mst  <= M_INROW;
                    end
                end
                M_INROW: begin
                    busy <= 1'b1;
                    case (seq_kind)
                        3'd0: begin
                            opcode <= OP_CMD;
                            rch    <= seq_val[7:0];
                            next_st<= M_INNXT;
                            op_go  <= 1'b1;
                            mst    <= M_WAIT;
                        end
                        3'd1, 3'd3, 3'd4: begin
                            opcode <= OP_DAT;
                            if (seq_kind == 3'd3) rch <= MADCTL;
                            else if (seq_kind == 3'd4) rch <= PIXFMT;
                            else rch <= seq_val[7:0];
                            next_st<= M_INNXT;
                            op_go  <= 1'b1;
                            mst    <= M_WAIT;
                        end
                        3'd2: begin
                            opcode <= OP_MS;
                            rms    <= seq_val;
                            next_st<= M_INNXT;
                            op_go  <= 1'b1;
                            mst    <= M_WAIT;
                        end
                        default: begin              /* kind 7 = END */
                            if (pass >= 3'd2) mst <= M_CLEAR0;
                            else begin
                                pass <= pass + 1'b1;
                                row  <= 8'd0;
                                mcnt <= 32'd0;
                                mst  <= M_INIT2;
                            end
                        end
                    endcase
                end
                M_INNXT: begin
                    row <= row + 8'd1;
                    mst <= M_INROW;
                end
                M_INIT2: begin
                    busy <= 1'b1;
                    if (mcnt >= (250 * MS_TICKS - 1)) begin
                        mcnt <= 32'd0;
                        mst  <= M_INROW;
                    end else mcnt <= mcnt + 1'b1;
                end
                /* 清屏黑 */
                M_CLEAR0: begin
                    busy   <= 1'b1;
                    opcode <= OP_FILL;
                    rx0    <= 16'd0; ry0 <= 16'd0;
                    rx1    <= LCD_W - 1; ry1 <= LCD_H - 1;
                    rcolor <= C_BLACK;
                    next_st<= M_END1;
                    op_go  <= 1'b1;
                    mst    <= M_WAIT;
                end
                M_END1: begin
                    lcd_bl <= 1'b1;
                    mst    <= M_DRAW0;
                end
                /* 整帧: 逐格画 30x20(空格也发, 简化状态机; 背景=黑无痕) */
                M_DRAW0: begin
                    busy      <= 1'b1;
                    buf_dirty <= 1'b0;
                    rr   <= 8'd0;
                    cc   <= 8'd0;
                    mst  <= M_CELLA;
                end
                M_CELLA: begin
                    busy <= 1'b1;
                    ch_q <= cell_ch;        /* 缓冲异步读 -> 寄存器(时序安全) */
                    mst  <= M_CELLB;
                end
                M_CELLB: begin
                    busy    <= 1'b1;
                    opcode  <= OP_CELL;
                    rzoom   <= 4'd1;
                    rcolor  <= FG;
                    rbg     <= BG;
                    rch     <= ch_q;
                    rx0     <= cell_x;
                    ry0     <= cell_y;
                    rx1     <= cell_x + 8'd7;
                    ry1     <= cell_y + 8'd15;
                    next_st <= M_CELLN;
                    op_go   <= 1'b1;
                    mst     <= M_WAIT;
                end
                M_CELLN: begin
                    busy <= 1'b1;
                    if (cc >= (COLS - 1)) begin
                        cc <= 8'd0;
                        if (rr >= (ROWS - 1)) mst <= M_IDLE;
                        else begin rr <= rr + 8'd1; mst <= M_CELLA; end
                    end else begin
                        cc <= cc + 8'd1;
                        mst <= M_CELLA;
                    end
                end
                /* 通用等待 */
                M_WAIT: begin
                    busy <= 1'b1;
                    if (!op_was_run) begin
                        if (op_run) op_was_run <= 1'b1;
                    end else if (!op_run) begin
                        op_was_run <= 1'b0;
                        mst        <= next_st;
                    end
                end
                /* 空闲: 等写口 / redraw / 定时重绘 */
                M_IDLE: begin
                    busy <= 1'b0;
                    if (buf_dirty) begin
                        busy <= 1'b1;
                        mst  <= M_DRAW0;
                    end else if (redraw_q2 && !redraw_prev) begin
                        busy <= 1'b1;
                        mst  <= M_DRAW0;
                    end else if (AUTO_REDRAW_MS > 0) begin
                        if (mcnt >= (AUTO_REDRAW_MS * MS_TICKS - 1)) begin
                            mcnt <= 32'd0;
                            busy <= 1'b1;
                            mst  <= M_DRAW0;
                        end else mcnt <= mcnt + 1'b1;
                    end
                end
                default: mst <= M_IDLE;
            endcase
        end
    end

    assign dbg_state = {mst[3:0], ex};

endmodule
