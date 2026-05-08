module sweep_result_store #(
    parameter integer MAX_RESULTS = 128
)(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              clear,
    input  wire              write_en,
    input  wire [31:0]       freq_word,
    input  wire [9:0]        peak_bin,
    input  wire [31:0]       h_mag_q16,
    input  wire signed [15:0] h_phase_deg_q8,
    input  wire [6:0]        read_index,
    output reg  [31:0]       read_freq_word,
    output reg  [9:0]        read_peak_bin,
    output reg  [31:0]       read_h_mag_q16,
    output reg  signed [15:0] read_h_phase_deg_q8,
    output reg               read_valid,
    output reg  [6:0]        result_count
);

    reg [31:0]        freq_word_mem [0:MAX_RESULTS-1];
    reg [9:0]         peak_bin_mem  [0:MAX_RESULTS-1];
    reg [31:0]        h_mag_mem     [0:MAX_RESULTS-1];
    reg signed [15:0] h_phase_mem   [0:MAX_RESULTS-1];

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            result_count <= 7'd0;
        end else if(clear) begin
            result_count <= 7'd0;
        end else if(write_en && (result_count < MAX_RESULTS)) begin
            freq_word_mem[result_count] <= freq_word;
            peak_bin_mem[result_count]  <= peak_bin;
            h_mag_mem[result_count]     <= h_mag_q16;
            h_phase_mem[result_count]   <= h_phase_deg_q8;
            result_count                <= result_count + 7'd1;
        end
    end

    always @(*) begin
        if(read_index < result_count) begin
            read_freq_word       = freq_word_mem[read_index];
            read_peak_bin        = peak_bin_mem[read_index];
            read_h_mag_q16       = h_mag_mem[read_index];
            read_h_phase_deg_q8  = h_phase_mem[read_index];
            read_valid           = 1'b1;
        end else begin
            read_freq_word       = 32'd0;
            read_peak_bin        = 10'd0;
            read_h_mag_q16       = 32'd0;
            read_h_phase_deg_q8  = 16'sd0;
            read_valid           = 1'b0;
        end
    end

endmodule
