// Behavioral sine ROM model for simulation
// Replaces Altera altsyncram-based sin.v — no Quartus libraries needed.
// 10-bit address, 10-bit signed sine output centered around 512.
`timescale 1ns/1ps

module sin (
    input  wire [9:0]  address,
    input  wire        clock,
    output reg  [9:0]  q
);

    reg [9:0] sine_table [0:1023];

    integer i;
    real    phase;
    real    val;

    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            phase = 2.0 * 3.141592653589793 * i / 1024.0;
            val   = 512.0 + 511.0 * $sin(phase);
            sine_table[i] = $rtoi(val);
        end
    end

    always @(posedge clock) begin
        q <= sine_table[address];
    end

endmodule
