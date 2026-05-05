`timescale 1ns/1ps

module ad_wave_rec_tb;

    reg clk;
    reg rst_n;

    localparam integer CLK_HALF_NS    = 10;               // 50 MHz
    localparam integer SAMPLE_COUNT   = 16;               // tiny for speed

    // ── 4 test frequency words (per user spec thresholds) ───
    localparam [31:0] FW_100HZ  = 32'd8590;               // → smp_div=999
    localparam [31:0] FW_1KHZ   = 32'd85899;              // → smp_div=99
    localparam [31:0] FW_10KHZ  = 32'd858993;             // → smp_div=9
    localparam [31:0] FW_100KHZ = 32'd8589934;            // → smp_div=0

    // ── frequency & smp_div ─────────────────────────────────
    reg  [31:0] f_word;
    wire [15:0] smp_div;

    // ── ADC simulator ────────────────────────────────────────
    reg  [7:0]  ad_data_drv;
    reg         ad_otr_drv;
    reg  [31:0] adc_phase_acc;
    wire [9:0]  adc_rom_addr = adc_phase_acc[31:22];

    // ── DDS ──────────────────────────────────────────────────
    wire [7:0]  dds_wave;

    // ── ad_wave_rec ──────────────────────────────────────────
    wire        ad_clk;
    wire [7:0]  rd_data, ref_rd_data;
    wire        buf_full;
    reg         acq_start_reg;
    reg  [9:0]  rd_addr;

    // ── book-keeping ─────────────────────────────────────────
    integer     cycle_count, csv_fd, k;
    reg  [3:0]  freq_step;

    // ══════════════════════════════════════════════════════════
    //  Clock
    // ══════════════════════════════════════════════════════════
    initial begin
        clk = 1'b0;
        forever #(CLK_HALF_NS) clk = ~clk;
    end

    // ══════════════════════════════════════════════════════════
    //  VCD
    // ══════════════════════════════════════════════════════════
    initial begin
        $dumpfile("ad_wave_rec_tb.vcd");
        $dumpvars(0, ad_wave_rec_tb);
    end

    // ══════════════════════════════════════════════════════════
    //  smp_div_adapt: f_word → smp_div (0/9/99/999)
    // ══════════════════════════════════════════════════════════
    smp_div_adapt u_smp (
        .f_word  (f_word),
        .smp_div (smp_div)
    );

    // ══════════════════════════════════════════════════════════
    //  DUTs
    // ══════════════════════════════════════════════════════════
    dds_top u_dds (
        .clk(clk), .rst_n(rst_n), .phase_clr(1'b0),
        .f_word(f_word), .a_word(9'd256), .wave_out(dds_wave)
    );

    ad_wave_rec #(.SAMPLE_COUNT(SAMPLE_COUNT)) u_dut (
        .clk(clk), .rst_n(rst_n),
        .ad_data(ad_data_drv), .ad_otr(ad_otr_drv),
        .ref_data_in(dds_wave), .acq_start(acq_start_reg),
        .smp_div(smp_div), .rd_addr(rd_addr), .rd_en(1'b1),
        .ad_clk(ad_clk), .rd_data(rd_data),
        .ref_rd_data(ref_rd_data), .buf_full(buf_full), .otr_flag()
    );

    // ══════════════════════════════════════════════════════════
    //  ADC emulation
    // ══════════════════════════════════════════════════════════
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_phase_acc <= 0;
            ad_data_drv   <= 8'd128;
            ad_otr_drv    <= 1'b0;
        end else begin
            adc_phase_acc <= adc_phase_acc + f_word + 32'h01000000;
            if (ad_clk)
                ad_data_drv <= sin_lookup(adc_rom_addr)[9:2];
        end
    end

    // ══════════════════════════════════════════════════════════
    //  Test sequence
    // ══════════════════════════════════════════════════════════
    initial begin
        rst_n = 0; cycle_count = 0; f_word = FW_100KHZ;
        acq_start_reg = 0; rd_addr = 0; freq_step = 0;

        csv_fd = $fopen("ad_wave_rec_wave.csv", "w");
        $fdisplay(csv_fd, "time_ns,cycle,freq_step,freq_khz,smp_div,ad_clk,ad_data,ad_data_sync2,dds_wave,ram_wren,wr_addr,buf_full");

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════╗");
        $display("║  ADC Adaptive smp_div — Fast Verification            ║");
        $display("╠═══════════════════════════════════════════════════════╣");
        $display("║  Step  Freq     smp_div   sample rate                ║");
        $display("║  ──── ──────── ───────── ───────────                ║");
        $display("║   1    100 Hz     999      25 kSps                   ║");
        $display("║   2    1 kHz       99     250 kSps                   ║");
        $display("║   3    10 kHz       9     2.5 MSps                   ║");
        $display("║   4    100 kHz      0      25 MSps                   ║");
        $display("╚═══════════════════════════════════════════════════════╝\n");

        repeat (5) @(posedge clk); rst_n = 1;
        $display("[%8t] Reset released", $time);
        repeat (10) @(posedge clk);

        // ── Phase 1: sweep through 4 frequencies quickly ───
        $display("\n--- Phase 1: smp_div switching demo ---");

        f_word = FW_100HZ;  freq_step = 1;  repeat (50) @(posedge clk);
        $display("[%8t] f=100Hz  smp_div=%0d", $time, smp_div);

        f_word = FW_1KHZ;   freq_step = 2;  repeat (50) @(posedge clk);
        $display("[%8t] f=1kHz   smp_div=%0d", $time, smp_div);

        f_word = FW_10KHZ;  freq_step = 3;  repeat (50) @(posedge clk);
        $display("[%8t] f=10kHz  smp_div=%0d", $time, smp_div);

        f_word = FW_100KHZ; freq_step = 4;  repeat (50) @(posedge clk);
        $display("[%8t] f=100kHz smp_div=%0d", $time, smp_div);

        // ── Phase 2: one acquisition at 100kHz (smp_div=0) ───
        $display("\n--- Phase 2: acquisition @ 100kHz (smp_div=0) ---");
        acq_start_reg <= 1; @(posedge clk); acq_start_reg <= 0;
        $display("[%8t] acq_start pulsed", $time);

        fork
            begin wait(buf_full);
                $display("[%8t] buf_full — %0d samples captured", $time, SAMPLE_COUNT); end
            begin repeat(5000) @(posedge clk);
                $display("[%8t] TIMEOUT", $time); $finish; end
        join_any disable fork;

        // readback
        repeat (5) @(posedge clk);
        $display("[%8t] Readback first 8:", $time);
        for (k = 0; k < 8; k = k + 1) begin
            rd_addr <= k[9:0]; @(posedge clk); #1;
            $display("[%8t]   [%2d] ref=%3d  adc=%3d", $time, rd_addr, ref_rd_data, rd_data);
        end

        repeat (10) @(posedge clk);
        $display("\nDone.  cycles=%0d  time=%0t ns", cycle_count, $time);
        $fclose(csv_fd);
        $finish;
    end

    // ══════════════════════════════════════════════════════════
    //  CSV logger
    // ══════════════════════════════════════════════════════════
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%0d,%b,%0d,%0d,%0d,%b,%0d,%b",
                $time, cycle_count, freq_step,
                (f_word * 50) >> 32, smp_div,
                ad_clk, ad_data_drv, u_dut.ad_data_sync2,
                dds_wave, u_dut.ram_wren, u_dut.wr_addr, buf_full);
        end
    end

    // ══════════════════════════════════════════════════════════
    //  sine function
    // ══════════════════════════════════════════════════════════
    function [9:0] sin_lookup;
        input [9:0] a;
        begin sin_lookup = $rtoi(512.0 + 511.0 * $sin(2.0*3.1415926535*a/1024.0)); end
    endfunction

endmodule


// ══════════════════════════════════════════════════════════════
//  smp_div_adapt — maps f_word to smp_div (0/9/99/999)
// ══════════════════════════════════════════════════════════════
module smp_div_adapt (
    input  wire [31:0] f_word,
    output reg  [15:0] smp_div
);
    // thresholds per user spec:
    //   f_word ≥ 8589934 (≈100kHz) → smp_div=0,   rate=25MHz
    //   f_word ≥ 858993  (≈10kHz)  → smp_div=9,   rate=2.5MHz
    //   f_word ≥ 85899   (≈1kHz)   → smp_div=99,  rate=250kHz
    //   f_word < 85899   (<1kHz)   → smp_div=999, rate=25kHz
    localparam [31:0] TH_100K = 32'd8589934;
    localparam [31:0] TH_10K  = 32'd858993;
    localparam [31:0] TH_1K   = 32'd85899;

    always @(*) begin
        if      (f_word >= TH_100K) smp_div = 16'd0;
        else if (f_word >= TH_10K)  smp_div = 16'd9;
        else if (f_word >= TH_1K)   smp_div = 16'd99;
        else                        smp_div = 16'd999;
    end
endmodule
