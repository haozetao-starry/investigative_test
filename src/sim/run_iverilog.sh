#!/bin/bash
# Run DDS sweep simulation with Icarus Verilog (free, no Quartus needed)
# Make sure iverilog is installed: apt install iverilog  (or download from http://iverilog.icarus.com)

cd "$(dirname "$0")"

echo "==> Compiling..."
iverilog -g2012 -o dds_sweep_tb.vvp \
    ../dds/dds_phase.v \
    ../dds/dds_amp.v \
    ../dds/dds_sweep_ctrl.v \
    ../dds/dds_top.v \
    ./sin_sim.v \
    ./dds_sweep_tb.v

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

echo "==> Running simulation..."
vvp dds_sweep_tb.vvp

echo ""
echo "==> Done. Output files:"
echo "    dds_sweep_wave.csv   — waveform samples (one per clock)"
echo "    dds_sweep_tb.vcd     — full signal dump for GTKWave"
echo ""
echo "To view waveforms: gtkwave dds_sweep_tb.vcd"
