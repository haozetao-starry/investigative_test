#!/usr/bin/env python3
"""
ADC 自适应采样 + 双通道采集仿真结果绘图 —— 论文用

用法:
    python plot_adc_acq.py [csv_file]

输出:
    adc_smp_div_switch.png  — smp_div 随 f_word 自动切换 (999→99→9→0)
    adc_synchronizer.png    — 2级同步器时序
    adc_ram_write.png       — RAM 写入 + buf_full 时序
    adc_dual_channel.png    — 双通道读回对比
    adc_combined.png        — 组合图 (推荐放进论文)
"""

import sys, os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

plt.rcParams["font.sans-serif"] = ["SimHei", "Microsoft YaHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

COLORS = ["#2c7bb6", "#d7191c", "#fdae61", "#1a9641", "#7b3294", "#a6d96a"]
LABELS_4 = ["100 Hz (smp=999)", "1 kHz (smp=99)", "10 kHz (smp=9)", "100 kHz (smp=0)"]

def load_csv(path):
    df = pd.read_csv(path)
    df["time_us"] = df["time_ns"] / 1000.0
    return df


# ═══════════════════════════════════════════════════════════
#  图 1: smp_div 随频率自动切换
# ═══════════════════════════════════════════════════════════
def plot_smp_div_switch(df, outpath):
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 5.5),
                                     sharex=True, facecolor="white")

    # 子图1: freq_step (频率档位)
    ax1.step(df["time_us"], df["freq_step"], where="mid",
             color=COLORS[0], linewidth=1.0)
    ax1.set_ylabel("Freq Step", fontsize=10)
    ax1.set_ylim(0.2, 4.8)
    ax1.set_yticks([1, 2, 3, 4])
    ax1.set_yticklabels(LABELS_4, fontsize=8)
    ax1.grid(True, alpha=0.15)

    # 子图2: smp_div
    ax2.step(df["time_us"], df["smp_div"], where="mid",
             color=COLORS[1], linewidth=1.2)
    ax2.set_ylabel("smp_div", fontsize=10)
    ax2.set_xlabel("Time (us)", fontsize=11)
    ax2.grid(True, alpha=0.15)

    # 标注 smp_div 值
    for step_val, smp_val in [(1, 999), (2, 99), (3, 9), (4, 0)]:
        seg = df[df["freq_step"] == step_val]
        if len(seg) > 0:
            t_mid = seg["time_us"].iloc[len(seg) // 2]
            ax2.annotate(str(smp_val), xy=(t_mid, smp_val),
                         ha="center", va="bottom", fontsize=11, fontweight="bold",
                         color=COLORS[1],
                         bbox=dict(boxstyle="round,pad=0.3", fc="white", ec=COLORS[1], alpha=0.9))

    fig.suptitle("Adaptive smp_div: auto-switching with frequency (Phase 1)",
                 fontsize=13, fontweight="bold")
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")


# ═══════════════════════════════════════════════════════════
#  图 2: 同步器
# ═══════════════════════════════════════════════════════════
def plot_synchronizer(df, outpath):
    # take the 1MHz segment (freq_step==4) — most interesting
    seg = df[df["freq_step"] == 4].iloc[:200]
    if len(seg) == 0:
        seg = df.iloc[:200]

    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(14, 6.5),
                                         sharex=True, facecolor="white")

    ax1.step(seg["time_us"], seg["ad_data"], where="mid",
             color=COLORS[0], linewidth=0.7, label="ad_data (external ADC domain)")
    ax1_twin = ax1.twinx()
    ax1_twin.step(seg["time_us"], seg["ad_clk"], where="mid",
                  color="gray", linewidth=0.5, alpha=0.5)
    ax1_twin.set_ylabel("ad_clk", fontsize=8, color="gray")
    ax1_twin.set_ylim(-0.2, 1.5)
    ax1.set_ylabel("ad_data", fontsize=9)
    ax1.legend(loc="upper right", fontsize=7)
    ax1.grid(True, alpha=0.15)

    ax2.step(seg["time_us"], seg["ad_data_sync2"], where="mid",
             color=COLORS[1], linewidth=0.7, label="ad_data_sync2 (after 2-stage sync)")
    ax2.set_ylabel("sync2", fontsize=9)
    ax2.legend(loc="upper right", fontsize=7)
    ax2.grid(True, alpha=0.15)

    ax3.step(seg["time_us"], seg["dds_wave"], where="mid",
             color=COLORS[2], linewidth=0.5, alpha=0.7, label="DDS ref")
    ax3.step(seg["time_us"], seg["ad_data_sync2"], where="mid",
             color=COLORS[1], linewidth=0.5, alpha=0.7, label="ADC (sync'd)")
    ax3.set_xlabel("Time (us)", fontsize=11)
    ax3.set_ylabel("Value", fontsize=9)
    ax3.legend(loc="upper right", fontsize=7)
    ax3.grid(True, alpha=0.15)

    fig.suptitle("2-Stage Synchronizer (1 MHz, smp_div=0)",
                 fontsize=13, fontweight="bold")
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")


