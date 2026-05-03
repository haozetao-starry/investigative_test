module dds_phase(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        phase_clr,
    input  wire [31:0] f_word,
    output wire [9:0]  rom_addr
);

    reg [31:0] phase_acc;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            phase_acc <= 32'd0;
        else if(phase_clr)
            phase_acc <= 32'd0;
        else
            phase_acc <= phase_acc + f_word;
    end

    assign rom_addr = phase_acc[31:22];

endmodule
