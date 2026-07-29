`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// sensor_guard_core
//
// Role
//   Monitors only the final 12-bit ADC samples that have already passed the
//   redundant-link decision path and Duplicate Guard.
//
// Checks
//   1. Under-range : adc_raw < low_threshold
//   2. Over-range  : adc_raw > high_threshold
//   3. Delta       : abs(adc_raw - previous_adc) > max_delta
//   4. Stale       : no adc_valid for stale_limit_cycles after at least one
//                    valid sample has been received in the current enable session
//
// Key policies
//   - adc_raw is sampled only when enable=1 and adc_valid=1.
//   - Under/Over/Delta alarms describe the most recently accepted sample.
//     A following normal sample clears the corresponding alarm immediately.
//   - Stale monitoring starts only after the first valid sample of the current
//     enable session.
//   - data_seen is the current enable-session sample-seen state and is
//     exported for AXI STATUS[1].
//   - display_valid is a level: enable && data_seen && !stale_alarm.
//   - sample_count and alarm_count are saturating counters.
//   - alarm_count increments once per abnormal valid sample, even when multiple
//     sample alarms occur together, and once when entering Stale state.
//   - stale_limit_cycles=0 disables Stale monitoring.
//
// Control priority
//   reset_p > clear > !enable > valid-sample processing > stale processing
//
// Reset/Clear
//   reset_p : asynchronous, active high, clears all state/statistics.
//   clear   : synchronous one-cycle pulse, clears all state/statistics.
//   enable=0: pauses monitoring, clears the current monitoring session state,
//             but preserves current/min/max values and accumulated counters.
//
// Verilog-2005
//////////////////////////////////////////////////////////////////////////////////

module sensor_guard_core #(
    parameter integer COUNTER_WIDTH = 32
)(
    input  wire                         clk,
    input  wire                         reset_p,

    // Control from AXI register block
    input  wire                         enable,
    input  wire                         clear,

    // Final ADC sample from redundant_link_core / Duplicate Guard
    input  wire [11:0]                  adc_raw,
    input  wire                         adc_valid,

    // Programmable monitoring limits
    input  wire [11:0]                  low_threshold,
    input  wire [11:0]                  high_threshold,
    input  wire [11:0]                  max_delta,
    input  wire [31:0]                  stale_limit_cycles,

    // Latest value and lifetime statistics since reset/clear
    output reg  [11:0]                  current_adc,
    output reg  [11:0]                  min_adc,
    output reg  [11:0]                  max_adc,
    output reg  [11:0]                  last_delta,

    // Current enable-session state
    // Exported for AXI STATUS[1].
    output reg                          data_seen,

    // Value-valid state for voltage_display_ip
    output wire                         display_valid,

    // Current alarm state
    output reg                          under_alarm,
    output reg                          over_alarm,
    output reg                          delta_alarm,
    output reg                          stale_alarm,
    output wire                         sensor_alarm,

    // Saturating statistics
    output reg  [COUNTER_WIDTH-1:0]     sample_count,
    output reg  [COUNTER_WIDTH-1:0]     alarm_count
);

    localparam [COUNTER_WIDTH-1:0] COUNTER_MAX =
        {COUNTER_WIDTH{1'b1}};

    // Previous sample is valid only while data_seen=1 in the current enable session.
    reg [11:0] previous_adc;

    // Lifetime min/max validity is preserved across enable=0 and reset only by
    // reset_p or clear.
    reg        stats_initialized;

    // Number of consecutive enabled clocks without adc_valid after data_seen.
    reg [31:0] stale_counter;

    // -------------------------------------------------------------------------
    // Combinational checks for the sample presented on adc_raw
    // -------------------------------------------------------------------------
    wire [11:0] adc_delta;
    wire        under_now;
    wire        over_now;
    wire        delta_now;
    wire        sample_alarm_now;

    assign adc_delta =
        (adc_raw >= previous_adc) ?
        (adc_raw - previous_adc) :
        (previous_adc - adc_raw);

    assign under_now = (adc_raw < low_threshold);
    assign over_now  = (adc_raw > high_threshold);

    // The first sample of each enable session establishes a new Delta baseline.
    assign delta_now = data_seen && (adc_delta > max_delta);

    assign sample_alarm_now = under_now | over_now | delta_now;

    assign display_valid = enable && data_seen && !stale_alarm;

    assign sensor_alarm =
        under_alarm | over_alarm | delta_alarm | stale_alarm;

    // -------------------------------------------------------------------------
    // Sequential logic
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            current_adc       <= 12'd0;
            min_adc           <= 12'd0;
            max_adc           <= 12'd0;
            last_delta        <= 12'd0;

            previous_adc      <= 12'd0;
            data_seen         <= 1'b0;
            stats_initialized <= 1'b0;
            stale_counter     <= 32'd0;

            under_alarm       <= 1'b0;
            over_alarm        <= 1'b0;
            delta_alarm       <= 1'b0;
            stale_alarm       <= 1'b0;

            sample_count      <= {COUNTER_WIDTH{1'b0}};
            alarm_count       <= {COUNTER_WIDTH{1'b0}};
        end
        else if (clear) begin
            // Full synchronous clear. If adc_valid is high in this cycle,
            // the sample is intentionally ignored because clear has priority.
            current_adc       <= 12'd0;
            min_adc           <= 12'd0;
            max_adc           <= 12'd0;
            last_delta        <= 12'd0;

            previous_adc      <= 12'd0;
            data_seen         <= 1'b0;
            stats_initialized <= 1'b0;
            stale_counter     <= 32'd0;

            under_alarm       <= 1'b0;
            over_alarm        <= 1'b0;
            delta_alarm       <= 1'b0;
            stale_alarm       <= 1'b0;

            sample_count      <= {COUNTER_WIDTH{1'b0}};
            alarm_count       <= {COUNTER_WIDTH{1'b0}};
        end
        else if (!enable) begin
            // Disable ends the current monitoring session but preserves the
            // latest value, min/max statistics, and accumulated counters.
            previous_adc <= 12'd0;
            data_seen    <= 1'b0;
            stale_counter <= 32'd0;
            last_delta    <= 12'd0;

            under_alarm  <= 1'b0;
            over_alarm   <= 1'b0;
            delta_alarm  <= 1'b0;
            stale_alarm  <= 1'b0;
        end
        else if (adc_valid) begin
            // -------------------------------------------------------------
            // Accept one new sample
            // -------------------------------------------------------------
            current_adc  <= adc_raw;
            previous_adc <= adc_raw;
            data_seen    <= 1'b1;

            stale_counter <= 32'd0;
            stale_alarm   <= 1'b0;

            // These alarms describe this sample, not historical events.
            under_alarm <= under_now;
            over_alarm  <= over_now;
            delta_alarm <= delta_now;

            if (data_seen)
                last_delta <= adc_delta;
            else
                last_delta <= 12'd0;

            // Lifetime min/max statistics survive enable toggling.
            if (!stats_initialized) begin
                min_adc           <= adc_raw;
                max_adc           <= adc_raw;
                stats_initialized <= 1'b1;
            end
            else begin
                if (adc_raw < min_adc)
                    min_adc <= adc_raw;

                if (adc_raw > max_adc)
                    max_adc <= adc_raw;
            end

            // One accepted sample increments sample_count once.
            if (sample_count != COUNTER_MAX)
                sample_count <= sample_count + 1'b1;

            // Multiple alarms on the same sample still count as one alarm.
            if (sample_alarm_now && (alarm_count != COUNTER_MAX))
                alarm_count <= alarm_count + 1'b1;
        end
        else begin
            // -------------------------------------------------------------
            // No valid sample this clock: Stale monitoring only
            // -------------------------------------------------------------
            if (!data_seen) begin
                // Stale has no meaning until one sample has been received in
                // the current enable session.
                stale_counter <= 32'd0;
                stale_alarm   <= 1'b0;
            end
            else if (stale_limit_cycles == 32'd0) begin
                // A limit of zero disables Stale monitoring.
                stale_counter <= 32'd0;
                stale_alarm   <= 1'b0;
            end
            else if (!stale_alarm) begin
                // Assert Stale on the Nth consecutive no-sample clock, where
                // N == stale_limit_cycles.
                if (stale_counter >= (stale_limit_cycles - 1'b1)) begin
                    stale_counter <= stale_limit_cycles;
                    stale_alarm   <= 1'b1;

                    // Count only the transition into Stale, never its duration.
                    if (alarm_count != COUNTER_MAX)
                        alarm_count <= alarm_count + 1'b1;
                end
                else begin
                    stale_counter <= stale_counter + 1'b1;
                end
            end
            else begin
                // Already Stale: hold state and do not count repeatedly.
                stale_counter <= stale_counter;
                stale_alarm   <= 1'b1;
            end
        end
    end

endmodule