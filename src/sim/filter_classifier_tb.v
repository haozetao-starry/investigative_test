`timescale 1ns/1ps

module filter_classifier_tb;

    reg clk;
    reg rst_n;

    localparam integer CLK_HALF_NS    = 10;          // 50 MHz
    localparam integer NUM_POINTS     = 100;         // sweep points per test
    localparam integer MAX_SIM_CYCLES = 50000;

    // ── DUT signals ──────────────────────────────────────
    reg         classify_start;
    wire        classifier_done;
    wire [2:0]  filter_type;
    wire [6:0]  cls_read_index;
    wire [31:0] cls_read_h_mag_q16;
    wire [15:0] cls_read_h_phase_deg_q8;
    wire        cls_read_valid;

    // ── sweep_result_store signals ────────────────────────
    reg         store_clear;
    reg         store_write_en;
    reg  [31:0] store_freq_word;
    reg  [9:0]  store_peak_bin;
    reg  [31:0] store_h_mag_q16;
    reg  [15:0] store_h_phase_deg_q8;
    wire [6:0]  store_result_count;

    // ── book-keeping ──────────────────────────────────────
    integer     cycle_count, csv_fd, i;
    reg  [2:0]  test_case;
    reg  [2:0]  expected_type;
    reg  [7:0]  write_idx;
    reg  [31:0] expected_types [0:5];
    reg  [31:0] actual_types   [0:5];
    integer     pass_count, fail_count;

    // ── helper: compute test magnitude ────────────────────
    function [31:0] make_mag;
        input integer idx;
        input [2:0] tcase;
        real center, val, slope;
        begin
            case (tcase)
                3'd0: begin  // ALLPASS: ~1.0 with tiny ripple
                    // ripple ±0.8% ensures max>min but flat_span small
                    val = 1.0 + 0.008 * $sin(idx * 0.25);
                end
                3'd1: begin  // LOWPASS: 1.0 → 0.05 (steep drop)
                    val = 1.0 - 0.95 * idx / (NUM_POINTS - 1.0);
                end
                3'd2: begin  // HIGHPASS: 0.05 → 1.0 (steep rise)
                    val = 0.05 + 0.95 * idx / (NUM_POINTS - 1.0);
                end
                3'd3: begin  // BANDPASS: asymmetric bell at center
                    // slight slope on tails so edge_gap ≠ 0
                    center = NUM_POINTS / 2.0;
                    slope  = 0.08 * idx / (NUM_POINTS - 1.0);  // rising baseline
                    val = 0.08 + slope + 0.92 * $exp(-((idx - center) * (idx - center)) / 200.0);
                end
                3'd4: begin  // NOTCH: asymmetric inverted bell at center
                    center = NUM_POINTS / 2.0;
                    slope  = 0.10 * (1.0 - idx / (NUM_POINTS - 1.0));  // falling baseline
                    val = 0.85 + slope - 0.70 * $exp(-((idx - center) * (idx - center)) / 300.0);
                end
                3'd5: begin  // UNKNOWN: zigzag with multiple peaks&valleys
                    // irregular saw-like pattern that evades all specific rules
                    val = 0.35 + 0.30 * $sin(idx * 0.35)
                                + 0.18 * $sin(idx * 0.13)
                                + 0.12 * $sin(idx * 0.07);
                end
                default: val = 0.5;
            endcase
            make_mag = $rtoi(val * 65536.0);  // Q16
        end
    endfunction

    // ══════════════════════════════════════════════════════
    //  Clock
    // ══════════════════════════════════════════════════════
    initial begin
        clk = 1'b0;
        forever #(CLK_HALF_NS) clk = ~clk;
    end

    // ══════════════════════════════════════════════════════
    //  VCD dump
    // ══════════════════════════════════════════════════════
    initial begin
        $dumpfile("filter_classifier_tb.vcd");
        $dumpvars(0, filter_classifier_tb);
    end

    // ══════════════════════════════════════════════════════
    //  DUTs
    // ══════════════════════════════════════════════════════
    sweep_result_store #(.MAX_RESULTS(128)) u_store (
        .clk              (clk),
        .rst_n            (rst_n),
        .clear            (store_clear),
        .write_en         (store_write_en),
        .freq_word        (store_freq_word),
        .peak_bin         (store_peak_bin),
        .h_mag_q16        (store_h_mag_q16),
        .h_phase_deg_q8   (store_h_phase_deg_q8),
        .read_index       (cls_read_index),
        .read_freq_word   (),
        .read_peak_bin    (),
        .read_h_mag_q16   (cls_read_h_mag_q16),
        .read_h_phase_deg_q8 (cls_read_h_phase_deg_q8),
        .read_valid       (cls_read_valid),
        .result_count     (store_result_count)
    );

    filter_classifier u_classifier (
        .clk                (clk),
        .rst_n              (rst_n),
        .start              (classify_start),
        .result_count       (store_result_count),
        .read_index         (cls_read_index),
        .read_h_mag_q16     (cls_read_h_mag_q16),
        .read_h_phase_deg_q8(cls_read_h_phase_deg_q8),
        .read_valid         (cls_read_valid),
        .done               (classifier_done),
        .filter_type        (filter_type)
    );

    // type name lookup
    function [63:0] type_name;
        input [2:0] t;
        begin
            case (t)
                3'd0: type_name = "UNKNOWN ";
                3'd1: type_name = "LOWPASS ";
                3'd2: type_name = "HIGHPASS";
                3'd3: type_name = "BANDPASS";
                3'd4: type_name = "NOTCH   ";
                3'd5: type_name = "ALLPASS ";
                default: type_name = "???     ";
            endcase
        end
    endfunction

    // ══════════════════════════════════════════════════════
    //  Test sequence
    // ══════════════════════════════════════════════════════
    initial begin
        rst_n          = 1'b0;
        classify_start = 1'b0;
        store_clear    = 1'b0;
        store_write_en = 1'b0;
        store_freq_word= 32'd0;
        store_peak_bin = 10'd0;
        store_h_mag_q16= 32'd0;
        store_h_phase_deg_q8 = 16'd0;
        cycle_count    = 0;
        test_case      = 3'd0;
        pass_count     = 0;
        fail_count     = 0;
        write_idx      = 0;

        csv_fd = $fopen("filter_classifier_wave.csv", "w");
        $fdisplay(csv_fd, "time_ns,cycle,test_case,filter_type,classifier_done");

        $display("\n");
        $display("╔══════════════════════════════════════════════════════════╗");
        $display("║   Filter Classifier — 6-Type Verification Testbench     ║");
        $display("╠══════════════════════════════════════════════════════════╣");
        $display("║  Test cases: ALLPASS LOWPASS HIGHPASS BANDPASS NOTCH    ║");
        $display("║              UNKNOWN (total 6)                          ║");
        $display("║  Sweep points per test: %0d                             ║", NUM_POINTS);
        $display("╚══════════════════════════════════════════════════════════╝");
        $display("\n");

        // ── Reset ─────────────────────────────────────────
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        $display("[%8t ns] Reset released", $time);
        repeat (5) @(posedge clk);

        // ── Run 6 test cases ──────────────────────────────
        for (test_case = 0; test_case < 6; test_case = test_case + 1) begin
            case (test_case)
                3'd0: expected_type = 3'd5;  // ALLPASS → 5
                3'd1: expected_type = 3'd1;  // LOWPASS → 1
                3'd2: expected_type = 3'd2;  // HIGHPASS → 2
                3'd3: expected_type = 3'd3;  // BANDPASS → 3
                3'd4: expected_type = 3'd4;  // NOTCH → 4
                3'd5: expected_type = 3'd0;  // UNKNOWN → 0
            endcase

            $display("\n[%8t ns] ═══ Test %0d: %0s (expected type=%0d) ═══",
                     $time, test_case + 1, type_name(expected_type), expected_type);

            // Clear store
            store_clear <= 1'b1; @(posedge clk); store_clear <= 1'b0;
            @(posedge clk);

            // Write NUM_POINTS entries
            for (write_idx = 0; write_idx < NUM_POINTS; write_idx = write_idx + 1) begin
                store_freq_word <= write_idx;
                store_peak_bin  <= write_idx[9:0];
                store_h_mag_q16 <= make_mag(write_idx, test_case);
                store_h_phase_deg_q8 <= 16'd0;
                store_write_en  <= 1'b1;
                @(posedge clk);
                store_write_en  <= 1'b0;
                @(posedge clk);
            end

            $display("[%8t ns]   Wrote %0d entries, result_count=%0d",
                     $time, NUM_POINTS, store_result_count);

            // Start classification
            classify_start <= 1'b1; @(posedge clk); classify_start <= 1'b0;
            $display("[%8t ns]   classify_start pulsed", $time);

            // Wait for done with timeout
            fork
                begin
                    wait (classifier_done);
                    $display("[%8t ns]   classifier_done — filter_type=%0d (%0s)",
                             $time, filter_type, type_name(filter_type));
                end
                begin
                    repeat (MAX_SIM_CYCLES) @(posedge clk);
                    $display("[%8t ns]   *** TIMEOUT", $time);
                    $fclose(csv_fd); $finish;
                end
            join_any
            disable fork;

            // Verify
            actual_types[test_case] = filter_type;
            if (filter_type == expected_type) begin
                $display("[%8t ns]   >>> PASS: got %0s as expected", $time, type_name(filter_type));
                pass_count = pass_count + 1;
            end else begin
                $display("[%8t ns]   >>> FAIL: got %0s, expected %0s",
                         $time, type_name(filter_type), type_name(expected_type));
                fail_count = fail_count + 1;
            end

            repeat (10) @(posedge clk);
        end

        // ── Summary ────────────────────────────────────────
        $display("\n");
        $display("╔══════════════════════════════════════════════════════════╗");
        $display("║                  Simulation Summary                     ║");
        $display("╠══════════════════════════════════════════════════════════╣");
        $display("║  Test case   Expected     Actual       Result           ║");
        $display("║  ─────────   ────────     ──────       ──────           ║");
        for (i = 0; i < 6; i = i + 1) begin
            $display("║  %0s      %0s       %0s         %0s              ║",
                     type_name(i[2:0]), type_name(test_case_map(i[2:0])),
                     type_name(actual_types[i]),
                     (actual_types[i] == test_case_map(i[2:0])) ? "PASS" : "FAIL");
        end
        $display("╠══════════════════════════════════════════════════════════╣");
        $display("║  PASS: %0d / 6    FAIL: %0d / 6                          ║", pass_count, fail_count);
        $display("║  Cycles: %0d   Time: %0t ns                              ║", cycle_count, $time);
        $display("╚══════════════════════════════════════════════════════════╝");
        $display("\n");

        $fclose(csv_fd);
        $finish;
    end

    // map test index to expected type
    function [2:0] test_case_map;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: test_case_map = 3'd5;  // ALLPASS
                3'd1: test_case_map = 3'd1;  // LOWPASS
                3'd2: test_case_map = 3'd2;  // HIGHPASS
                3'd3: test_case_map = 3'd3;  // BANDPASS
                3'd4: test_case_map = 3'd4;  // NOTCH
                3'd5: test_case_map = 3'd0;  // UNKNOWN
                default: test_case_map = 3'd0;
            endcase
        end
    endfunction

    // ══════════════════════════════════════════════════════
    //  Cycle counter + CSV logger
    // ══════════════════════════════════════════════════════
    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count <= cycle_count + 1;
            $fdisplay(csv_fd, "%0d,%0d,%0d,%0d,%b",
                      $time, cycle_count, test_case, filter_type, classifier_done);
        end
    end

endmodule
