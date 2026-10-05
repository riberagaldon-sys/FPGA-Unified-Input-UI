`timescale 1ns/1ps

module mouse_event_mapper(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              packet_valid,
    input  wire [2:0]        buttons,
    input  wire signed [8:0] dx,
    input  wire signed [8:0] dy,

    output reg               left_press,
    output reg               right_press,
    output reg               middle_press
);

    reg [2:0] buttons_d;

    wire mouse_stationary;

    assign mouse_stationary =
        (dx == 9'sd0) &&
        (dy == 9'sd0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buttons_d    <= 3'b000;
            left_press   <= 1'b0;
            right_press  <= 1'b0;
            middle_press <= 1'b0;
        end
        else begin
            left_press   <= 1'b0;
            right_press  <= 1'b0;
            middle_press <= 1'b0;

            if (packet_valid) begin
                // 无位移的数据包才允许产生按键事件，
                // 避免鼠标移动数据误触发页面进入或返回。
                if (mouse_stationary) begin
                    left_press <=
                        buttons[0] && !buttons_d[0];

                    right_press <=
                        buttons[1] && !buttons_d[1];

                    middle_press <=
                        buttons[2] && !buttons_d[2];
                end

                // 无论是否移动，都记录真实按键状态，
                // 防止释放状态丢失。
                buttons_d <= buttons;
            end
        end
    end

endmodule