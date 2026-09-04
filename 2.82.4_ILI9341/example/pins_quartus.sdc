# example/pins_quartus.sdc - Quartus 时序约束示例(配合 prj_top_example_quartus.v)
# 把 clk 换成你的时钟名与周期; 引脚分配在 .qsf 或 Pin Planner 完成。
create_clock -name sys_clk -period 10.000 [get_ports clk]
