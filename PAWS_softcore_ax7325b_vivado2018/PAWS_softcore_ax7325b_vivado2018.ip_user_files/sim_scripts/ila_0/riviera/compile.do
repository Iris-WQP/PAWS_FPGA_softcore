vlib work
vlib riviera

vlib riviera/xil_defaultlib
vlib riviera/xpm

vmap xil_defaultlib riviera/xil_defaultlib
vmap xpm riviera/xpm

vlog -work xil_defaultlib  -sv2k12 "+incdir+../../../../PAWS_softcore_ax7325b_vivado2018.srcs/sources_1/ip/ila_0/hdl/verilog" "+incdir+../../../../PAWS_softcore_ax7325b_vivado2018.srcs/sources_1/ip/ila_0/hdl/verilog" \
"/data/eda/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/data/eda/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -93 \
"/data/eda/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work xil_defaultlib  -v2k5 "+incdir+../../../../PAWS_softcore_ax7325b_vivado2018.srcs/sources_1/ip/ila_0/hdl/verilog" "+incdir+../../../../PAWS_softcore_ax7325b_vivado2018.srcs/sources_1/ip/ila_0/hdl/verilog" \
"../../../../PAWS_softcore_ax7325b_vivado2018.srcs/sources_1/ip/ila_0/sim/ila_0.v" \

vlog -work xil_defaultlib \
"glbl.v"

