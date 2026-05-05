`timescale 1ns/1ps

module dds_sweep_tb;

    reg clk;
    reg rst_n;

    localparam integer DDS_A_WORD_WIDTH = 9;
    localparam integer CLK_HALF_NS      = 10;             // 50 MHz clock
    localparam integer MAX_SIM_CYCLES   = 20000;          // timeout

    // ── sweep parameters (match uut_ctrl) ────────────────────
    localparam integer CLK_FREQ_HZ      = 50000000;
    localparam integer START_FREQ_HZ    = 1000000;
    localparam integer STOP_FREQ_HZ     = 4000000;
    localparam integer STEP_FREQ_HZ     = 1000000;
    localparam integer STEP_PERIOD_CLKS = 500;            // 每段500个时钟, 1MHz下可见10个完整正弦周期

    // ── DUT wires ────────────────────────────────────────────
    wire [31:0] f_word;
    wire        phase_clr;
    wire        step_sync;
    wire        sweep_busy;
    wire        sweep_done;
    wire [7:0]  wave_out;
    wire [DDS_A_WORD_WIDTH-1:0] amp_word;

    // ── thesis display signals ───────────────────────────────
    reg  [7:0]  freq_step;          // 频率档位号 (1,2,3,4...), 波形窗口可显示

    // ── book‑keeping ─────────────────────────────────────────
    integer     cycle_count;
    integer     step_count;
    integer     csv_fd;
    real        freq_hz_approx;

    assign amp_word = 9'd256;       // 50% 幅度

    // ── helper: f_word → approximate Hz for display ──────────
    function real fword_to_hz;
        input [31:0] fw;
        reg   [63:0] tmp;
        begin
            tmp = {32'd0, fw};
            fword_to_hz = (tmp * CLK_FREQ_HZ) / (64'd1 << 32);
        end
    endfunction

    // ══════════════════════════════════════════════════════════
    //  Clock
    // ══════════════════════════════════════════════════════════
    initial begin
        clk = 1'b0;
        forever #(CLK_HALF_NS) clk = ~clk;
    end

    // ══════════════════════════════════════════════════════════
    //  VCD dump
    // ══════════════════════════════════════════════════════════
    initial begin
        $dumpfile("dds_sweep_tb.vcd");
        $dumpvars(0, dds_sweep_tb);
    end

    // ══════════════════════════════════════════════════════════
    //  DUT
    // ══════════════════════════════════════════════════════════
    dds_sweep_ctrl #(
        .CLK_FREQ_HZ           (CLK_FREQ_HZ),
        .START_FREQ_HZ         (START_FREQ_HZ),
        .STOP_FREQ_HZ          (STOP_FREQ_HZ),
        .STEP_FREQ_HZ          (STEP_FREQ_HZ),
        .STEP_PERIOD_CLKS      (STEP_PERIOD_CLKS),
        .REPEAT_SWEEP          (0),
        .RESET_PHASE_EACH_STEP (1)
    ) uut_ctrl (
        .clk        (clk),
        .rst_n      (rst_n),
        .sweep_en   (1'b1),
        .restart    (1'b0),
        .f_word     (f_word),
        .phase_clr  (phase_clr),
        .step_sync  (step_sync),
        .sweep_busy (sweep_busy),
        .sweep_done (sweep_done)
    );

    dds_top uut_dds (
        .clk       (clk),
        .rst_n     (rst_n),
        .phase_clr (phase_clr),
        .f_word    (f_word),
        .a_word    (amp_word),
        .wave_out  (wave_out)
    );

    // ══════════════════════════════════════════════════════════
    //  Test sequence
    // ══════════════════════════════════════════════════════════
    initial begin
        rst_n       = 1'b0;
        cycle_count = 0;
        step_count  = 0;
        freq_step   = 0;

        csv_fd = $fopen("dds_sweep_wave.csv", "w");
        $fdisplay(csv_fd, "time_ns,cycle,freq_step,f_word_hex,freq_hz,wave_out,step_sync");

        $display("\n");
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║       DDS  Sweep  Testbench (Thesis Edition)          ║");
        $display("╠════════════════════════════════════════════════════════╣");
        $display("║  Clock        : %0d MHz                               ║", CLK_FREQ_HZ / 1_000_000);
        $display("║  Sweep range  : %0d → %0d Hz                          ║", START_FREQ_HZ, STOP_FREQ_HZ);
        $display("║  Step size    : %0d Hz                                ║", STEP_FREQ_HZ);
        $display("║  Dwell        : %0d clocks (%.1f us per step)         ║",
                 STEP_PERIOD_CLKS, STEP_PERIOD_CLKS * CLK_HALF_NS * 2.0 / 1000.0);
        $display("║  Phase reset  : each step                             ║");
        $display("╚════════════════════════════════════════════════════════╝");
        $display("\n");

        // ── reset ────────────────────────────────────────────
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        $display("[%8t ns] > Reset released", $time);

        // ── wait for sweep_done (with timeout) ───────────────
        fork
            begin
                wait (sweep_done);
                $display("[%8t ns] > sweep_done asserted", $time);
            end
            begin
                repeat (MAX_SIM_CYCLES) @(posedge clk);
                $display("[%8t ns] *** TIMEOUT — sweep_done did not assert within %0d cycles",
                         $time, MAX_SIM_CYCLES);
                $fclose(csv_fd);
                $finish;
            end
        join_any
        disable fork;

        // ── observe a few extra cycles after sweep finishes ──
        repeat (100) @(posedge clk);

        // ── summary ──────────────────────────────────────────
        $display("\n");
        $display("╔════════════════════════════════════════════════════════╗");
        $display("║  Simulation finished                                  ║");
        $display("╠════════════════════════════════════════════════════════╣");
        $display("║  Total cycles   : %-5d                                ║", cycle_count);
        $display("║  Total steps    : %-5d                                ║", step_count);
        $display("║  Sim time       : %-8t ns                             ║", $time);
        $display("║  CSV saved to   : dds_sweep_wave.csv                  ║");
        $display("║  VCD saved to   : dds_sweep_tb.vcd                    ║");
        $display("║  Plot script    : python plot_dds_sweep.py             ║");
        $display("╚════════════════════════════════════════════════════════╝");
        $display("\n");

        $fclose(csv_fd);
        $finish;
    end

    // ══════════════════════════════════════════════════════════
    //  freq_step tracking — increments at each step_sync
    // ══════════════════════════════════════════════════════════
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            freq_step <= 8'd0;
        else if (step_sync)
            freq_step <= freq_step + 8'd1;
    end

    // ══════════════════════════════════════════════════════════
    //  Cycle counter, CSV logger, console reporter
    // ══════════════════════════════════════════════════════════
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            freq_hz_approx = fword_to_hz(f_word);

            // ── CSV: one row per cycle ───────────────────────
            $fdisplay(csv_fd, "%0d,%0d,%0d,0x%08h,%0.0f,%0d,%b",
                      $time, cycle_count, freq_step, f_word,
                      freq_hz_approx, wave_out, step_sync);

            // ── console: step boundary ───────────────────────
            if (step_sync) begin
                step_count <= step_count + 1;
                $display("[%8t ns] ------------------------------", $time);
                $display("[%8t ns]  STEP %0d  f = %.1f MHz  f_word = 0x%08h",
                         $time, freq_step + 1, freq_hz_approx / 1e6, f_word);
            end
        end
    end

endmodule
