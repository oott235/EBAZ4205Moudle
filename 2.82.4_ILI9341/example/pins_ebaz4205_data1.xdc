## ============ EBAZ4205: 2.8"/2.4" ILI9341 TFT (8080-8bit) — Data1 排针约束 ============
## 屏幕模块接 Data1 排针 (2mm, 20 脚): 1/2=3.3V, 3/4/12=GND, 10=NC, 其余为 IO
## 脚位 -> 封装引脚: 5=A20 6=H16 7=B19 8=B20 9=C20 11=H17
##                  13=D20 14=D18 15=H18 16=D19 17=F20 18=E19 19=F19 20=K17

set_property PACKAGE_PIN D20 [get_ports {lcd_db[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[0]}]
set_property PACKAGE_PIN D18 [get_ports {lcd_db[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[1]}]
set_property PACKAGE_PIN H18 [get_ports {lcd_db[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[2]}]
set_property PACKAGE_PIN D19 [get_ports {lcd_db[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[3]}]
set_property PACKAGE_PIN F20 [get_ports {lcd_db[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[4]}]
set_property PACKAGE_PIN E19 [get_ports {lcd_db[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[5]}]
set_property PACKAGE_PIN F19 [get_ports {lcd_db[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[6]}]
set_property PACKAGE_PIN K17 [get_ports {lcd_db[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {lcd_db[7]}]

set_property PACKAGE_PIN A20 [get_ports lcd_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_cs_n]
set_property PACKAGE_PIN H16 [get_ports lcd_rs]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rs]
set_property PACKAGE_PIN B19 [get_ports lcd_wr_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_wr_n]
set_property PACKAGE_PIN H17 [get_ports lcd_rd_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rd_n]
set_property PACKAGE_PIN B20 [get_ports lcd_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_rst_n]
set_property PACKAGE_PIN C20 [get_ports lcd_bl]
set_property IOSTANDARD LVCMOS33 [get_ports lcd_bl]

## 板载 LED6 (心跳): 红 W14 / 绿 W13, 低电平点亮
set_property PACKAGE_PIN W14 [get_ports led_red]
set_property IOSTANDARD LVCMOS33 [get_ports led_red]
set_property PACKAGE_PIN W13 [get_ports led_grn]
set_property IOSTANDARD LVCMOS33 [get_ports led_grn]

## 换板/换脚: 只改这里; 引脚表同步改 README