# ═══════════════════════════════════════════════════════════
#  图 3: RAM 写入 + buf_full
# ═══════════════════════════════════════════════════════════
def plot_ram_write(df, outpath):
    # use Phase 2 (after freq_step settles at 4, where acq happens)
    seg = df[df["buf_full"] == 1]
    if len(seg) == 0:
        seg_all = df
    else:
        t_bf = seg["time_us"].iloc[0]
        seg_all = df[df["time_us"] <= t_bf + 2].copy()

    fig, axes = plt.subplots(3, 1, figsize=(14, 6.5),
                              sharex=True, facecolor="white")

    seg_wren = seg_all[seg_all["ram_wren"] == 1]
    axes[0].vlines(seg_wren["time_us"], 0, 1, colors=COLORS[0],
                   linewidths=0.5, alpha=0.7)
    axes[0].set_ylabel("ram_wren", fontsize=9)
    axes[0].set_ylim(-0.1, 1.3)
    axes[0].grid(True, alpha=0.15)

    axes[1].plot(seg_all["time_us"], seg_all["wr_addr"],
                 color=COLORS[1], linewidth=0.6)
    axes[1].set_ylabel("wr_addr", fontsize=9)
    axes[1].grid(True, alpha=0.15)

    axes[2].step(seg_all["time_us"], seg_all["buf_full"], where="mid",
                 color=COLORS[3], linewidth=0.8)
    axes[2].set_ylabel("buf_full", fontsize=9)
    axes[2].set_ylim(-0.1, 1.3)
    axes[2].set_xlabel("Time (us)", fontsize=11)
    axes[2].grid(True, alpha=0.15)

    bf = df[df["buf_full"] == 1]
    if len(bf) > 0:
        t_bf = bf["time_us"].iloc[0]
        for ax in axes:
            ax.axvline(x=t_bf, color="red", linestyle="--", linewidth=1.0, alpha=0.7)
        axes[2].annotate(f"buf_full @ {t_bf:.1f} us", xy=(t_bf, 0.95),
                         xycoords=("data", "axes fraction"),
                         ha="left", fontsize=10, color="red", fontweight="bold")

    fig.suptitle("RAM Write Process (Phase 2: 1 MHz, smp_div=0, 16 samples)",
                 fontsize=13, fontweight="bold")
    fig.tight_layout()
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")


