module filter_classifier(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              start,
    input  wire [6:0]        result_count,
    output reg  [6:0]        read_index,
    input  wire [31:0]       read_h_mag_q16,
    input  wire signed [15:0] read_h_phase_deg_q8,
    input  wire              read_valid,
    output reg               done,
    output reg  [2:0]        filter_type
);

    localparam [2:0] TYPE_UNKNOWN  = 3'd0;
    localparam [2:0] TYPE_LOWPASS  = 3'd1;
    localparam [2:0] TYPE_HIGHPASS = 3'd2;
    localparam [2:0] TYPE_BANDPASS = 3'd3;
    localparam [2:0] TYPE_NOTCH    = 3'd4;
    localparam [2:0] TYPE_ALLPASS  = 3'd5;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_SCAN       = 3'd1;
    localparam [2:0] ST_CLASSIFY   = 3'd2;

    reg [2:0] state;
    reg [6:0] scan_index;
    reg [31:0] first_mag;
    reg [31:0] last_mag;
    reg [31:0] max_mag;
    reg [31:0] min_mag;
    reg [6:0]  max_idx;
    reg [6:0]  min_idx;

    wire [6:0] last_index;
    wire [6:0] edge_zone;
    wire [31:0] edge_avg;
    wire [31:0] flat_span;
    wire [31:0] edge_gap;
    wire [31:0] edge_margin;
    wire [31:0] peak_margin;
    wire [31:0] trough_margin;
    wire        peak_is_center;
    wire        trough_is_center;

    assign last_index = (result_count == 0) ? 7'd0 : (result_count - 7'd1);
    assign edge_zone = (result_count >> 3);
    assign edge_avg = (first_mag + last_mag) >> 1;
    assign flat_span = (max_mag >= min_mag) ? (max_mag - min_mag) : 32'd0;
    assign edge_gap = (first_mag >= last_mag) ? (first_mag - last_mag) : (last_mag - first_mag);
    assign edge_margin = (edge_avg >> 4) + 32'd1;
    assign peak_margin = (edge_avg >> 3) + 32'd1;
    assign trough_margin = (edge_avg >> 3) + 32'd1;
    assign peak_is_center = (max_idx > edge_zone) && (max_idx < (last_index - edge_zone));
    assign trough_is_center = (min_idx > edge_zone) && (min_idx < (last_index - edge_zone));

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state       <= ST_IDLE;
            read_index  <= 7'd0;
            done        <= 1'b0;
            filter_type <= TYPE_UNKNOWN;
            scan_index  <= 7'd0;
            first_mag   <= 32'd0;
            last_mag    <= 32'd0;
            max_mag     <= 32'd0;
            min_mag     <= 32'd0;
            max_idx     <= 7'd0;
            min_idx     <= 7'd0;
        end else begin
            done <= 1'b0;

            case(state)
                ST_IDLE: begin
                    if(start) begin
                        if(result_count < 7'd3) begin
                            filter_type <= TYPE_UNKNOWN;
                            done        <= 1'b1;
                            state       <= ST_IDLE;
                        end else begin
                            scan_index  <= 7'd0;
                            read_index  <= 7'd0;
                            first_mag   <= 32'd0;
                            last_mag    <= 32'd0;
                            max_mag     <= 32'd0;
                            min_mag     <= 32'hFFFFFFFF;
                            max_idx     <= 7'd0;
                            min_idx     <= 7'd0;
                            state       <= ST_SCAN;
                        end
                    end
                end

                ST_SCAN: begin
                    if(read_valid) begin
                        if(scan_index == 7'd0)
                            first_mag <= read_h_mag_q16;

                        if(scan_index == last_index)
                            last_mag <= read_h_mag_q16;

                        if(read_h_mag_q16 > max_mag) begin
                            max_mag <= read_h_mag_q16;
                            max_idx <= scan_index;
                        end

                        if(read_h_mag_q16 < min_mag) begin
                            min_mag <= read_h_mag_q16;
                            min_idx <= scan_index;
                        end

                        if(scan_index == last_index) begin
                            state <= ST_CLASSIFY;
                        end else begin
                            scan_index <= scan_index + 7'd1;
                            read_index <= scan_index + 7'd1;
                        end
                    end
                end

                ST_CLASSIFY: begin
                    if((max_mag <= min_mag) || (result_count < 7'd3)) begin
                        filter_type <= TYPE_UNKNOWN;
                    end else if((flat_span <= edge_margin) || (edge_gap <= edge_margin)) begin
                        filter_type <= TYPE_ALLPASS;
                    end else if(peak_is_center &&
                                (max_mag >= (edge_avg + peak_margin)) &&
                                (first_mag + peak_margin <= max_mag) &&
                                (last_mag + peak_margin <= max_mag)) begin
                        filter_type <= TYPE_BANDPASS;
                    end else if(trough_is_center &&
                                (min_mag + trough_margin <= edge_avg) &&
                                (first_mag >= min_mag + trough_margin) &&
                                (last_mag >= min_mag + trough_margin)) begin
                        filter_type <= TYPE_NOTCH;
                    end else if(first_mag >= (last_mag + edge_margin)) begin
                        filter_type <= TYPE_LOWPASS;
                    end else if(last_mag >= (first_mag + edge_margin)) begin
                        filter_type <= TYPE_HIGHPASS;
                    end else begin
                        filter_type <= TYPE_UNKNOWN;
                    end
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
