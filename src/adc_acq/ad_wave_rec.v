module ad_wave_rec #(
    parameter integer SAMPLE_COUNT = 1024
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  ad_data,
    input  wire        ad_otr,
    input  wire [7:0]  ref_data_in,
    input  wire        acq_start,
    input  wire [15:0] smp_div,
    input  wire [9:0]  rd_addr,
    input  wire        rd_en,
    output wire        ad_clk,
    output wire [7:0]  rd_data,
    output wire [7:0]  ref_rd_data,
    output reg         buf_full,
    output reg         otr_flag
);

    reg [9:0]  wr_addr;
    reg        ram_wren;
    reg [7:0]  ad_data_sync1;
    reg [7:0]  ad_data_sync2;
    reg        ad_otr_sync1;
    reg        ad_otr_sync2;
    reg [7:0]  ad_data_reg;
    reg [7:0]  ref_data_reg;
    reg        ad_clk_reg;
    reg        acq_en;
    reg [15:0] smp_cnt;

    assign ad_clk = ad_clk_reg;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            ad_clk_reg <= 1'b0;
        else
            ad_clk_reg <= ~ad_clk_reg;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_addr       <= 10'd0;
            ram_wren      <= 1'b0;
            ad_data_sync1 <= 8'd0;
            ad_data_sync2 <= 8'd0;
            ad_otr_sync1  <= 1'b0;
            ad_otr_sync2  <= 1'b0;
            ad_data_reg   <= 8'd0;
            ref_data_reg  <= 8'd0;
            acq_en        <= 1'b0;
            buf_full      <= 1'b0;
            otr_flag      <= 1'b0;
            smp_cnt       <= 16'd0;
        end else begin
            // 2-stage synchronizer for external async ADC signals
            ad_data_sync1 <= ad_data;
            ad_data_sync2 <= ad_data_sync1;
            ad_otr_sync1  <= ad_otr;
            ad_otr_sync2  <= ad_otr_sync1;

            ram_wren <= 1'b0;

            if(acq_start) begin
                wr_addr  <= 10'd0;
                acq_en   <= 1'b1;
                buf_full <= 1'b0;
                otr_flag <= 1'b0;
                smp_cnt  <= 16'd0;
            end else if(acq_en && !buf_full && ad_clk_reg) begin
                ad_data_reg  <= ad_data_sync2;
                ref_data_reg <= ref_data_in;

                if(ad_otr_sync2)
                    otr_flag <= 1'b1;

                if(smp_cnt >= smp_div) begin
                    smp_cnt  <= 16'd0;
                    ram_wren <= 1'b1;
                    if(wr_addr == SAMPLE_COUNT-1) begin
                        acq_en   <= 1'b0;
                        buf_full <= 1'b1;
                    end else begin
                        wr_addr <= wr_addr + 10'd1;
                    end
                end else begin
                    smp_cnt <= smp_cnt + 16'd1;
                end
            end
        end
    end

    ADC_RAM u_response_ram(
        .data      (ad_data_reg),
        .rdaddress (rd_addr),
        .rdclock   (clk),
        .rden      (rd_en),
        .wraddress (wr_addr),
        .wrclock   (clk),
        .wren      (ram_wren),
        .q         (rd_data)
    );

    ADC_RAM u_reference_ram(
        .data      (ref_data_reg),
        .rdaddress (rd_addr),
        .rdclock   (clk),
        .rden      (rd_en),
        .wraddress (wr_addr),
        .wrclock   (clk),
        .wren      (ram_wren),
        .q         (ref_rd_data)
    );

endmodule
