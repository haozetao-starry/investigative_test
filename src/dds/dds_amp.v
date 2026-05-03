module dds_amp(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  wave_in,
    input  wire [8:0]  a_word,
    output reg  [7:0]  wave_out
);

    wire signed [8:0]  wave_signed = {1'b0, wave_in} - 9'sd128;
    // a_word is 9-bit (0-511), full-scale = 511 ≈ divide by 512
    // mult_result[17:9] = product / 512, correct amplitude scaling
    wire signed [18:0] mult_result = wave_signed * $signed({1'b0, a_word});
    wire signed [9:0]  scaled_wave = $signed(mult_result[17:9]) + 10'sd128;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            wave_out <= 8'd128;
        else if(scaled_wave < 0)
            wave_out <= 8'd0;
        else if(scaled_wave > 10'sd255)
            wave_out <= 8'd255;
        else
            wave_out <= scaled_wave[7:0];
    end

endmodule
