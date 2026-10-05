`timescale 1ns/1ps

module top_chapter7_ui #(
    parameter integer CLK_HZ          = 50_000_000,
    parameter integer POR_BITS        = 21,
    parameter integer PS2_DEVICE_MODE = 0
)(
    input  wire sys_clk,

    input  wire S1_KEYA,
    input  wire S1_KEYB,
    input  wire S1_KEYC,
    input  wire S1_KEYD,
    input  wire S1_KEYP,

    input  wire EC_A,
    input  wire EC_B,
    input  wire EC_KEY,

    inout  wire PS2_CLK,
    inout  wire PS2_DATA,

    output wire TOUCH_SCL,
    inout  wire TOUCH_SDA,
    inout  wire TOUCH_INT,
    output wire TOUCH_RST,

    output wire [7:0] LCD_R,
    output wire [7:0] LCD_G,
    output wire [7:0] LCD_B,
    output wire       LCD_CLK,
    output wire       LCD_HSYNC,
    output wire       LCD_VSYNC,
    output wire       LCD_DE,
    output wire       LCD_BL,
    output wire       LCD_nRST
);

    // ============================================================
    // Power-on reset
    // ============================================================

    wire rst_n;

    por_reset #(
        .COUNTER_BITS(POR_BITS)
    ) u_por (
        .clk   (sys_clk),
        .rst_n (rst_n)
    );


    // ============================================================
    // 1024x600 LCD pixel clock
    //
    // Input : 50 MHz
    // VCO   : 50 MHz x 16 = 800 MHz
    // Output: 800 MHz / 15.625 = 51.2 MHz
    // Frame : 51.2 MHz / (1344 x 635) = about 60 Hz
    // ============================================================

    wire lcd_pix_clk_mmcm;
    wire lcd_pix_clk;

    wire lcd_clk_fb_mmcm;
    wire lcd_clk_fb;

    wire lcd_clk_locked;

    MMCME2_BASE #(
        .BANDWIDTH        ("OPTIMIZED"),
        .CLKIN1_PERIOD    (20.000),
        .DIVCLK_DIVIDE    (1),
        .CLKFBOUT_MULT_F  (16.000),
        .CLKOUT0_DIVIDE_F (15.625),
        .STARTUP_WAIT     ("FALSE")
    ) u_lcd_mmcm (
        .CLKIN1   (sys_clk),
        .CLKFBIN  (lcd_clk_fb),

        .RST      (~rst_n),
        .PWRDWN   (1'b0),

        .CLKOUT0  (lcd_pix_clk_mmcm),
        .CLKFBOUT (lcd_clk_fb_mmcm),
        .LOCKED   (lcd_clk_locked)
    );

    BUFG u_lcd_clk_fb_buf (
        .I (lcd_clk_fb_mmcm),
        .O (lcd_clk_fb)
    );

    BUFG u_lcd_pix_clk_buf (
        .I (lcd_pix_clk_mmcm),
        .O (lcd_pix_clk)
    );

    wire lcd_logic_rst_n;

    assign lcd_logic_rst_n = rst_n && lcd_clk_locked;


    // ============================================================
    // Chapter-7 controller signals
    // ============================================================

    wire event_up;
    wire event_down;
    wire event_left;
    wire event_right;

    wire event_ok;
    wire event_back;
    wire event_pause;

    wire [2:0] ui_state;
    wire [2:0] menu_sel;

    wire paused;

    wire [10:0] pointer_x;
    wire [9:0]  pointer_y;

    wire pointer_down;
    wire pointer_click;

    wire [7:0] keyboard_code;
    wire       keyboard_extended;

    wire [4:0] ec_count;

    wire [15:0] touch_x_raw;
    wire [15:0] touch_y_raw;

    wire        ft_flag;
    wire [15:0] chip_version;
    wire [6:0]  touch_state;

    wire touch_coord_valid_unused;


    // ============================================================
    // Chapter-7 unified input controller
    // ============================================================

    chapter7_controller #(
        .CLK_HZ          (CLK_HZ),
        .PS2_DEVICE_MODE (PS2_DEVICE_MODE)
    ) u_controller (
        .clk   (sys_clk),
        .rst_n (rst_n),

        // Matrix keypad is disabled in the LCD top to avoid
        // conflicting bus-switch selections.
        .keypad_valid (1'b0),
        .keypad_code  (4'd0),

        .S1_KEYA (S1_KEYA),
        .S1_KEYB (S1_KEYB),
        .S1_KEYC (S1_KEYC),
        .S1_KEYD (S1_KEYD),
        .S1_KEYP (S1_KEYP),

        .EC_A   (EC_A),
        .EC_B   (EC_B),
        .EC_KEY (EC_KEY),

        .PS2_CLK  (PS2_CLK),
        .PS2_DATA (PS2_DATA),

        .TOUCH_SCL (TOUCH_SCL),
        .TOUCH_SDA (TOUCH_SDA),
        .TOUCH_INT (TOUCH_INT),
        .TOUCH_RST (TOUCH_RST),

        .touch_key_press (1'b0),

        .event_up    (event_up),
        .event_down  (event_down),
        .event_left  (event_left),
        .event_right (event_right),
        .event_ok    (event_ok),
        .event_back  (event_back),
        .event_pause (event_pause),

        .ui_state (ui_state),
        .menu_sel (menu_sel),
        .paused   (paused),

        .pointer_x     (pointer_x),
        .pointer_y     (pointer_y),
        .pointer_down  (pointer_down),
        .pointer_click (pointer_click),

        .keyboard_code     (keyboard_code),
        .keyboard_extended (keyboard_extended),

        .ec_count (ec_count),

        .touch_x_raw (touch_x_raw),
        .touch_y_raw (touch_y_raw),

        .ft_flag      (ft_flag),
        .chip_version (chip_version),
        .touch_state  (touch_state),

        .touch_coord_valid (touch_coord_valid_unused)
    );


    // ============================================================
    // LCD timing
    // ============================================================

    wire [10:0] px;
    wire [9:0]  py;

    wire        active_video;
    wire [23:0] rgb;

    lcd_timing_1024x600 u_lcd_timing (
        .pix_clk (lcd_pix_clk),
        .rst_n   (lcd_logic_rst_n),

        .x            (px),
        .y            (py),
        .active_video (active_video),

        .hsync (LCD_HSYNC),
        .vsync (LCD_VSYNC)
    );


    // ============================================================
    // UI renderer
    // ============================================================

    ui_renderer_1024x600 u_renderer (
        .x            (px),
        .y            (py),
        .active_video (active_video),

        .ui_state (ui_state),
        .menu_sel (menu_sel),
        .paused   (paused),

        .keypad_code          (4'd0),
        .keypad_valid_latched (1'b0),

        .keyboard_code     (keyboard_code),
        .keyboard_extended (keyboard_extended),

        .ec_count (ec_count),

        // 统一使用触摸或鼠标的指针坐标
        .touch_x    ({5'd0, pointer_x}),
        .touch_y    ({6'd0, pointer_y}),

        // 鼠标模式下持续显示十字；触摸模式下仅按住时显示
        .touch_down (pointer_down || (PS2_DEVICE_MODE == 1)),
        .ft_flag    (ft_flag),

        .rgb (rgb)
    );


    // ============================================================
    // Register RGB and DE using the LCD pixel clock
    // ============================================================

    reg [23:0] lcd_rgb_reg;
    reg        lcd_de_reg;

    always @(posedge lcd_pix_clk or negedge lcd_logic_rst_n) begin
        if (!lcd_logic_rst_n) begin
            lcd_rgb_reg <= 24'h000000;
            lcd_de_reg  <= 1'b0;
        end
        else begin
            lcd_de_reg <= active_video;

            if (active_video)
                lcd_rgb_reg <= rgb;
            else
                lcd_rgb_reg <= 24'h000000;
        end
    end

    assign LCD_R = lcd_rgb_reg[23:16];
    assign LCD_G = lcd_rgb_reg[15:8];
    assign LCD_B = lcd_rgb_reg[7:0];

    assign LCD_DE = lcd_de_reg;


    // ============================================================
    // Forward the 51.2 MHz LCD pixel clock through ODDR
    //
    // RGB and DE update at the rising edge of lcd_pix_clk.
    // LCD_CLK rises at the falling edge, providing half a cycle
    // of setup time for the LCD.
    // ============================================================

    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE")
    ) u_lcd_clk_oddr (
        .Q  (LCD_CLK),
        .C  (lcd_pix_clk),
        .CE (1'b1),

        .D1 (1'b0),
        .D2 (1'b1),

        .R  (~lcd_logic_rst_n),
        .S  (1'b0)
    );


    // ============================================================
    // LCD control
    // ============================================================

    assign LCD_BL   = 1'b1;
    assign LCD_nRST = 1'b1;

endmodule