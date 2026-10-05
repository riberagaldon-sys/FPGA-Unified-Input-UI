`timescale 1ns/1ps

// Teaching-manual Chapter 8: unified input events and touch menus.
// Project: chapter7_unified_ui_200t_fixed_20260811_clean
// Simulation top: tb_chapter8_all.  Run 4 ms; expect CH8 PASS.
//
// The DUT is the ORIGINAL chapter7_controller from this project.  Its touch
// adapter, pointer selector, event router, hit-test and UI FSM are real RTL.
// Controlled touch samples are injected only at the touch-driver/adapter
// boundary, using four persistent forces below.  This is a CONTROL-LAYER
// simulation, not an I2C, LCD/MMCM, board, timing or CDC qualification.
// PS/2 keyboard frames and five-way/EC11 electrical inputs are driven at ports.
// Only debounce/EC11 timing parameters are shortened in the testbench.
// Matrix keypad and the separate touch key remain disconnected, as in UI Top.
// Actual keyboard mapping: Enter=confirm, Esc=back, Space=pause/resume.
//
// Root waveform aliases are available directly under tb_chapter8_all.
// Figure 8-1: 13.95--14.20 us, release click and touch-coordinate selection.
// Figure 8-2(a): 18--56 us, displacement 29 versus 30 (X and Y).
// Figure 8-2(b): 58--116 us, 79 versus 80, directions and menu selection.
// Optional input-source view: 198--1230 us (five-way and PS/2 keyboard).
// The remaining checks cover button edges, all 7 entries, EC11 and priority.
// There is deliberately no $finish or $stop, so Vivado remains open.

module tb_chapter8_all;
    reg sys_clk = 1'b0;
    always #10 sys_clk = ~sys_clk; // actual 50 MHz simulation clock
    reg rst_n = 1'b0;

    reg S1_KEYA = 1'b1; // down, active low
    reg S1_KEYB = 1'b1; // left
    reg S1_KEYC = 1'b1; // right
    reg S1_KEYD = 1'b1; // up
    reg S1_KEYP = 1'b1; // center/confirm
    reg EC_A = 1'b1;
    reg EC_B = 1'b1;
    reg EC_KEY = 1'b1;

    tri1 PS2_CLK;
    tri1 PS2_DATA;
    reg kb_clk_low = 1'b0;
    reg kb_data_low = 1'b0;
    assign PS2_CLK = kb_clk_low ? 1'b0 : 1'bz;
    assign PS2_DATA = kb_data_low ? 1'b0 : 1'bz;

    wire TOUCH_SCL, TOUCH_RST;
    tri1 TOUCH_SDA;
    tri1 TOUCH_INT;

    wire event_up, event_down, event_left, event_right;
    wire event_ok, event_back, event_pause;
    wire [2:0] ui_state, menu_index;
    wire paused;
    wire [10:0] pointer_x;
    wire [9:0] pointer_y;
    wire pointer_down, pointer_click;
    wire [7:0] keyboard_code;
    wire keyboard_extended;
    wire [4:0] ec_count;
    wire [15:0] touch_x_raw, touch_y_raw;
    wire [6:0] touch_state;
    wire ft_flag;
    wire [15:0] chip_version;
    wire coord_update_pulse;
    wire touch_i2c_ack, touch_i2c_done, touch_valid_monitor;

    chapter7_controller #(
        .CLK_HZ(50_000_000), .PS2_DEVICE_MODE(0)
    ) dut (
        .clk(sys_clk), .rst_n(rst_n),
        .keypad_valid(1'b0), .keypad_code(4'd0),
        .S1_KEYA(S1_KEYA), .S1_KEYB(S1_KEYB), .S1_KEYC(S1_KEYC),
        .S1_KEYD(S1_KEYD), .S1_KEYP(S1_KEYP),
        .EC_A(EC_A), .EC_B(EC_B), .EC_KEY(EC_KEY),
        .PS2_CLK(PS2_CLK), .PS2_DATA(PS2_DATA),
        .TOUCH_SCL(TOUCH_SCL), .TOUCH_SDA(TOUCH_SDA),
        .TOUCH_INT(TOUCH_INT), .TOUCH_RST(TOUCH_RST),
        .touch_key_press(1'b0),
        .event_up(event_up), .event_down(event_down),
        .event_left(event_left), .event_right(event_right),
        .event_ok(event_ok), .event_back(event_back),
        .event_pause(event_pause),
        .ui_state(ui_state), .menu_sel(menu_index), .paused(paused),
        .pointer_x(pointer_x), .pointer_y(pointer_y),
        .pointer_down(pointer_down), .pointer_click(pointer_click),
        .keyboard_code(keyboard_code), .keyboard_extended(keyboard_extended),
        .ec_count(ec_count), .touch_x_raw(touch_x_raw),
        .touch_y_raw(touch_y_raw), .ft_flag(ft_flag),
        .chip_version(chip_version), .touch_state(touch_state),
        .touch_coord_valid(coord_update_pulse),
        .touch_i2c_ack(touch_i2c_ack), .touch_i2c_done(touch_i2c_done),
        .touch_valid_monitor(touch_valid_monitor)
    );

    // SIMULATION ONLY: 20 stable samples rather than 20 ms.
    // The system clock and PS/2 CLK_HZ retain the real 50 MHz value.
    defparam dut.u_fiveway.CLK_HZ = 1000;
    defparam dut.u_ec_key.CLK_HZ = 1000;
    defparam dut.u_ec_compat.CLK_HZ = 1000;

    reg stim_touch_valid = 1'b0;
    reg [15:0] stim_touch_x = 16'd0;
    reg [15:0] stim_touch_y = 16'd0;
    reg [6:0] stim_touch_state = 7'h10;
    initial begin
        // Inject RAW INPUTS, never gesture outputs, event outputs or UI state.
        force dut.touch_valid_raw = stim_touch_valid;
        force dut.touch_x_raw = stim_touch_x;
        force dut.touch_y_raw = stim_touch_y;
        force dut.touch_state = stim_touch_state;
    end

    // Read-only aliases of the actual DUT.  Keep these at the root for Vivado.
    wire touch_valid_raw = dut.touch_valid_raw;
    wire touch_down = dut.touch_pointer_down;
    wire touch_click = dut.touch_pointer_click;
    wire [10:0] touch_pointer_x = dut.touch_pointer_x;
    wire [9:0] touch_pointer_y = dut.touch_pointer_y;
    wire touch_selected = dut.touch_pointer_selected;
    wire gesture_active = dut.u_touch_adapter.gesture_active;
    wire [10:0] start_x = dut.u_touch_adapter.start_x;
    wire [9:0] start_y = dut.u_touch_adapter.start_y;
    wire [10:0] last_x = dut.u_touch_adapter.last_x;
    wire [9:0] last_y = dut.u_touch_adapter.last_y;
    wire signed [12:0] dx = dut.u_touch_adapter.dx_release;
    wire signed [11:0] dy = dut.u_touch_adapter.dy_release;
    wire [12:0] abs_dx = dut.u_touch_adapter.abs_dx;
    wire [11:0] abs_dy = dut.u_touch_adapter.abs_dy;
    wire swipe_up = dut.touch_swipe_up;
    wire swipe_down = dut.touch_swipe_down;
    wire swipe_left = dut.touch_swipe_left;
    wire swipe_right = dut.touch_swipe_right;
    wire button_hit = dut.button_hit;
    wire button_click = dut.button_click;
    wire [2:0] button_index = dut.button_index;
    wire five_up_press = dut.five_up_press;
    wire five_down_press = dut.five_down_press;
    wire five_left_press = dut.five_left_press;
    wire five_right_press = dut.five_right_press;
    wire five_center_press = dut.five_center_press;
    wire keyboard_press = dut.g_keyboard.key_press;
    wire keyboard_release = dut.g_keyboard.key_release;
    wire keyboard_scan_valid = dut.g_keyboard.scan_valid;
    wire keyboard_frame_error = dut.g_keyboard.frame_error;
    wire ec_step = dut.ec_step;
    wire ec_key_press = dut.ec_key_press;

    integer case_id = 0;
    integer gesture_tests = 0;
    integer errors = 0;
    reg checks_done = 1'b0;
    reg checks_pass = 1'b0;
    integer click_count = 0;
    integer swipe_up_count = 0, swipe_down_count = 0;
    integer swipe_left_count = 0, swipe_right_count = 0;
    integer ok_count = 0, back_count = 0, pause_count = 0;
    integer up_count = 0, down_count = 0, left_count = 0, right_count = 0;
    integer button_count = 0;
    integer simultaneous_button_up = 0;
    integer simultaneous_up_down = 0;
    reg [4:0] gesture_prev = 5'b0;
    reg expected_touch_phase = 1'b0;
    reg [10:0] expected_click_x = 11'd0;
    reg [9:0] expected_click_y = 10'd0;

    task check;
        input condition;
        input [8*120-1:0] message;
        begin
            if (condition !== 1'b1) begin
                errors = errors + 1;
                $display("CH8 ERROR case=%0d time=%0.3f us: %0s",
                         case_id, $realtime/1000.0, message);
            end
        end
    endtask

    always @(posedge sys_clk) begin
        #1;
        if (rst_n) begin
            if (touch_click) begin
                click_count = click_count + 1;
                check(touch_down == 1'b0, "release click occurs with touch_down=0");
                check(touch_selected == 1'b1, "release click retains touch pointer source");
                if (expected_touch_phase) begin
                    check(pointer_x == expected_click_x && pointer_y == expected_click_y,
                          "release uses the final completed touch coordinate");
                end
                check(event_ok == 1'b1, "touch click reaches unified confirm");
                $display("CH8 CLICK case=%0d at=%0.3f us pointer=(%0d,%0d) button_hit=%0b index=%0d",
                         case_id, $realtime/1000.0, pointer_x, pointer_y,
                         button_hit, button_index);
            end
            if (swipe_up) swipe_up_count = swipe_up_count + 1;
            if (swipe_down) swipe_down_count = swipe_down_count + 1;
            if (swipe_left) swipe_left_count = swipe_left_count + 1;
            if (swipe_right) swipe_right_count = swipe_right_count + 1;
            if (event_ok) ok_count = ok_count + 1;
            if (event_back) back_count = back_count + 1;
            if (event_pause) pause_count = pause_count + 1;
            if (event_up) up_count = up_count + 1;
            if (event_down) down_count = down_count + 1;
            if (event_left) left_count = left_count + 1;
            if (event_right) right_count = right_count + 1;
            if (button_click) button_count = button_count + 1;
            if (button_click && event_up)
                simultaneous_button_up = simultaneous_button_up + 1;
            if (event_up && event_down)
                simultaneous_up_down = simultaneous_up_down + 1;
            check(keyboard_frame_error == 1'b0, "all generated PS/2 frames are valid");
            check((gesture_prev & {touch_click, swipe_up, swipe_down,
                                   swipe_left, swipe_right}) == 5'b0,
                  "gesture requests last only one clock cycle");
            gesture_prev = {touch_click, swipe_up, swipe_down, swipe_left, swipe_right};
        end else begin
            gesture_prev = 5'b0;
        end
    end

    task clear_counts;
        begin
            click_count = 0;
            swipe_up_count = 0; swipe_down_count = 0;
            swipe_left_count = 0; swipe_right_count = 0;
            ok_count = 0; back_count = 0; pause_count = 0;
            up_count = 0; down_count = 0; left_count = 0; right_count = 0;
            button_count = 0;
            simultaneous_button_up = 0; simultaneous_up_down = 0;
        end
    endtask

    task at_us;
        input integer target_us;
        time goal;
        begin
            goal = target_us * 1000;
            check($time <= goal, "scheduled test did not overrun its time slot");
            if ($time < goal) #(goal - $time);
            @(negedge sys_clk);
        end
    endtask

    task reset_controller;
        begin
            rst_n = 1'b0;
            stim_touch_valid = 1'b0;
            stim_touch_state = 7'h10;
            stim_touch_x = 0; stim_touch_y = 0;
            S1_KEYA = 1; S1_KEYB = 1; S1_KEYC = 1; S1_KEYD = 1; S1_KEYP = 1;
            EC_A = 1; EC_B = 1; EC_KEY = 1;
            kb_clk_low = 0; kb_data_low = 0;
            repeat (8) @(negedge sys_clk);
            rst_n = 1'b1;
            repeat (6) @(negedge sys_clk);
            clear_counts;
            expected_touch_phase = 1'b0;
            check(ui_state == 0 && menu_index == 0 && paused == 0,
                  "reset returns to home, menu zero, unpaused");
        end
    endtask

    task completed_coordinate;
        input integer px;
        input integer py;
        begin
            stim_touch_x = px;
            stim_touch_y = py;
            // A completed coordinate has the same 0x40 -> 0x10 transition
            // consumed by the original touch_event_adapter.
            stim_touch_state = 7'h40;
            repeat (2) @(negedge sys_clk);
            stim_touch_state = 7'h10;
            repeat (6) @(negedge sys_clk);
            check(touch_pointer_x == px && touch_pointer_y == py,
                  "adapter consumed the completed coordinate");
        end
    endtask

    task gesture;
        input integer id;
        input integer begin_us;
        input integer x0, y0, x1, y1;
        input integer expect_click, expect_up, expect_down, expect_left, expect_right;
        input integer expect_state, expect_menu, expect_hit;
        begin
            at_us(begin_us);
            case_id = id;
            reset_controller;
            expected_click_x = x1; expected_click_y = y1;
            expected_touch_phase = 1'b1;
            stim_touch_valid = 1'b1;
            completed_coordinate(x0, y0);
            check(click_count == 0 && ok_count == 0,
                  "contact start is not an immediate click");
            at_us(begin_us + 2);
            completed_coordinate(x1, y1);
            check(dx == x1-x0 && dy == y1-y0, "signed final displacement is correct");
            check(click_count == 0 && ok_count == 0,
                  "coordinate movement while held does not click");
            at_us(begin_us + 4);
            stim_touch_valid = 1'b0;
            repeat (12) @(negedge sys_clk);
            check(click_count == expect_click, "click count matches this boundary case");
            check(swipe_up_count == expect_up, "up swipe count");
            check(swipe_down_count == expect_down, "down swipe count");
            check(swipe_left_count == expect_left, "left swipe count");
            check(swipe_right_count == expect_right, "right swipe count");
            check(button_count == expect_hit, "menu button hit count");
            check(ui_state == expect_state && menu_index == expect_menu,
                  "UI state and menu selection match actual RTL");
            check(touch_down == 0 && gesture_active == 0, "release ends the gesture");
            check(pointer_x == 512 && pointer_y == 300,
                  "after the click cycle pointer returns to the idle mouse position");
            gesture_tests = gesture_tests + 1;
            $display("CH8 GESTURE case=%0d at=%0.3f us delta=(%0d,%0d) click=%0d swipe(U,D,L,R)=(%0d,%0d,%0d,%0d) ui=%0d menu=%0d",
                     case_id, $realtime/1000.0, dx, dy, click_count,
                     swipe_up_count, swipe_down_count, swipe_left_count,
                     swipe_right_count, ui_state, menu_index);
            expected_touch_phase = 1'b0;
        end
    endtask

    task five_press;
        input integer key;
        begin
            @(negedge sys_clk);
            case (key)
                0: S1_KEYA = 0;
                1: S1_KEYB = 0;
                2: S1_KEYC = 0;
                3: S1_KEYD = 0;
                4: S1_KEYP = 0;
            endcase
            repeat (60) @(negedge sys_clk);
            S1_KEYA = 1; S1_KEYB = 1; S1_KEYC = 1; S1_KEYD = 1; S1_KEYP = 1;
            repeat (60) @(negedge sys_clk);
        end
    endtask

    task ps2_byte;
        input [7:0] value;
        reg [10:0] frame;
        integer i;
        begin
            frame = {1'b1, ~(^value), value, 1'b0};
            kb_clk_low = 0; kb_data_low = 0;
            #2000;
            for (i = 0; i < 11; i = i + 1) begin
                kb_data_low = ~frame[i];
                #1000;
                kb_clk_low = 1;
                #2000;
                kb_clk_low = 0;
                #1000;
            end
            kb_data_low = 0;
            #2000;
            @(negedge sys_clk);
        end
    endtask

    task keyboard_break;
        input [7:0] value;
        input extended_key;
        begin
            if (extended_key) ps2_byte(8'hE0);
            ps2_byte(8'hF0);
            ps2_byte(value);
        end
    endtask

    task ec_rotate;
        input reverse;
        begin
            @(negedge sys_clk);
            if (reverse) EC_B = 0; else EC_A = 0;
            repeat (8) @(negedge sys_clk);
            if (reverse) EC_A = 0; else EC_B = 0;
            repeat (8) @(negedge sys_clk);
            if (reverse) EC_B = 1; else EC_A = 1;
            repeat (8) @(negedge sys_clk);
            if (reverse) EC_A = 1; else EC_B = 1;
            repeat (8) @(negedge sys_clk);
            repeat (400) @(negedge sys_clk);
        end
    endtask

    integer j;
    integer snapshot;
    initial begin
        $timeformat(-6, 3, " us", 12);
        // click at menu entry 1, rather than idle mouse entry 3:
        // this distinguishes the actual pointer selection from a wrong mux.
        gesture(1, 10, 300,130, 320,140, 1,0,0,0,0, 2,1,1);

        // Strict click threshold: BOTH axes must have absolute movement <30.
        gesture(2, 20, 300,130, 329,130, 1,0,0,0,0, 2,1,1);
        gesture(3, 30, 300,130, 330,130, 0,0,0,0,0, 0,0,0);
        gesture(4, 40, 300,130, 300,159, 1,0,0,0,0, 2,1,1);
        gesture(5, 50, 300,130, 300,160, 0,0,0,0,0, 0,0,0);

        // Swipe threshold and dominant axis.  Horizontal requests exist but
        // this UI FSM uses only up/down for menu movement.
        gesture(6, 60, 300,130, 300,209, 0,0,0,0,0, 0,0,0);
        gesture(7, 70, 300,130, 300,210, 0,0,1,0,0, 0,1,0);
        gesture(8, 80, 300,210, 300,130, 0,1,0,0,0, 0,6,0);
        gesture(9, 90, 300,130, 380,130, 0,0,0,0,1, 0,0,0);
        gesture(10,100, 380,130, 300,130, 0,0,0,1,0, 0,0,0);
        gesture(11,110, 300,130, 380,210, 0,0,0,0,1, 0,0,0);

        // Actual hit-test bounds: 140<=X<884; first button 40<=Y<98.
        // NOTE: outside a menu button, the current router STILL produces
        // event_ok for a click.  The UI opens the currently selected entry.
        // No claim is made that an outside click is ignored by current RTL.
        gesture(12,120, 139,40, 139,40, 1,0,0,0,0, 1,0,0);
        gesture(13,130, 140,40, 140,40, 1,0,0,0,0, 1,0,1);
        gesture(14,140, 883,97, 883,97, 1,0,0,0,0, 1,0,1);
        gesture(15,150, 884,40, 884,40, 1,0,0,0,0, 1,0,0);
        gesture(16,160, 300,98, 300,98, 1,0,0,0,0, 1,0,0);
        gesture(17,170, 300,116,300,116,1,0,0,0,0, 2,1,1);

        at_us(200);
        case_id = 20;
        reset_controller;
        // A four-cycle key bounce is shorter than the 20-sample debounce.
        S1_KEYA = 0;
        repeat (4) @(negedge sys_clk);
        S1_KEYA = 1;
        repeat (40) @(negedge sys_clk);
        check(down_count == 0 && menu_index == 0, "short key bounce is rejected");
        five_press(0);
        check(down_count == 1 && menu_index == 1 && ui_state == 0,
              "five-way A is down, one event for one held press");
        five_press(1);
        five_press(2);
        check(left_count == 1 && right_count == 1 && menu_index == 1,
              "five-way left/right events do not alter this vertical menu");
        five_press(4);
        check(ok_count == 1 && ui_state == 2, "five-way center opens selected entry");
        ps2_byte(8'h76); // Esc is the available return source in keyboard mode.
        check(back_count == 1 && ui_state == 0 && menu_index == 1,
              "PS/2 Esc returns home and preserves selection");
        keyboard_break(8'h76, 1'b0);
        check(back_count == 1, "Esc release does not return a second time");

        at_us(400);
        case_id = 21;
        reset_controller;
        ps2_byte(8'hE0); ps2_byte(8'h72); // extended down
        check(menu_index == 1 && down_count == 1, "extended PS/2 down moves the menu");
        keyboard_break(8'h72, 1'b1);
        check(down_count == 1, "extended down release is not another direction event");
        ps2_byte(8'h5A); // Enter
        check(ui_state == 2 && ok_count == 1, "Enter MAKE confirms selected entry");
        keyboard_break(8'h5A, 1'b0);
        check(ok_count == 1 && ui_state == 2, "Enter BREAK does not confirm again");
        ps2_byte(8'h29); // Space
        check(paused == 1 && pause_count == 1 && ok_count == 1,
              "Space pauses, and is not a confirm event");
        keyboard_break(8'h29, 1'b0);
        check(paused == 1 && pause_count == 1, "Space BREAK does not toggle pause");
        ps2_byte(8'h29);
        check(paused == 0 && pause_count == 2, "a second Space MAKE resumes");
        keyboard_break(8'h29, 1'b0);
        ps2_byte(8'h76);
        keyboard_break(8'h76, 1'b0);
        check(ui_state == 0 && back_count == 1, "keyboard returns from the page");
        ps2_byte(8'h1D); keyboard_break(8'h1D, 1'b0); // W
        check(menu_index == 0 && up_count == 1, "W generates up");
        ps2_byte(8'h1C); keyboard_break(8'h1C, 1'b0); // A
        ps2_byte(8'h23); keyboard_break(8'h23, 1'b0); // D
        check(left_count == 1 && right_count == 1, "A/D generate left/right");
        ps2_byte(8'h4D); keyboard_break(8'h4D, 1'b0); // P: no current mapping
        check(pause_count == 2 && ok_count == 1, "P has no pause/confirm mapping in current RTL");

        at_us(1900);
        case_id = 22;
        reset_controller;
        ec_rotate(1'b0); ec_rotate(1'b1);
        check(ec_count == 2, "EC11 compatibility counter increases in both directions");
        check(up_count == 0 && down_count == 0 && menu_index == 0,
              "EC11 rotation is counting, not menu navigation");
        EC_KEY = 0;
        repeat (60) @(negedge sys_clk);
        EC_KEY = 1;
        repeat (60) @(negedge sys_clk);
        check(ec_count == 0 && ok_count == 1 && ui_state == 1,
              "EC11 shaft key clears counter and confirms once");

        at_us(2100);
        case_id = 30;
        reset_controller;
        expected_touch_phase = 1;
        expected_click_x = 320; expected_click_y = 140;
        stim_touch_valid = 1;
        completed_coordinate(300,130);
        completed_coordinate(320,140);
        // Debounce asserts at key-edge+430 ns; synchronized release asserts
        // at release-edge+50 ns.  Align actual source events, not outputs.
        S1_KEYD = 0;
        repeat (19) @(negedge sys_clk);
        stim_touch_valid = 0;
        repeat (20) @(negedge sys_clk);
        S1_KEYD = 1;
        repeat (40) @(negedge sys_clk);
        check(simultaneous_button_up == 1, "touch-button and up arrived in the same clock");
        check(ui_state == 2 && menu_index == 1, "touch button wins over simultaneous up");
        expected_touch_phase = 0;

        at_us(2200);
        case_id = 31;
        reset_controller;
        S1_KEYA = 0; S1_KEYD = 0;
        repeat (60) @(negedge sys_clk);
        S1_KEYA = 1; S1_KEYD = 1;
        repeat (60) @(negedge sys_clk);
        check(simultaneous_up_down == 1, "up/down presses arrived in the same clock");
        check(menu_index == 6 && ui_state == 0, "up wins over down; selection wraps 0 to 6");

        // All seven real menu rectangles open the corresponding UI state.
        for (j = 0; j < 7; j = j + 1)
            gesture(100+j, 2400+j*100, 300,69+j*76, 300,69+j*76,
                    1,0,0,0,0, j+1,j,1);

        at_us(3200);
        checks_done = 1'b1;
        checks_pass = (errors == 0);
        if (checks_pass)
            $display("CH8 PASS: control-layer tests complete; gesture_tests=%0d errors=%0d",
                     gesture_tests, errors);
        else
            $display("CH8 FAIL: gesture_tests=%0d errors=%0d", gesture_tests, errors);
    end

    initial begin
        #5_000_000;
        if (!checks_done) begin
            check(1'b0, "testbench watchdog expired");
            checks_done = 1'b1;
            checks_pass = 1'b0;
            $display("CH8 FAIL: timeout");
        end
    end
endmodule
