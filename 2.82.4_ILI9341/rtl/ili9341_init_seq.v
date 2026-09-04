`timescale 1ns/1ps
/* ili9341_init_seq.v - ILI9341 初始化命令表 (自动生成, 勿手改)
 * 逐条对照 OLED2.8 BSP/bsp_ili9341.c (8080-8bit 已实测点亮)。
 * kind: 0=CMD 1=DAT 2=delay_ms 3=MADCTL_VALUE 4=PIXFMT_VALUE
 * 主状态机按本表跑 3 遍(与 C 的三遍初始化一致), 遍间延时 250ms */
module ili9341_init_seq (
    input  wire [6:0]  addr,
    output reg  [2:0]  kind,
    output reg  [23:0] val
);

    always @(*) begin
        kind = 3'd0; val = 24'd0;
        case (addr)
            7'd0  : begin kind = 3'd0; val = 24'd1; end
            7'd1  : begin kind = 3'd2; val = 24'd150; end
            7'd2  : begin kind = 3'd0; val = 24'd239; end
            7'd3  : begin kind = 3'd1; val = 24'd3; end
            7'd4  : begin kind = 3'd1; val = 24'd128; end
            7'd5  : begin kind = 3'd1; val = 24'd2; end
            7'd6  : begin kind = 3'd0; val = 24'd207; end
            7'd7  : begin kind = 3'd1; val = 24'd0; end
            7'd8  : begin kind = 3'd1; val = 24'd193; end
            7'd9  : begin kind = 3'd1; val = 24'd48; end
            7'd10 : begin kind = 3'd0; val = 24'd237; end
            7'd11 : begin kind = 3'd1; val = 24'd100; end
            7'd12 : begin kind = 3'd1; val = 24'd3; end
            7'd13 : begin kind = 3'd1; val = 24'd18; end
            7'd14 : begin kind = 3'd1; val = 24'd129; end
            7'd15 : begin kind = 3'd0; val = 24'd232; end
            7'd16 : begin kind = 3'd1; val = 24'd133; end
            7'd17 : begin kind = 3'd1; val = 24'd0; end
            7'd18 : begin kind = 3'd1; val = 24'd120; end
            7'd19 : begin kind = 3'd0; val = 24'd203; end
            7'd20 : begin kind = 3'd1; val = 24'd57; end
            7'd21 : begin kind = 3'd1; val = 24'd44; end
            7'd22 : begin kind = 3'd1; val = 24'd0; end
            7'd23 : begin kind = 3'd1; val = 24'd52; end
            7'd24 : begin kind = 3'd1; val = 24'd2; end
            7'd25 : begin kind = 3'd0; val = 24'd247; end
            7'd26 : begin kind = 3'd1; val = 24'd32; end
            7'd27 : begin kind = 3'd0; val = 24'd234; end
            7'd28 : begin kind = 3'd1; val = 24'd0; end
            7'd29 : begin kind = 3'd1; val = 24'd0; end
            7'd30 : begin kind = 3'd0; val = 24'd192; end
            7'd31 : begin kind = 3'd1; val = 24'd35; end
            7'd32 : begin kind = 3'd0; val = 24'd193; end
            7'd33 : begin kind = 3'd1; val = 24'd16; end
            7'd34 : begin kind = 3'd0; val = 24'd197; end
            7'd35 : begin kind = 3'd1; val = 24'd62; end
            7'd36 : begin kind = 3'd1; val = 24'd40; end
            7'd37 : begin kind = 3'd0; val = 24'd199; end
            7'd38 : begin kind = 3'd1; val = 24'd134; end
            7'd39 : begin kind = 3'd0; val = 24'd54; end
            7'd40 : begin kind = 3'd3; val = 24'd0; end
            7'd41 : begin kind = 3'd0; val = 24'd58; end
            7'd42 : begin kind = 3'd4; val = 24'd0; end
            7'd43 : begin kind = 3'd0; val = 24'd177; end
            7'd44 : begin kind = 3'd1; val = 24'd0; end
            7'd45 : begin kind = 3'd1; val = 24'd24; end
            7'd46 : begin kind = 3'd0; val = 24'd182; end
            7'd47 : begin kind = 3'd1; val = 24'd8; end
            7'd48 : begin kind = 3'd1; val = 24'd130; end
            7'd49 : begin kind = 3'd1; val = 24'd39; end
            7'd50 : begin kind = 3'd0; val = 24'd242; end
            7'd51 : begin kind = 3'd1; val = 24'd0; end
            7'd52 : begin kind = 3'd0; val = 24'd38; end
            7'd53 : begin kind = 3'd1; val = 24'd1; end
            7'd54 : begin kind = 3'd0; val = 24'd224; end
            7'd55 : begin kind = 3'd1; val = 24'd15; end
            7'd56 : begin kind = 3'd1; val = 24'd49; end
            7'd57 : begin kind = 3'd1; val = 24'd43; end
            7'd58 : begin kind = 3'd1; val = 24'd12; end
            7'd59 : begin kind = 3'd1; val = 24'd14; end
            7'd60 : begin kind = 3'd1; val = 24'd8; end
            7'd61 : begin kind = 3'd1; val = 24'd78; end
            7'd62 : begin kind = 3'd1; val = 24'd241; end
            7'd63 : begin kind = 3'd1; val = 24'd55; end
            7'd64 : begin kind = 3'd1; val = 24'd7; end
            7'd65 : begin kind = 3'd1; val = 24'd16; end
            7'd66 : begin kind = 3'd1; val = 24'd3; end
            7'd67 : begin kind = 3'd1; val = 24'd14; end
            7'd68 : begin kind = 3'd1; val = 24'd9; end
            7'd69 : begin kind = 3'd1; val = 24'd0; end
            7'd70 : begin kind = 3'd0; val = 24'd225; end
            7'd71 : begin kind = 3'd1; val = 24'd0; end
            7'd72 : begin kind = 3'd1; val = 24'd14; end
            7'd73 : begin kind = 3'd1; val = 24'd20; end
            7'd74 : begin kind = 3'd1; val = 24'd3; end
            7'd75 : begin kind = 3'd1; val = 24'd17; end
            7'd76 : begin kind = 3'd1; val = 24'd7; end
            7'd77 : begin kind = 3'd1; val = 24'd49; end
            7'd78 : begin kind = 3'd1; val = 24'd193; end
            7'd79 : begin kind = 3'd1; val = 24'd72; end
            7'd80 : begin kind = 3'd1; val = 24'd8; end
            7'd81 : begin kind = 3'd1; val = 24'd15; end
            7'd82 : begin kind = 3'd1; val = 24'd12; end
            7'd83 : begin kind = 3'd1; val = 24'd49; end
            7'd84 : begin kind = 3'd1; val = 24'd54; end
            7'd85 : begin kind = 3'd1; val = 24'd15; end
            7'd86 : begin kind = 3'd0; val = 24'd17; end
            7'd87 : begin kind = 3'd2; val = 24'd150; end
            7'd88 : begin kind = 3'd0; val = 24'd41; end
            7'd89 : begin kind = 3'd2; val = 24'd30; end
            7'd90 : begin kind = 3'd0; val = 24'd54; end
            7'd91 : begin kind = 3'd3; val = 24'd0; end
            7'd92 : begin kind = 3'd0; val = 24'd58; end
            7'd93 : begin kind = 3'd4; val = 24'd0; end
            7'd94 : begin kind = 3'd7; val = 24'd0; end
            default: begin kind = 3'd0; val = 24'd0; end
        endcase
    end

endmodule
