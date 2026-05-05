# ModelSim / Questa simulation script for ad_wave_rec_tb
# Usage: vsim -do sim_ad_wave_rec.do

vlib work
vmap work work

# Compile all source files
vlog +acc -sv ../dds/dds_phase.v
vlog +acc -sv ../dds/dds_amp.v
vlog +acc -sv ../dds/dds_top.v
vlog +acc -sv ./sin_sim.v
vlog +acc -sv ./ADC_RAM_sim.v
vlog +acc -sv ../adc_acq/ad_wave_rec.v
vlog +acc -sv ./ad_wave_rec_tb.v

# Load testbench
vsim -voptargs=+acc work.ad_wave_rec_tb

# ── Wave window ──────────────────────────────────────────
add wave -divider "Clock & Reset"
add wave /ad_wave_rec_tb/clk
add wave /ad_wave_rec_tb/ad_clk
add wave /ad_wave_rec_tb/rst_n

add wave -divider "Frequency & smp_div (Adaptive)"
add wave -radix hex /ad_wave_rec_tb/f_word
add wave -radix unsigned /ad_wave_rec_tb/freq_step
add wave -radix unsigned /ad_wave_rec_tb/smp_div

add wave -divider "ADC Input + 2-stage Sync"
add wave -radix unsigned /ad_wave_rec_tb/ad_data_drv
add wave -radix unsigned /ad_wave_rec_tb/u_dut/ad_data_sync1
add wave -radix unsigned /ad_wave_rec_tb/u_dut/ad_data_sync2

add wave -divider "DDS Reference"
add wave -radix unsigned -format analog-step /ad_wave_rec_tb/dds_wave

add wave -divider "RAM Write"
add wave /ad_wave_rec_tb/u_dut/ram_wren
add wave -radix unsigned /ad_wave_rec_tb/u_dut/wr_addr
add wave -radix unsigned /ad_wave_rec_tb/u_dut/smp_cnt

add wave -divider "Status"
add wave /ad_wave_rec_tb/acq_start_reg
add wave /ad_wave_rec_tb/buf_full

add wave -divider "RAM Readback"
add wave -radix unsigned /ad_wave_rec_tb/rd_data
add wave -radix unsigned /ad_wave_rec_tb/ref_rd_data
add wave -radix unsigned /ad_wave_rec_tb/rd_addr

configure wave -signalnamewidth 120
wave refresh

run -all
