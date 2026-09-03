## =====================================================================
## oled_core 引脚示例约束 —— EBAZ4205 Data3 排针 (2mm)
## OLED: 0.96" SSD1306, 4线SPI (SCLK/MOSI/DC/CS/RES), 3.3V
##   SCLK=R18 MOSI=R19 DC=P19 CS=T20 RES=U20  (Data3 第13~17脚)
##   VCC=第1/2脚(3.3V)  GND=第12脚
## 其它板卡请按你的原理图改 PACKAGE_PIN, IOSTANDARD 通常 LVCMOS33
## =====================================================================
set_property PACKAGE_PIN R18 [get_ports sclk]
set_property IOSTANDARD LVCMOS33 [get_ports sclk]

set_property PACKAGE_PIN R19 [get_ports mosi]
set_property IOSTANDARD LVCMOS33 [get_ports mosi]

set_property PACKAGE_PIN P19 [get_ports dc]
set_property IOSTANDARD LVCMOS33 [get_ports dc]

set_property PACKAGE_PIN T20 [get_ports cs]
set_property IOSTANDARD LVCMOS33 [get_ports cs]

set_property PACKAGE_PIN U20 [get_ports res]
set_property IOSTANDARD LVCMOS33 [get_ports res]

set_property PACKAGE_PIN W14 [get_ports led_red]
set_property IOSTANDARD LVCMOS33 [get_ports led_red]

set_property PACKAGE_PIN W13 [get_ports led_grn]
set_property IOSTANDARD LVCMOS33 [get_ports led_grn]