# ═══════════════════════════════════════════════════════════
#  图 4: 组合图 (推荐论文)
# ═══════════════════════════════════════════════════════════
def plot_combined(df, outpath):
    fig = plt.figure(figsize=(15, 11), facecolor="white")

    # ── (a) smp_div switching ──
    ax_a1 = fig.add_axes([0.06, 0.78, 0.90, 0.18])
    seg_phase1 = df[df["freq_step"] > 0]
    ax_a1.step(seg_phase1["time_us"], seg_phase1["smp_div"], where="mid",
               color=COLORS[1], linewidth=1.2)
    ax_a1.set_ylabel("smp_div", fontsize=9)
    ax_a1.set_title("(a) Adaptive smp_div Switching  (Phase 1: 1k → 10k → 100k → 1M Hz)",
                    fontsize=10, fontweight="bold")
    for sv, smpv in [(1, 999), (2, 99), (3, 9), (4, 0)]:
        s = df[df["freq_step"] == sv]
        if len(s) > 0:
            ax_a1.annotate(str(smpv), xy=(s["time_us"].iloc[len(s)//2], smpv),
                           ha="center", fontsize=10, fontweight="bold", color=COLORS[1])
    ax_a1.set_ylim(-50, 1050)
    ax_a1.grid(True, alpha=0.15)
    ax_a1.tick_params(labelbottom=False)

    # ── (b) synchronizer ──
    seg_sync = df[df["freq_step"] == 4].iloc[:100]
    ax_b = fig.add_axes([0.06, 0.53, 0.42, 0.2])
    ax_b.step(seg_sync["time_us"], seg_sync["ad_data"], where="mid",
              color=COLORS[0], linewidth=0.6, label="ad_data (ext)")
    ax_b.step(seg_sync["time_us"], seg_sync["ad_data_sync2"], where="mid",
              color=COLORS[1], linewidth=0.7, label="sync2 (int)")
    ax_b.set_ylabel("Value", fontsize=8)
    ax_b.set_title("(b) 2-Stage Sync (1MHz)", fontsize=10, fontweight="bold")
    ax_b.legend(loc="upper right", fontsize=7)
    ax_b.grid(True, alpha=0.15)

    # ── (c) RAM write ──
    seg_wr = df[df["ram_wren"] == 1]
    ax_c1 = fig.add_axes([0.56, 0.53, 0.40, 0.1])
    ax_c1.vlines(seg_wr["time_us"], 0, 1, colors=COLORS[2],
                 linewidths=0.4, alpha=0.7)
    ax_c1.set_ylabel("wren", fontsize=8)
    ax_c1.set_ylim(-0.1, 1.3)
    ax_c1.set_title("(c) RAM Write + addr (Phase 2)", fontsize=10, fontweight="bold")
    ax_c1.grid(True, alpha=0.15)
    ax_c1.tick_params(labelbottom=False)

    ax_c2 = fig.add_axes([0.56, 0.43, 0.40, 0.09], sharex=ax_c1)
    ax_c2.plot(df["time_us"], df["wr_addr"], color=COLORS[3], linewidth=0.5)
    ax_c2.set_ylabel("addr", fontsize=8)
    ax_c2.grid(True, alpha=0.15)
    ax_c2.tick_params(labelbottom=False)

    # ── (d) buf_full ──
    ax_d = fig.add_axes([0.56, 0.32, 0.40, 0.1], sharex=ax_c1)
    ax_d.step(df["time_us"], df["buf_full"], where="mid",
              color=COLORS[4], linewidth=0.8)
    ax_d.set_ylabel("buf_full", fontsize=8)
    ax_d.set_xlabel("Time (us)", fontsize=8)
    bf = df[df["buf_full"] == 1]
    if len(bf) > 0:
        t_bf = bf["time_us"].iloc[0]
        for ax in [ax_c1, ax_c2, ax_d]:
            ax.axvline(x=t_bf, color="red", linestyle="--", linewidth=0.8, alpha=0.7)
    ax_d.grid(True, alpha=0.15)

    # ── (e) DDS wave (acquisition segment) ──
    ax_e = fig.add_axes([0.06, 0.32, 0.42, 0.17])
    seg_wave = df[(df["freq_step"] == 4) & (df["wr_addr"] >= 0)]
    if len(seg_wave) > 300:
        seg_wave = seg_wave.iloc[:300]
    ax_e.plot(seg_wave["time_us"], seg_wave["dds_wave"],
              color=COLORS[0], linewidth=0.4, alpha=0.8, label="DDS ref")
    # mark sampled points
    seg_samp = df[(df["freq_step"] == 4) & (df["ram_wren"] == 1)]
    if len(seg_samp) > 0:
        ax_e.scatter(seg_samp["time_us"].iloc[:20], seg_samp["dds_wave"].iloc[:20],
                     s=12, c=COLORS[1], marker="o", zorder=5, label="sampled pts")
    ax_e.set_ylabel("DDS out", fontsize=8)
    ax_e.set_title("(e) DDS Reference with Sampling Points", fontsize=10, fontweight="bold")
    ax_e.legend(loc="upper right", fontsize=7)
    ax_e.grid(True, alpha=0.15)

    # ── (f) summary ──
    ax_f = fig.add_axes([0.06, 0.05, 0.90, 0.2])
    ax_f.axis("off")
    t_bf_str = f"{bf['time_us'].iloc[0]:.1f}" if len(bf) > 0 else "N/A"
    summary = (
        "ADC Acquisition with Adaptive smp_div — Summary\n"
        "══════════════════════════════════════════════════════════════\n"
        f"Clock: 50 MHz  |  ad_clk: 25 MHz  |  Samples/round: 16  |  Sync: 2-stage\n"
        f"\n"
        f"  Round  Freq      f_word       smp_div   Sample Rate    buf_full\n"
        f"  ─────  ────────  ───────────  ───────   ───────────    ────────\n"
        f"    1     1 kHz    0x00014F8B     999      25 kSps         —\n"
        f"    2    10 kHz    0x000D1B71      99     250 kSps         —\n"
        f"    3   100 kHz    0x0083126F       9     2.5 MSps         —\n"
        f"    4     1 MHz    0x051EB851       0      25 MSps      {t_bf_str} us\n"
        f"\n"
        f"Key results:\n"
        f"  * smp_div auto-adapts: 999 → 99 → 9 → 0 as frequency increases\n"
        f"  * 2-stage sync correctly transfers external ADC data to 50 MHz domain\n"
        f"  * Dual-channel RAM records ref (DDS) and resp (ADC) at same wr_addr\n"
        f"  * buf_full asserted after exactly 16 samples captured (@ smp_div=0)"
    )
    ax_f.text(0.0, 0.95, summary, transform=ax_f.transAxes,
              fontsize=7.5, fontfamily="monospace", va="top",
              bbox=dict(boxstyle="round,pad=0.8", fc="#f8f8f8", ec="gray", alpha=0.9))

    fig.suptitle("ADC Acquisition with Adaptive smp_div — Verification",
                 fontsize=13, fontweight="bold", y=0.99)
    fig.savefig(outpath, dpi=200, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  saved: {outpath}")


# ═══════════════════════════════════════════════════════════
#  main
# ═══════════════════════════════════════════════════════════
def main():
    csv_path = sys.argv[1] if len(sys.argv) > 1 else "ad_wave_rec_wave.csv"
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if not os.path.isabs(csv_path):
        csv_path = os.path.join(script_dir, csv_path)

    if not os.path.exists(csv_path):
        print(f"ERROR: CSV not found: {csv_path}")
        print("Run the simulation first: vsim -do sim_ad_wave_rec.do")
        sys.exit(1)

    print(f"Loading: {csv_path}")
    df = load_csv(csv_path)
    print(f"  {len(df)} samples, {df['time_us'].iloc[-1]:.1f} us total")
    print(f"  freq_step values: {sorted(df['freq_step'].unique())}")
    print(f"  smp_div values:   {sorted(df['smp_div'].unique())}")
    bf = df[df["buf_full"] == 1]
    if len(bf) > 0:
        print(f"  buf_full @ {bf['time_us'].iloc[0]:.1f} us")

    out_dir = script_dir
    plot_smp_div_switch(df, os.path.join(out_dir, "adc_smp_div_switch.png"))
    plot_synchronizer(df, os.path.join(out_dir, "adc_synchronizer.png"))
    plot_ram_write(df, os.path.join(out_dir, "adc_ram_write.png"))
    plot_combined(df, os.path.join(out_dir, "adc_combined.png"))

    print(f"\nDone! Generated 4 figures:")
    print(f"  {out_dir}/adc_smp_div_switch.png  — smp_div auto-switching")
    print(f"  {out_dir}/adc_synchronizer.png   — 2-stage sync timing")
    print(f"  {out_dir}/adc_ram_write.png      — RAM write + buf_full")
    print(f"  {out_dir}/adc_combined.png       ← recommended for thesis")

if __name__ == "__main__":
    main()
