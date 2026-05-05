#!/usr/bin/env python3
"""
DDS 扫频仿真结果绘图 —— 论文用高质量图

用法:
    python plot_dds_sweep.py [csv_file]

输出:
    dds_sweep_overview.png   — 全扫频概览，标注各频率段
    dds_sweep_zoom.png       — 四段频率局部放大
    dds_sweep_combined.png   — 组合图 (推荐放进论文)
"""

import sys, os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from matplotlib.patches import Rectangle

# ── 中文字体 ────────────────────────────────────────────
plt.rcParams["font.sans-serif"] = ["SimHei", "Microsoft YaHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

# ── 配色 ────────────────────────────────────────────────
COLORS = ["#2c7bb6", "#fdae61", "#d7191c", "#1a9641", "#7b3294", "#a6d96a"]
BG_ALPHA = 0.08

def load_csv(path):
    df = pd.read_csv(path)
    df["time_us"] = df["time_ns"] / 1000.0
    df["freq_mhz"] = df["freq_hz"] / 1e6
    return df

def find_step_boundaries(df):
    """返回每个频率段的 (start_idx, end_idx, freq_mhz)，包含初始段，合并同频相邻段"""
    steps = []
    sync_idx = df.index[df["step_sync"] == 1].tolist()

    if not sync_idx:
        return steps

    # 初始段: 从复位释放到第一个 step_sync 之前
    first_sync = sync_idx[0]
    if first_sync > 0:
        seg_start = 0
        seg_end = first_sync - 1
        freq = df.loc[seg_start, "freq_mhz"]
        if freq > 0.01:
            steps.append((seg_start, seg_end, freq))

    # 后续段: 每个 step_sync 开始
    for i, start in enumerate(sync_idx):
        end = sync_idx[i + 1] - 1 if i + 1 < len(sync_idx) else df.index[-1]
        freq = df.loc[start, "freq_mhz"]
        if freq < 0.01:
            continue
        # 合并同频相邻段
        if steps and abs(steps[-1][2] - freq) < 0.05:
            steps[-1] = (steps[-1][0], end, freq)
        else:
            steps.append((start, end, freq))

    return steps

# ═══════════════════════════════════════════════════════════
#  图 1: 全扫频概览
# ═══════════════════════════════════════════════════════════
def plot_overview(df, steps, outpath):
    fig, ax = plt.subplots(figsize=(14, 4.5))
    fig.patch.set_facecolor("white")

    ax.plot(df["time_us"], df["wave_out"],
            color=COLORS[0], linewidth=0.3, alpha=0.85)
    ax.axhline(y=128, color="gray", linestyle="--", linewidth=0.5, alpha=0.5)
    ax.set_ylim(30, 225)
    ax.set_ylabel("DDS Output (8-bit)", fontsize=11)
    ax.set_xlabel("Time (us)", fontsize=11)

    # 频率段背景 + 标注
    for i, (si, ei, fmhz) in enumerate(steps):
        t0 = df.loc[si, "time_us"]
        t1 = df.loc[ei, "time_us"]
        color = COLORS[i % len(COLORS)]
        ax.axvspan(t0, t1, alpha=BG_ALPHA, color=color)
        ax.annotate(
            f"{fmhz:.1f} MHz",
            xy=((t0 + t1) / 2, 210),
            ha="center", va="top", fontsize=10, fontweight="bold",
            color=color,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=color, alpha=0.85),
        )

    ax.set_title("DDS Frequency Sweep: 1 → 4 MHz  (step = 1 MHz, dwell = 500 clk)",
                 fontsize=13, fontweight="bold", pad=12)
    ax.grid(True, alpha=0.2)
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")

