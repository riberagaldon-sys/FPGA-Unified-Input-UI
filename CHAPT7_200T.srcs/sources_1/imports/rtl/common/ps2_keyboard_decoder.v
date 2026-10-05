`timescale 1ns/1ps

module ps2_keyboard_decoder(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] scan_code,
    input  wire       scan_valid,
    output reg        key_press,
    output reg        key_release,
    output reg  [7:0] key_code,
    output reg        extended
);

    reg break_pending;
    reg extend_pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            break_pending  <= 1'b0;
            extend_pending <= 1'b0;
            key_press      <= 1'b0;
            key_release    <= 1'b0;
            key_code       <= 8'd0;
            extended       <= 1'b0;
        end
        else begin
            key_press   <= 1'b0;
            key_release <= 1'b0;

            if (scan_valid) begin
                if (scan_code == 8'hE0) begin
                    extend_pending <= 1'b1;
                end
                else if (scan_code == 8'hF0) begin
                    break_pending <= 1'b1;
                end
                else if (scan_code == 8'hE1) begin
                    // Pause/Break使用特殊多字节序列。
                    // 原版本只忽略E1前缀。
                    break_pending  <= 1'b0;
                    extend_pending <= 1'b0;
                end
                else begin
                    key_code <= scan_code;
                    extended <= extend_pending;

                    if (break_pending)
                        key_release <= 1'b1;
                    else
                        key_press <= 1'b1;

                    break_pending  <= 1'b0;
                    extend_pending <= 1'b0;
                end
            end
        end
    end

endmodule