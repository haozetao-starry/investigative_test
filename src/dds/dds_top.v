module dds_top(
    input                 clk,
    input                 rst_n,
    input                 phase_clr,
    input        [31:0]   f_word,
    input        [8:0]    a_word,
    output       [7:0]    wave_out
);

    wire [9:0] rom_addr;
    wire [9:0] sin_q_raw;
    wire [7:0] wave_raw;

    dds_phase u_dds_phase(
        .clk       (clk),
        .rst_n     (rst_n),
        .phase_clr (phase_clr),
        .f_word    (f_word),
        .rom_addr  (rom_addr)
    );

    sin u_sin (
        .address (rom_addr),
        .clock   (clk),
        .q       (sin_q_raw)
    );

    // The ROM stores 10-bit unsigned sine data centered at 512.
    // Keeping the upper 8 bits preserves the sinusoidal shape and 128 midpoint.
    assign wave_raw = sin_q_raw[9:2];

    dds_amp u_dds_amp(
        .clk      (clk),
        .rst_n    (rst_n),
        .wave_in  (wave_raw),
        .a_word   (a_word),
        .wave_out (wave_out)
    );

endmodule
