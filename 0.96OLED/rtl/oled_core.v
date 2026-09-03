/* oled_core.v - SSD1306 (0.96" 128x64, 4线SPI) 低耦合显示核心 2026-09
 * =====================================================================
 * 目标: 即插即用、与数据来源解耦。给 clk/rst_n + 写 ASCII 即可, 模块
 *       自己完成: SSD1306 初始化 → 文本缓冲 → 6x8 字库渲染 → 整帧刷新。
 *
 * 用户接口 (全部):
 *   clk           显示时钟 (EBAZ4205 用 PS FCLK_CLK0 = 100MHz, 纯 PL 可用任意)
 *   rst_n         复位 (低有效)
 *   wr_en        写使能脉冲(1 拍); wr_addr/wr_data 同拍有效
 *   wr_addr       ASCII 缓冲偏移 0..255 (屏区 0..159 = 行*20+列)
 *   wr_data       ASCII 32..126 (其余码显示为空白)
 *   rd_addr/rd_data 异步回读(调试用, 不用悬空)
 *   sclk/mosi/dc/cs/res  OLED 4线SPI 引脚(物理约束在工程 xdc)
 *
 * 布局: 8 页 = 8 行文字, 行 20 字符 x 6px (5px 字形+1px 间隔), 120px 宽
 * 刷新: 0.5s 整帧重发(写入后最迟 0.5s 可见), 写口随时可写
 * 字位: bit r = 行 r, bit0 = 屏幕最上
 * =====================================================================
 * 依赖: font_data.v(字库) ascii_default.v(上电默认文本) 需在 include 路径
 * 例化:
 *   oled_core #(.CLK_HZ(100000000)) u_oled (
 *       .clk(clk), .rst_n(rst_n),
 *       .wr_en(wr_en), .wr_addr(addr), .wr_data(data),
 *       .rd_addr(8'h0), .rd_data(),
 *       .sclk(sclk), .mosi(mosi), .dc(dc), .cs(cs), .res(res),
 *       .busy(), .dbg_sstate());
 * =====================================================================
 */
