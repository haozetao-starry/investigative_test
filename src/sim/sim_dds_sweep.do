# ModelSim / Questa simulation script for dds_sweep_tb
# Usage: vsim -do sim_dds_sweep.do

# Create work library
vlib work
vmap work work

# Compile source files
vlog +acc -sv ../dds/dds_phase.v
vlog +acc -sv ../dds/dds_amp.v
vlog +acc -sv ../dds/dds_sweep_ctrl.v
vlog +acc -sv ../dds/dds_top.v
vlog +acc -sv ./sin_sim.v
vlog +acc -sv ./dds_sweep_tb.v

# Load and run
vsim -voptargs=+acc work.dds_sweep_tb

# Add waves — thesis-friendly grouping
add wave -divider "Clock & Reset"
add wave /dds_sweep_tb/clk
add wave /dds_sweep_tb/rst_n

add wave -divider "Sweep State"
add wave /dds_sweep_tb/sweep_busy
add wave /dds_sweep_tb/sweep_done
add wave /dds_sweep_tb/step_sync
add wave -radix unsigned /dds_sweep_tb/freq_step

add wave -divider "Frequency Word"
add wave -radix hex /dds_sweep_tb/f_word

add wave -divider "DDS Output"
add wave -radix unsigned -format analog-step /dds_sweep_tb/wave_out

add wave -divider "Sweep Ctrl Internal"
add wave -radix hex /dds_sweep_tb/uut_ctrl/f_word
add wave /dds_sweep_tb/uut_ctrl/phase_clr
add wave -radix unsigned /dds_sweep_tb/uut_ctrl/dwell_cnt

configure wave -signalnamewidth 100
wave refresh

run -all
