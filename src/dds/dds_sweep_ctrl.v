module dds_sweep_ctrl #(
    parameter integer CLK_FREQ_HZ           = 50000000,
    parameter integer START_FREQ_HZ         = 100,
    parameter integer STOP_FREQ_HZ          = 10000,
    parameter integer STEP_FREQ_HZ          = 100,
    parameter integer STEP_PERIOD_CLKS      = 50000,
    parameter integer REPEAT_SWEEP          = 1,
    parameter integer RESET_PHASE_EACH_STEP = 1
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sweep_en,
    input  wire        restart,
    output reg  [31:0] f_word,
    output reg         phase_clr,
    output reg         step_sync,
    output reg         sweep_busy,
    output reg         sweep_done
);

    function [31:0] hz_to_fword;
        input integer freq_hz;
        reg   [63:0] numerator;
        begin
            numerator   = freq_hz;
            numerator   = numerator << 32;
            hz_to_fword = numerator / CLK_FREQ_HZ;
        end
    endfunction

    localparam [31:0] START_WORD = hz_to_fword(START_FREQ_HZ);
    localparam [31:0] STOP_WORD  = hz_to_fword(STOP_FREQ_HZ);
    localparam [31:0] STEP_WORD  = hz_to_fword(STEP_FREQ_HZ);
    localparam        SWEEP_UP   = (STOP_WORD >= START_WORD);
    localparam integer SAFE_STEP_PERIOD_CLKS = (STEP_PERIOD_CLKS > 0) ? STEP_PERIOD_CLKS : 1;

    reg [31:0] dwell_cnt;


    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            f_word     <= START_WORD;
            phase_clr  <= 1'b0;
            step_sync  <= 1'b0;
            sweep_busy <= 1'b0;
            sweep_done <= 1'b0;
            dwell_cnt  <= 32'd0;
        end else begin
            phase_clr <= 1'b0;
            step_sync <= 1'b0;
            sweep_done <= 1'b0;

            if(restart) begin
                f_word     <= START_WORD;
                dwell_cnt  <= 32'd0;
                sweep_busy <= sweep_en;
                phase_clr  <= 1'b1;
                step_sync  <= 1'b1;
            end else if(sweep_en) begin
                sweep_busy <= 1'b1;

                if(dwell_cnt >= (SAFE_STEP_PERIOD_CLKS - 1)) begin
                    dwell_cnt <= 32'd0;
                    step_sync <= 1'b1;
                    if(RESET_PHASE_EACH_STEP != 0)
                        phase_clr <= 1'b1;

                    if(STEP_WORD == 0) begin
                        sweep_done <= 1'b1;
                        if(REPEAT_SWEEP != 0) begin
                            f_word <= START_WORD;
                        end else begin
                            f_word <= START_WORD;
                            sweep_busy <= 1'b0;
                        end
                    end else begin
                        if(SWEEP_UP) begin
                            if(f_word >= STOP_WORD) begin
                                sweep_done <= 1'b1;
                                if(REPEAT_SWEEP != 0) begin
                                    f_word <= START_WORD;
                                end else begin
                                    f_word <= STOP_WORD;
                                    sweep_busy <= 1'b0;
                                end
                            end else if((f_word + STEP_WORD) >= STOP_WORD) begin
                                f_word <= STOP_WORD;
                            end else begin
                                f_word <= f_word + STEP_WORD;
                            end
                        end else begin
                            if(f_word <= STOP_WORD) begin
                                sweep_done <= 1'b1;
                                if(REPEAT_SWEEP != 0) begin
                                    f_word <= START_WORD;
                                end else begin
                                    f_word <= STOP_WORD;
                                    sweep_busy <= 1'b0;
                                end
                            end else if(f_word <= (STOP_WORD + STEP_WORD)) begin
                                f_word <= STOP_WORD;
                            end else begin
                                f_word <= f_word - STEP_WORD;
                            end
                        end
                    end
                end else begin
                    dwell_cnt <= dwell_cnt + 32'd1;
                end
            end else begin
                f_word     <= START_WORD;
                dwell_cnt  <= 32'd0;
                sweep_busy <= 1'b0;
            end
        end
    end

endmodule
