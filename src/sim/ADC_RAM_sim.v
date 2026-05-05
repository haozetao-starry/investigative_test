// Behavioral dual-port RAM model for simulation
// Replaces Altera altsyncram-based ADC_RAM.v — no Quartus libraries needed.
// 1024 words x 8 bits, simple write / registered read.
`timescale 1ns/1ps

module ADC_RAM (
    input  wire [7:0]   data,
    input  wire [9:0]   rdaddress,
    input  wire         rdclock,
    input  wire         rden,
    input  wire [9:0]   wraddress,
    input  wire         wrclock,
    input  wire         wren,
    output reg  [7:0]   q
);

    reg [7:0] mem [0:1023];

    always @(posedge wrclock) begin
        if (wren)
            mem[wraddress] <= data;
    end

    always @(posedge rdclock) begin
        if (rden)
            q <= mem[rdaddress];
    end

endmodule