module oled_core #(
    parameter CLK_HZ = 100000000
) (
    input  wire clk,
    input  wire rst_n,

    /* ---- 文本写口 ---- */
    input  wire       wr_en,
    input  wire [7:0] wr_addr,
    input  wire [7:0] wr_data,

    /* ---- 异步回读(可选) ---- */
    input  wire [7:0] rd_addr,
    output wire [7:0] rd_data,

    /* ---- SSD1306 4线SPI 引脚 ---- */
    output wire sclk,
    output wire mosi,
    output wire dc,
    output wire cs,
    output wire res,

    /* ---- 状态 ---- */
    output wire        busy,
    output wire [1:0]  dbg_sstate
);

    /* ================= 内容存储 ================= */
    `include "ascii_default.v"      /* reg [7:0] ascii_buf [0:255]; initial 默认文本 */
    `include "font_data.v"          /* reg [7:0] font [0:4][0:255]; font[col][ascii] */

    /* 写口: 单写者 (与 initial 默认文本并存, 综合为带初值的 LUTRAM) */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        end else begin
            if (wr_en) ascii_buf[wr_addr] <= wr_data;
        end
    end
    assign rd_data = ascii_buf[rd_addr];

    /* ================= SPI 驱动状态机 ================= */
    reg [7:0] cmd_rom [0:31];
    initial begin
        cmd_rom[0]=8'hAE;
        cmd_rom[1]=8'hD5; cmd_rom[2]=8'h80;
        cmd_rom[3]=8'hA8; cmd_rom[4]=8'h3F;
        cmd_rom[5]=8'hD3; cmd_rom[6]=8'h00;
        cmd_rom[7]=8'h40;
        cmd_rom[8]=8'h8D; cmd_rom[9]=8'h14;
        cmd_rom[10]=8'h20; cmd_rom[11]=8'h00;
        cmd_rom[12]=8'hA1;
        cmd_rom[13]=8'hC8;
        cmd_rom[14]=8'hDA; cmd_rom[15]=8'h12;
        cmd_rom[16]=8'h81; cmd_rom[17]=8'hCF;
        cmd_rom[18]=8'hD9; cmd_rom[19]=8'hF1;
        cmd_rom[20]=8'hDB; cmd_rom[21]=8'h40;
        cmd_rom[22]=8'hA4;
        cmd_rom[23]=8'hA6;
        cmd_rom[24]=8'hAF;
        cmd_rom[25]=8'h21; cmd_rom[26]=8'h00; cmd_rom[27]=8'h7F;
        cmd_rom[28]=8'h22; cmd_rom[29]=8'h00; cmd_rom[30]=8'h07;
        cmd_rom[31]=8'hFF;              /* 哨兵 */
    end

    localparam [1:0] ST_RES = 0, ST_CMD = 1, ST_PAGE = 2, ST_GAP = 3;
    localparam [3:0] HALF = 4'd8;       /* SCK 半周期 = 8 clk */

    reg [1:0]  st;
    reg [31:0] tcnt;
    reg [5:0]  ci;
    reg [2:0]  pg;          /* 页/行 0..7 */
    reg [7:0]  bx;          /* 页内字节 0..127 */
    reg [7:0]  sr;
    reg [7:0]  m_byte;      /* 流水: 渲染字节寄存器 (切断长组合链) */
    reg        fetched;     /* 已取数标志 */
    reg [3:0]  biti;
    reg [3:0]  ht;
    reg        do_sclk;
    reg        sclk_r, mosi_r, dc_r, cs_r, res_r;

    assign sclk = sclk_r;
    assign mosi = mosi_r;
    assign dc   = dc_r;
    assign cs   = cs_r;
    assign res  = res_r;
    assign busy = (st == ST_CMD) || (st == ST_PAGE);
    assign dbg_sstate = st;

    /* ---------- 渲染: (页 pg, 字符列 gcnt, 字内列 scnt) -> 数据字节 ----------
     * gcnt/scnt 由状态机随字节发送递增, 避免每字节做 x/6 除法(组合链过长)
     */
    reg [4:0] gcnt;         /* 行内字符列 0..21 */
    reg [2:0] scnt;         /* 字内列 0..5 */
    wire [7:0] lineaddr = (pg * 8'd20) + {3'b0, gcnt};      /* ascii 偏移 0..161 */
    wire       gvalid  = (gcnt <= 5'd19);
    wire [7:0] code    = ascii_buf[lineaddr];
    wire [7:0] disp_byte = (gvalid && (scnt <= 3'd4)) ? font[scnt][code] : 8'h00;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= ST_RES; tcnt <= 32'd0;
            ci <= 6'd0; pg <= 3'd0; bx <= 8'd0;
            gcnt <= 5'd0; scnt <= 3'd0;
            sr <= 8'h00; m_byte <= 8'h00; fetched <= 1'b0;
            biti <= 4'd0; ht <= 4'd0;
            do_sclk <= 1'b0;
            sclk_r <= 1'b0; mosi_r <= 1'b0;
            dc_r <= 1'b0; cs_r <= 1'b1; res_r <= 1'b0;
        end else begin
            case (st)
            ST_RES: begin
                if (tcnt >= (CLK_HZ/10)) begin   /* RES 低 100ms 后拉高 */
                    res_r <= 1'b1; tcnt <= 32'd0;
                    st <= ST_CMD;
                end else tcnt <= tcnt + 32'd1;
            end

            ST_CMD: begin
                if (!do_sclk) begin
                    if (cmd_rom[ci] == 8'hFF) begin
                        cs_r <= 1'b1;
                        ci <= 6'd0; pg <= 3'd0; bx <= 8'd0;
                        gcnt <= 5'd0; scnt <= 3'd0;
                        st <= ST_PAGE;
                    end else begin
                        sr <= cmd_rom[ci];
                        biti <= 4'd7; ht <= 4'd0;
                        cs_r <= 1'b0; dc_r <= 1'b0;
                        mosi_r <= cmd_rom[ci][7];
                        sclk_r <= 1'b0;
                        do_sclk <= 1'b1;
                    end
                end else begin
                    if (ht == HALF) begin
                        ht <= 4'd0;
                        if (sclk_r) begin
                            sclk_r <= 1'b0;
                            if (biti == 4'd0) begin
                                do_sclk <= 1'b0;
                                cs_r <= 1'b1;
                                ci <= ci + 6'd1;
                            end else begin
                                biti <= biti - 4'd1;
                                mosi_r <= sr[biti - 4'd1];
                            end
                        end else sclk_r <= 1'b1;
                    end else ht <= ht + 4'd1;
                end
            end

            ST_PAGE: begin
                if (!do_sclk) begin
                    if (!fetched) begin
                        m_byte <= disp_byte;
                        fetched <= 1'b1;
                    end else begin
                        sr <= m_byte;
                        biti <= 4'd7; ht <= 4'd0;
                        if (bx == 8'd0) begin
                            cs_r <= 1'b0; dc_r <= 1'b1;
                        end
                        mosi_r <= m_byte[7];
                        sclk_r <= 1'b0;
                        do_sclk <= 1'b1;
                        fetched <= 1'b0;
                    end
                end else begin
                    if (ht == HALF) begin
                        ht <= 4'd0;
                        if (sclk_r) begin
                            sclk_r <= 1'b0;
                            if (biti == 4'd0) begin
                                do_sclk <= 1'b0;
                                if (bx == 8'd127) begin
                                    bx <= 8'd0; gcnt <= 5'd0; scnt <= 3'd0;
                                    cs_r <= 1'b1;
                                    if (pg == 3'd7) st <= ST_GAP;
                                    else pg <= pg + 3'd1;
                                end else begin
                                    bx <= bx + 8'd1;
                                    if (scnt == 3'd5) begin
                                        scnt <= 3'd0; gcnt <= gcnt + 1'b1;
                                    end else scnt <= scnt + 1'b1;
                                end
                            end else begin
                                biti <= biti - 4'd1;
                                mosi_r <= sr[biti - 4'd1];
                            end
                        end else sclk_r <= 1'b1;
                    end else ht <= ht + 4'd1;
                end
            end

            ST_GAP: begin
                if (tcnt >= (CLK_HZ/2)) begin        /* 0.5s 后整帧重刷 */
                    tcnt <= 32'd0;
                    pg <= 3'd0; bx <= 8'd0;
                    gcnt <= 5'd0; scnt <= 3'd0;
                    st <= ST_PAGE;
                end else tcnt <= tcnt + 32'd1;
            end
            default: st <= ST_RES;
            endcase
        end
    end

endmodule
