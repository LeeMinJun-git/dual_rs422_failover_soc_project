`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// tb_sensor_guard_core
//
// Self-checking Verilog-2005 testbench for the reviewed sensor_guard_core.
//
// Coverage
//   - asynchronous reset and synchronous clear
//   - clear priority over adc_valid
//   - enable=0 sample rejection and session invalidation
//   - state/statistics retention across enable toggling
//   - first-sample Delta suppression after clear and re-enable
//   - threshold boundary, Under, Over and Delta behavior
//   - non-sticky per-sample alarm updates
//   - one alarm_count increment for simultaneous sample alarms
//   - current/min/max/last_delta tracking
//   - data_seen lifecycle for AXI STATUS[1]
//   - display_valid level behavior
//   - Stale start only after first sample
//   - exact Stale timeout boundary, recovery and re-entry
//   - stale_limit_cycles values 0 and 1
//   - valid sample arriving on the would-be timeout clock
//   - runtime threshold changes applied only on the next valid sample
//   - saturating sample_count and alarm_count
//
// The DUT counter width is reduced to 4 bits so saturation can be verified fast.
//////////////////////////////////////////////////////////////////////////////////

module tb_sensor_guard_core;

    localparam integer COUNTER_WIDTH = 4;
    localparam integer CLK_PERIOD_NS = 10;

    reg                         clk;
    reg                         reset_p;
    reg                         enable;
    reg                         clear;
    reg  [11:0]                 adc_raw;
    reg                         adc_valid;
    reg  [11:0]                 low_threshold;
    reg  [11:0]                 high_threshold;
    reg  [11:0]                 max_delta;
    reg  [31:0]                 stale_limit_cycles;

    wire [11:0]                 current_adc;
    wire [11:0]                 min_adc;
    wire [11:0]                 max_adc;
    wire [11:0]                 last_delta;
    wire                        data_seen;
    wire                        display_valid;
    wire                        under_alarm;
    wire                        over_alarm;
    wire                        delta_alarm;
    wire                        stale_alarm;
    wire                        sensor_alarm;
    wire [COUNTER_WIDTH-1:0]    sample_count;
    wire [COUNTER_WIDTH-1:0]    alarm_count;

    integer check_count;
    integer fail_count;
    integer loop_index;

    sensor_guard_core #(
        .COUNTER_WIDTH (COUNTER_WIDTH)
    ) dut (
        .clk                (clk),
        .reset_p            (reset_p),
        .enable             (enable),
        .clear              (clear),
        .adc_raw            (adc_raw),
        .adc_valid          (adc_valid),
        .low_threshold      (low_threshold),
        .high_threshold     (high_threshold),
        .max_delta          (max_delta),
        .stale_limit_cycles (stale_limit_cycles),
        .current_adc        (current_adc),
        .min_adc            (min_adc),
        .max_adc            (max_adc),
        .last_delta         (last_delta),
        .data_seen          (data_seen),
        .display_valid      (display_valid),
        .under_alarm        (under_alarm),
        .over_alarm         (over_alarm),
        .delta_alarm        (delta_alarm),
        .stale_alarm        (stale_alarm),
        .sensor_alarm       (sensor_alarm),
        .sample_count       (sample_count),
        .alarm_count        (alarm_count)
    );

    always #(CLK_PERIOD_NS/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Self-check helpers
    // -------------------------------------------------------------------------
    task check_bit;
        input actual;
        input expected;
        input [8*120-1:0] label;
        begin
            check_count = check_count + 1;
            if (actual !== expected) begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s expected=%b actual=%b time=%0t",
                         label, expected, actual, $time);
            end
            else begin
                $display("[PASS] %0s = %b", label, actual);
            end
        end
    endtask

    task check_u12;
        input [11:0] actual;
        input [11:0] expected;
        input [8*120-1:0] label;
        begin
            check_count = check_count + 1;
            if (actual !== expected) begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s expected=%0d(0x%03h) actual=%0d(0x%03h) time=%0t",
                         label, expected, expected, actual, actual, $time);
            end
            else begin
                $display("[PASS] %0s = %0d(0x%03h)",
                         label, actual, actual);
            end
        end
    endtask

    task check_count4;
        input [COUNTER_WIDTH-1:0] actual;
        input [COUNTER_WIDTH-1:0] expected;
        input [8*120-1:0] label;
        begin
            check_count = check_count + 1;
            if (actual !== expected) begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s expected=%0d actual=%0d time=%0t",
                         label, expected, actual, $time);
            end
            else begin
                $display("[PASS] %0s = %0d", label, actual);
            end
        end
    endtask

    task check_alarms;
        input expected_under;
        input expected_over;
        input expected_delta;
        input expected_stale;
        input [8*120-1:0] label;
        begin
            check_bit(under_alarm, expected_under, label);
            check_bit(over_alarm,  expected_over,  label);
            check_bit(delta_alarm, expected_delta, label);
            check_bit(stale_alarm, expected_stale, label);
            check_bit(sensor_alarm,
                      expected_under | expected_over |
                      expected_delta | expected_stale,
                      label);
        end
    endtask

    // Drive inputs on falling edges and check 1 ns after the next rising edge.
    task tick_idle;
        input enable_i;
        input clear_i;
        begin
            @(negedge clk);
            enable    = enable_i;
            clear     = clear_i;
            adc_valid = 1'b0;
            @(posedge clk);
            #1;
        end
    endtask

    task tick_sample;
        input [11:0] sample_i;
        input enable_i;
        input clear_i;
        begin
            @(negedge clk);
            enable    = enable_i;
            clear     = clear_i;
            adc_raw   = sample_i;
            adc_valid = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    task apply_clear;
        begin
            tick_idle(1'b1, 1'b1);
            check_u12(current_adc, 12'd0, "clear current_adc");
            check_u12(min_adc,     12'd0, "clear min_adc");
            check_u12(max_adc,     12'd0, "clear max_adc");
            check_u12(last_delta,  12'd0, "clear last_delta");
            check_bit(data_seen,     1'b0, "clear data_seen");
            check_bit(display_valid, 1'b0, "clear display_valid");
            check_alarms(1'b0, 1'b0, 1'b0, 1'b0, "clear alarms");
            check_count4(sample_count, 4'd0, "clear sample_count");
            check_count4(alarm_count,  4'd0, "clear alarm_count");
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------
    initial begin
        clk                = 1'b0;
        reset_p            = 1'b1;
        enable             = 1'b0;
        clear              = 1'b0;
        adc_raw            = 12'd0;
        adc_valid          = 1'b0;
        low_threshold      = 12'd410;
        high_threshold     = 12'd3685;
        max_delta          = 12'd512;
        stale_limit_cycles = 32'd3;

        check_count = 0;
        fail_count  = 0;

        $dumpfile("tb_sensor_guard_core_reviewed.vcd");
        $dumpvars(0, tb_sensor_guard_core);

        $display("============================================================");
        $display(" Reviewed sensor_guard_core verification start");
        $display("============================================================");

        // ---------------------------------------------------------------------
        // TEST 0: Asynchronous reset defaults
        // ---------------------------------------------------------------------
        #1;
        $display("\n--- TEST 0: asynchronous reset defaults ---");
        check_u12(current_adc, 12'd0, "reset current_adc");
        check_u12(min_adc,     12'd0, "reset min_adc");
        check_u12(max_adc,     12'd0, "reset max_adc");
        check_u12(last_delta,  12'd0, "reset last_delta");
        check_bit(data_seen,     1'b0, "reset data_seen");
        check_bit(display_valid, 1'b0, "reset display_valid");
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0, "reset alarms");
        check_count4(sample_count, 4'd0, "reset sample_count");
        check_count4(alarm_count,  4'd0, "reset alarm_count");

        repeat (2) @(posedge clk);
        @(negedge clk);
        reset_p = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 1: clear priority over adc_valid
        // ---------------------------------------------------------------------
        $display("\n--- TEST 1: clear priority over adc_valid ---");
        apply_clear();
        tick_sample(12'd1000, 1'b1, 1'b0);
        check_count4(sample_count, 4'd1, "pre-clear sample accepted");

        tick_sample(12'd3000, 1'b1, 1'b1);
        check_u12(current_adc, 12'd0, "clear+sample current remains zero");
        check_u12(min_adc,     12'd0, "clear+sample min remains zero");
        check_u12(max_adc,     12'd0, "clear+sample max remains zero");
        check_count4(sample_count, 4'd0, "clear+sample ignored");
        check_count4(alarm_count,  4'd0, "clear+sample no alarm count");
        check_bit(data_seen,     1'b0, "clear+sample data_seen remains clear");
        check_bit(display_valid, 1'b0, "clear+sample display invalid");

        // ---------------------------------------------------------------------
        // TEST 2: no Stale before first sample, first-sample behavior,
        //         adc_valid qualification, display_valid level
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: first sample and display_valid level ---");
        apply_clear();
        low_threshold      = 12'd410;
        high_threshold     = 12'd3685;
        max_delta          = 12'd100;
        stale_limit_cycles = 32'd3;

        for (loop_index = 0; loop_index < 5; loop_index = loop_index + 1)
            tick_idle(1'b1, 1'b0);

        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "no stale before first sample");
        check_bit(data_seen, 1'b0,
                  "data_seen clear before first sample");
        check_bit(display_valid, 1'b0,
                  "display invalid before first sample");
        check_count4(alarm_count, 4'd0,
                     "no alarm count before first sample");

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_u12(current_adc, 12'd1000, "first sample current");
        check_u12(min_adc,     12'd1000, "first sample min");
        check_u12(max_adc,     12'd1000, "first sample max");
        check_u12(last_delta,  12'd0,    "first sample delta suppressed");
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "first normal sample alarms");
        check_bit(data_seen, 1'b1,
                  "first accepted sample sets data_seen");
        check_bit(display_valid, 1'b1,
                  "display valid after first sample");
        check_count4(sample_count, 4'd1, "first sample count");

        adc_raw = 12'd50;
        tick_idle(1'b1, 1'b0);
        check_u12(current_adc, 12'd1000,
                  "adc_raw ignored without adc_valid");
        check_count4(sample_count, 4'd1,
                     "no sample count without adc_valid");
        check_bit(data_seen, 1'b1,
                  "data_seen remains set between samples");
        check_bit(display_valid, 1'b1,
                  "display_valid remains level between samples");

        // ---------------------------------------------------------------------
        // TEST 3: threshold boundaries and non-sticky alarms
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: threshold boundaries and sample alarms ---");
        apply_clear();
        max_delta = 12'd4095;

        tick_sample(12'd410, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "low threshold equality normal");

        tick_sample(12'd3685, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "high threshold equality normal");

        tick_sample(12'd409, 1'b1, 1'b0);
        check_alarms(1'b1, 1'b0, 1'b0, 1'b0,
                     "under sample");
        check_count4(alarm_count, 4'd1, "under increments alarm_count");
        check_bit(display_valid, 1'b1,
                  "under sample remains display-valid");

        tick_sample(12'd500, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "normal sample clears under alarm");
        check_count4(alarm_count, 4'd1,
                     "normal sample does not increment alarm_count");

        tick_sample(12'd3686, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b1, 1'b0, 1'b0,
                     "over sample");
        check_count4(alarm_count, 4'd2, "over increments alarm_count");

        tick_sample(12'd3685, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "normal sample clears over alarm");
        check_count4(alarm_count, 4'd2,
                     "clearing alarm does not change count");

        // ---------------------------------------------------------------------
        // TEST 4: Delta boundary, forward/reverse Delta, alarm clearing
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: Delta behavior ---");
        apply_clear();
        low_threshold  = 12'd0;
        high_threshold = 12'd4095;
        max_delta      = 12'd512;

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_u12(last_delta, 12'd0, "Delta first sample zero");
        check_bit(delta_alarm, 1'b0, "Delta first sample no alarm");

        tick_sample(12'd1512, 1'b1, 1'b0);
        check_u12(last_delta, 12'd512, "Delta equality value");
        check_bit(delta_alarm, 1'b0, "Delta equality normal");
        check_count4(alarm_count, 4'd0,
                     "Delta equality no alarm count");

        tick_sample(12'd2025, 1'b1, 1'b0);
        check_u12(last_delta, 12'd513, "Delta above threshold value");
        check_bit(delta_alarm, 1'b1, "Delta above threshold alarm");
        check_count4(alarm_count, 4'd1,
                     "Delta alarm increments once");

        tick_sample(12'd2030, 1'b1, 1'b0);
        check_u12(last_delta, 12'd5, "small Delta value");
        check_bit(delta_alarm, 1'b0,
                  "normal Delta clears previous Delta alarm");

        tick_sample(12'd1500, 1'b1, 1'b0);
        check_u12(last_delta, 12'd530, "reverse Delta value");
        check_bit(delta_alarm, 1'b1, "reverse Delta alarm");
        check_count4(alarm_count, 4'd2,
                     "reverse Delta increments once");

        tick_sample(12'd988, 1'b1, 1'b0);
        check_u12(last_delta, 12'd512, "reverse Delta equality");
        check_bit(delta_alarm, 1'b0,
                  "reverse Delta equality clears alarm");

        // ---------------------------------------------------------------------
        // TEST 5: simultaneous alarms count only once per sample
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: simultaneous alarms count once ---");
        apply_clear();
        low_threshold  = 12'd410;
        high_threshold = 12'd3685;
        max_delta      = 12'd100;

        tick_sample(12'd1000, 1'b1, 1'b0);
        tick_sample(12'd300, 1'b1, 1'b0);
        check_alarms(1'b1, 1'b0, 1'b1, 1'b0,
                     "under and Delta together");
        check_count4(alarm_count, 4'd1,
                     "under+Delta count exactly once");

        tick_sample(12'd3900, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b1, 1'b1, 1'b0,
                     "over and Delta together");
        check_count4(alarm_count, 4'd2,
                     "over+Delta count exactly once");

        tick_sample(12'd2000, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b1, 1'b0,
                     "Delta-only sample");
        check_count4(alarm_count, 4'd3,
                     "Delta-only count once");

        tick_sample(12'd2050, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "fully normal sample clears sample alarms");
        check_count4(alarm_count, 4'd3,
                     "normal sample leaves alarm_count");

        // ---------------------------------------------------------------------
        // TEST 6: min/max/current statistics and enable behavior
        // ---------------------------------------------------------------------
        $display("\n--- TEST 6: statistics retention across disable ---");
        apply_clear();
        low_threshold      = 12'd0;
        high_threshold     = 12'd4095;
        max_delta          = 12'd4095;
        stale_limit_cycles = 32'd3;

        tick_sample(12'd2000, 1'b1, 1'b0);
        tick_sample(12'd1000, 1'b1, 1'b0);
        tick_sample(12'd3000, 1'b1, 1'b0);
        check_u12(current_adc, 12'd3000, "stats current");
        check_u12(min_adc,     12'd1000, "stats min");
        check_u12(max_adc,     12'd3000, "stats max");
        check_count4(sample_count, 4'd3, "stats sample_count");

        tick_idle(1'b0, 1'b0);
        check_bit(data_seen, 1'b0, "disable clears data_seen");
        check_bit(display_valid, 1'b0, "disable clears display_valid");
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "disable clears monitoring alarms");
        check_u12(current_adc, 12'd3000, "disable retains current");
        check_u12(min_adc,     12'd1000, "disable retains min");
        check_u12(max_adc,     12'd3000, "disable retains max");
        check_u12(last_delta,  12'd0,    "disable invalidates last Delta");
        check_count4(sample_count, 4'd3,
                     "disable retains sample_count");
        check_count4(alarm_count, 4'd0,
                     "disable retains alarm_count");

        tick_sample(12'd100, 1'b0, 1'b0);
        check_u12(current_adc, 12'd3000,
                  "disabled adc_valid ignored current");
        check_bit(data_seen, 1'b0,
                  "disabled adc_valid does not set data_seen");
        check_u12(min_adc, 12'd1000,
                  "disabled adc_valid ignored min");
        check_count4(sample_count, 4'd3,
                     "disabled adc_valid ignored count");

        for (loop_index = 0; loop_index < 5; loop_index = loop_index + 1)
            tick_idle(1'b1, 1'b0);

        check_bit(data_seen, 1'b0,
                  "re-enable starts with data_seen clear");
        check_bit(display_valid, 1'b0,
                  "re-enable requires a new first sample");
        check_bit(stale_alarm, 1'b0,
                  "re-enable does not stale before new first sample");

        max_delta = 12'd10;
        tick_sample(12'd3500, 1'b1, 1'b0);
        check_u12(last_delta, 12'd0,
                  "first sample after re-enable skips Delta");
        check_bit(data_seen, 1'b1,
                  "first sample after re-enable sets data_seen");
        check_bit(delta_alarm, 1'b0,
                  "old session sample not used as Delta baseline");
        check_u12(min_adc, 12'd1000,
                  "re-enable preserves lifetime min");
        check_u12(max_adc, 12'd3500,
                  "re-enable updates lifetime max");
        check_count4(sample_count, 4'd4,
                     "re-enabled sample increments count");

        tick_sample(12'd3520, 1'b1, 1'b0);
        check_u12(last_delta, 12'd20,
                  "second sample after re-enable computes Delta");
        check_bit(delta_alarm, 1'b1,
                  "second sample after re-enable can alarm");

        // ---------------------------------------------------------------------
        // TEST 7: Stale behavior and display_valid level
        // ---------------------------------------------------------------------
        $display("\n--- TEST 7: Stale timing, recovery and re-entry ---");
        apply_clear();
        low_threshold      = 12'd0;
        high_threshold     = 12'd4095;
        max_delta          = 12'd4095;
        stale_limit_cycles = 32'd3;

        for (loop_index = 0; loop_index < 5; loop_index = loop_index + 1)
            tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b0,
                  "Stale blocked before first sample");
        check_count4(alarm_count, 4'd0,
                     "no pre-first-sample Stale count");

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_bit(data_seen, 1'b1,
                  "Stale baseline sample sets data_seen");
        check_bit(display_valid, 1'b1,
                  "display valid after Stale baseline sample");

        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b0, "Stale idle 1 of 3");
        check_bit(display_valid, 1'b1, "display valid idle 1");

        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b0, "Stale idle 2 of 3");
        check_bit(display_valid, 1'b1, "display valid idle 2");

        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b1, "Stale asserts idle 3 of 3");
        check_bit(data_seen, 1'b1,
                  "Stale does not erase session data_seen");
        check_bit(display_valid, 1'b0, "Stale invalidates display");
        check_count4(alarm_count, 4'd1,
                     "Stale entry increments alarm_count once");

        tick_idle(1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b1, "Stale remains asserted");
        check_count4(alarm_count, 4'd1,
                     "Stale duration does not recount");

        tick_sample(12'd1001, 1'b1, 1'b0);
        check_bit(data_seen, 1'b1,
                  "Stale recovery keeps data_seen set");
        check_bit(stale_alarm, 1'b0, "new sample clears Stale");
        check_bit(display_valid, 1'b1,
                  "new sample restores display_valid");
        check_count4(alarm_count, 4'd1,
                     "Stale recovery does not alter count");

        tick_idle(1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b1, "Stale can re-enter");
        check_count4(alarm_count, 4'd2,
                     "second Stale entry increments once");

        tick_idle(1'b0, 1'b0);
        check_bit(data_seen, 1'b0, "disable clears Stale-session data_seen");
        check_bit(stale_alarm, 1'b0, "disable clears Stale state");
        check_bit(display_valid, 1'b0, "disable keeps display invalid");
        check_count4(alarm_count, 4'd2,
                     "disable retains Stale history count");

        for (loop_index = 0; loop_index < 5; loop_index = loop_index + 1)
            tick_idle(1'b1, 1'b0);
        check_bit(data_seen, 1'b0,
                  "re-enabled session has no data_seen before sample");
        check_bit(stale_alarm, 1'b0,
                  "re-enabled session waits for first sample");

        // stale_limit_cycles=0 disables Stale monitoring.
        apply_clear();
        stale_limit_cycles = 32'd0;
        tick_sample(12'd1000, 1'b1, 1'b0);
        for (loop_index = 0; loop_index < 6; loop_index = loop_index + 1)
            tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b0, "Stale limit zero disables Stale");
        check_bit(display_valid, 1'b1,
                  "display remains valid with Stale disabled");
        check_count4(alarm_count, 4'd0,
                     "disabled Stale does not count");

        // stale_limit_cycles=1 asserts on the first no-sample clock.
        apply_clear();
        stale_limit_cycles = 32'd1;
        tick_sample(12'd1000, 1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        check_bit(stale_alarm, 1'b1,
                  "Stale limit one asserts first idle clock");
        check_count4(alarm_count, 4'd1,
                     "Stale limit one counts once");

        // A sample on the would-be timeout clock must cancel the timeout.
        apply_clear();
        stale_limit_cycles = 32'd3;
        tick_sample(12'd1000, 1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        tick_idle(1'b1, 1'b0);
        tick_sample(12'd1100, 1'b1, 1'b0);
        check_bit(stale_alarm, 1'b0,
                  "sample on timeout boundary prevents Stale");
        check_count4(alarm_count, 4'd0,
                     "cancelled Stale does not count");

        // ---------------------------------------------------------------------
        // TEST 8: runtime threshold changes are sample-qualified
        // ---------------------------------------------------------------------
        $display("\n--- TEST 8: runtime threshold changes ---");
        apply_clear();
        stale_limit_cycles = 32'd0;
        low_threshold      = 12'd410;
        high_threshold     = 12'd3685;
        max_delta          = 12'd4095;

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_bit(under_alarm, 1'b0, "initial threshold normal");

        low_threshold = 12'd1500;
        tick_idle(1'b1, 1'b0);
        check_bit(under_alarm, 1'b0,
                  "threshold change alone does not reclassify stored sample");

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_bit(under_alarm, 1'b1,
                  "new valid sample uses updated threshold");
        check_count4(alarm_count, 4'd1,
                     "updated-threshold alarm counted");

        low_threshold = 12'd410;
        tick_idle(1'b1, 1'b0);
        check_bit(under_alarm, 1'b1,
                  "last sample alarm held until next valid sample");

        tick_sample(12'd1000, 1'b1, 1'b0);
        check_bit(under_alarm, 1'b0,
                  "next normal sample clears last sample alarm");
        check_count4(alarm_count, 4'd1,
                     "normal reclassification does not recount");

        // ---------------------------------------------------------------------
        // TEST 9: saturating sample_count and alarm_count
        // ---------------------------------------------------------------------
        $display("\n--- TEST 9: counter saturation ---");
        apply_clear();
        low_threshold      = 12'd0;
        high_threshold     = 12'd4095;
        max_delta          = 12'd4095;
        stale_limit_cycles = 32'd0;

        for (loop_index = 0; loop_index < 20; loop_index = loop_index + 1)
            tick_sample(12'd1000, 1'b1, 1'b0);

        check_count4(sample_count, 4'd15,
                     "sample_count saturates at maximum");
        check_count4(alarm_count, 4'd0,
                     "normal samples leave alarm_count zero");

        apply_clear();
        low_threshold  = 12'd1000;
        high_threshold = 12'd4095;
        max_delta      = 12'd4095;

        for (loop_index = 0; loop_index < 20; loop_index = loop_index + 1)
            tick_sample(12'd500, 1'b1, 1'b0);

        check_count4(sample_count, 4'd15,
                     "sample_count remains saturated");
        check_count4(alarm_count, 4'd15,
                     "alarm_count saturates at maximum");
        check_bit(under_alarm, 1'b1,
                  "last abnormal sample alarm still reflects sample");

        tick_sample(12'd1500, 1'b1, 1'b0);
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "normal sample clears alarm after saturation");
        check_count4(sample_count, 4'd15,
                     "sample_count does not wrap after saturation");
        check_count4(alarm_count, 4'd15,
                     "alarm_count does not wrap after saturation");

        // ---------------------------------------------------------------------
        // TEST 10: asynchronous reset during active operation
        // ---------------------------------------------------------------------
        $display("\n--- TEST 10: asynchronous reset during operation ---");
        apply_clear();
        low_threshold      = 12'd410;
        high_threshold     = 12'd3685;
        max_delta          = 12'd100;
        stale_limit_cycles = 32'd3;

        tick_sample(12'd1000, 1'b1, 1'b0);
        tick_sample(12'd300, 1'b1, 1'b0);
        check_bit(sensor_alarm, 1'b1,
                  "pre-reset active alarm exists");
        check_count4(sample_count, 4'd2,
                     "pre-reset samples exist");

        @(negedge clk);
        #2;
        reset_p = 1'b1;
        #1;
        check_u12(current_adc, 12'd0, "async reset current");
        check_u12(min_adc,     12'd0, "async reset min");
        check_u12(max_adc,     12'd0, "async reset max");
        check_u12(last_delta,  12'd0, "async reset last Delta");
        check_bit(data_seen,     1'b0, "async reset data_seen");
        check_bit(display_valid, 1'b0, "async reset display invalid");
        check_alarms(1'b0, 1'b0, 1'b0, 1'b0,
                     "async reset alarms");
        check_count4(sample_count, 4'd0, "async reset sample_count");
        check_count4(alarm_count,  4'd0, "async reset alarm_count");

        @(negedge clk);
        reset_p  = 1'b0;
        enable   = 1'b0;
        clear    = 1'b0;
        adc_valid = 1'b0;
        @(posedge clk);
        #1;

        // ---------------------------------------------------------------------
        // Final report
        // ---------------------------------------------------------------------
        $display("\n============================================================");
        $display(" Checks executed : %0d", check_count);
        $display(" Failures        : %0d", fail_count);

        if (fail_count == 0) begin
            $display(" RESULT          : ALL TESTS PASSED");
            $display(" SENSOR_GUARD_CORE TEST PASS");
        end
        else begin
            $display(" RESULT          : TEST FAILED");
        end

        $display("============================================================");
        $finish;
    end

endmodule