# ═══════════════════════════════════════════════════════════
#  图 2: 每段频率局部放大
# ═══════════════════════════════════════════════════════════
def plot_zoom(df, steps, outpath):
    n = len(steps)
    fig, axes = plt.subplots(n, 1, figsize=(14, 2.2 * n), sharex=False)
    fig.patch.set_facecolor("white")

    for i, (si, ei, fmhz) in enumerate(steps):
        ax = axes[i] if n > 1 else axes
        seg = df.loc[si:ei]
        t_us = seg["time_us"].values
        wave = seg["wave_out"].values

        color = COLORS[i % len(COLORS)]
        ax.plot(t_us, wave, color=color, linewidth=0.5)
        ax.axhline(y=128, color="gray", linestyle="--", linewidth=0.5, alpha=0.4)
        ax.set_ylim(30, 225)

        # 标注频率
        period_us = 1.0 / fmhz
        n_periods = (t_us[-1] - t_us[0]) * fmhz
        ax.set_ylabel("Output", fontsize=9)
        ax.text(
            0.99, 0.92,
            f"f = {fmhz:.0f} MHz | T = {period_us*1000:.0f} ns | ~{n_periods:.0f} cycles",
            transform=ax.transAxes, ha="right", va="top",
            fontsize=9, fontweight="bold", color=color,
            bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=color, alpha=0.85),
        )
        ax.grid(True, alpha=0.15)

    axes[-1].set_xlabel("Time (us)", fontsize=11)
    fig.suptitle("DDS Sweep — Zoom into Each Frequency Step",
                 fontsize=13, fontweight="bold", y=1.01)
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")

# ═══════════════════════════════════════════════════════════
#  图 3: 组合图 (推荐论文使用)
# ═══════════════════════════════════════════════════════════
def plot_combined(df, steps, outpath):
    n = len(steps)
    fig = plt.figure(figsize=(15, 10), facecolor="white")

    # ── 上半部分: 概览 ──
    ax_top = fig.add_axes([0.07, 0.56, 0.90, 0.38])
    ax_top.plot(df["time_us"], df["wave_out"],
                color=COLORS[0], linewidth=0.25, alpha=0.85)
    ax_top.axhline(y=128, color="gray", linestyle="--", linewidth=0.5, alpha=0.5)
    ax_top.set_ylim(30, 225)
    ax_top.set_ylabel("DDS Output (8-bit)", fontsize=11)

    for i, (si, ei, fmhz) in enumerate(steps):
        t0 = df.loc[si, "time_us"]
        t1 = df.loc[ei, "time_us"]
        color = COLORS[i % len(COLORS)]
        ax_top.axvspan(t0, t1, alpha=BG_ALPHA, color=color)
        ax_top.annotate(
            f"{fmhz:.0f} MHz",
            xy=((t0 + t1) / 2, 218),
            ha="center", va="top", fontsize=9.5, fontweight="bold",
            color=color,
            bbox=dict(boxstyle="round,pad=0.25", fc="white", ec=color, alpha=0.9),
        )
    ax_top.set_title("DDS Frequency Sweep Overview  (1→4 MHz, 500 clk/step)",
                     fontsize=13, fontweight="bold")
    ax_top.grid(True, alpha=0.15)
    ax_top.tick_params(labelbottom=False)

    # ── 下半部分: 各频率段拼成一行 ──
    # 每段取最后 15 个周期
    n = len(steps)
    panel_w = 0.90 / n
    for i, (si, ei, fmhz) in enumerate(steps):
        seg = df.loc[si:ei]
        samples_per_period = 50.0 / fmhz  # 50MHz clock
        n_samples = int(15 * samples_per_period)
        seg_tail = seg.iloc[-n_samples:] if len(seg) > n_samples else seg

        ax = fig.add_axes([0.07 + i * panel_w + 0.01, 0.08, panel_w - 0.02, 0.38])
        color = COLORS[i % len(COLORS)]
        ax.plot(seg_tail["time_us"].values, seg_tail["wave_out"].values,
                color=color, linewidth=0.6)
        ax.axhline(y=128, color="gray", linestyle="--", linewidth=0.4, alpha=0.4)
        ax.set_ylim(30, 225)
        ax.set_title(f"f = {fmhz:.0f} MHz", fontsize=11, fontweight="bold", color=color)
        ax.set_xlabel("Time (us)", fontsize=9)
        if i == 0:
            ax.set_ylabel("Output", fontsize=9)
        ax.grid(True, alpha=0.15)

    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")

