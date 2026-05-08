# ModelSim / Questa simulation script for filter_classifier_tb
# Usage: vsim -do sim_filter_classifier.do

vlib work
vmap work work

# Compile source files (dependency order)
vlog +acc -sv ../analysis/sweep_result_store.v
vlog +acc -sv ../analysis/filter_classifier.v
vlog +acc -sv ./filter_classifier_tb.v

# Load testbench
vsim -voptargs=+acc work.filter_classifier_tb

# ── Wave window ──────────────────────────────────────────
add wave -divider "Clock & Reset"
add wave /filter_classifier_tb/clk
add wave /filter_classifier_tb/rst_n

add wave -divider "Test Control"
add wave -radix unsigned /filter_classifier_tb/test_case
add wave -radix unsigned /filter_classifier_tb/expected_type
add wave /filter_classifier_tb/classify_start
add wave /filter_classifier_tb/classifier_done

add wave -divider "Classifier FSM"
add wave -radix unsigned /filter_classifier_tb/u_classifier/state
add wave -radix unsigned /filter_classifier_tb/u_classifier/scan_index

add wave -divider "Classification Result"
add wave -radix unsigned /filter_classifier_tb/filter_type

add wave -divider "Store Read Interface"
add wave -radix unsigned /filter_classifier_tb/cls_read_index
add wave -radix hex /filter_classifier_tb/cls_read_h_mag_q16
add wave /filter_classifier_tb/cls_read_valid
add wave -radix unsigned /filter_classifier_tb/store_result_count

add wave -divider "Store Write Interface"
add wave /filter_classifier_tb/store_write_en
add wave -radix hex /filter_classifier_tb/store_h_mag_q16

add wave -divider "Classifier Internals"
add wave -radix hex /filter_classifier_tb/u_classifier/first_mag
add wave -radix hex /filter_classifier_tb/u_classifier/last_mag
add wave -radix hex /filter_classifier_tb/u_classifier/max_mag
add wave -radix hex /filter_classifier_tb/u_classifier/min_mag
add wave -radix unsigned /filter_classifier_tb/u_classifier/max_idx
add wave -radix unsigned /filter_classifier_tb/u_classifier/min_idx

configure wave -signalnamewidth 120
wave refresh

run -all