# ═══════════════════════════════════════════════════════════
#  图 4: 可选 — FFT 频谱
# ═══════════════════════════════════════════════════════════
def plot_spectrum(df, steps, outpath):
    n = len(steps)
    cols = min(n, 2)
    rows = (n + cols - 1) // cols
    fig, axes = plt.subplots(rows, cols, figsize=(6 * cols, 4 * rows), facecolor="white")
    if n == 1:
        axes = [axes]
    else:
        axes = axes.flatten()

    for i, (si, ei, fmhz) in enumerate(steps):
        ax = axes[i]
        seg = df.loc[si:ei, "wave_out"].values
        # 去直流
        seg_ac = seg - np.mean(seg)
        win = np.hanning(len(seg_ac))
        fft = np.abs(np.fft.rfft(seg_ac * win))
        freqs = np.fft.rfftfreq(len(seg_ac), d=20e-9)  # 20ns sample period

        ax.plot(freqs / 1e6, fft, color=COLORS[i], linewidth=0.8)
        ax.set_xlim(0, 6)
        ymax = np.max(fft[1:]) * 1.2 if len(fft) > 1 else 1
        ax.set_ylim(0, ymax)

        # 标注主峰
        peak_idx = np.argmax(fft[1:]) + 1
        peak_freq = freqs[peak_idx] / 1e6
        ax.axvline(x=peak_freq, color="red", linestyle=":", linewidth=0.8, alpha=0.7)
        ax.annotate(
            f"{peak_freq:.2f} MHz",
            xy=(peak_freq, fft[peak_idx]),
            xytext=(peak_freq + 0.5, fft[peak_idx] * 0.85),
            fontsize=9, color="red",
            arrowprops=dict(arrowstyle="->", color="red", lw=0.8),
        )

        ax.set_title(f"f = {fmhz:.0f} MHz", fontsize=11, fontweight="bold", color=COLORS[i])
        ax.set_xlabel("Frequency (MHz)", fontsize=9)
        if i in [0, 2]:
            ax.set_ylabel("Magnitude", fontsize=9)
        ax.grid(True, alpha=0.15)

    fig.suptitle("DDS Output Spectrum per Frequency Step", fontsize=13, fontweight="bold")
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")

# ═══════════════════════════════════════════════════════════
#  main
# ═══════════════════════════════════════════════════════════
def main():
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "dds_sweep_wave.csv"
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if not os.path.isabs(csv_path):
        csv_path = os.path.join(script_dir, csv_path)

    if not os.path.exists(csv_path):
        print(f"ERROR: CSV not found: {csv_path}")
        print("Run the simulation first: vsim -do sim_dds_sweep.do")
        sys.exit(1)

    print(f"Loading: {csv_path}")
    df = load_csv(csv_path)
    print(f"  {len(df)} samples, {df['time_us'].iloc[-1]:.1f} us total")

    steps = find_step_boundaries(df)
    print(f"  {len(steps)} frequency steps detected:")
    for si, ei, fmhz in steps:
        print(f"    {fmhz:.0f} MHz  ({si}..{ei}, {ei - si + 1} samples)")

    out_dir = script_dir
    plot_overview(df, steps, os.path.join(out_dir, "dds_sweep_overview.png"))
    plot_zoom(df, steps, os.path.join(out_dir, "dds_sweep_zoom.png"))
    plot_combined(df, steps, os.path.join(out_dir, "dds_sweep_combined.png"))
    plot_spectrum(df, steps, os.path.join(out_dir, "dds_sweep_spectrum.png"))

    print("\nDone! Generated 4 figures:")
    print(f"  {out_dir}/dds_sweep_overview.png")
    print(f"  {out_dir}/dds_sweep_zoom.png")
    print(f"  {out_dir}/dds_sweep_combined.png   ← recommended for thesis")
    print(f"  {out_dir}/dds_sweep_spectrum.png")

if __name__ == "__main__":
    main()
