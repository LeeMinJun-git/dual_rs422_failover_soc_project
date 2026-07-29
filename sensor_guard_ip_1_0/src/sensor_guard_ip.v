`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// sensor_guard_ip
//
// Sensor Guard Custom IP integration top
//
// Verilog-2005
// Clock : 100 MHz
// Reset : Active-High Asynchronous
//
// Native data path
//   Duplicate Guard -> adc_raw / adc_valid -> sensor_guard_core
//
// AXI management path
//   MicroBlaze -> sensor_guard_axi_lite_regs -> sensor_guard_core
//
// External native outputs
//   current_adc, display_valid, sensor_alarm
//////////////////////////////////////////////////////////////////////////////////

module sensor_guard_ip #(
    parameter integer LOW_THRESHOLD_DEFAULT  = 410,
    parameter integer HIGH_THRESHOLD_DEFAULT = 3685,
    parameter integer MAX_DELTA_DEFAULT      = 512,
    parameter integer STALE_LIMIT_DEFAULT    = 50_000_000,
    parameter integer COUNTER_WIDTH          = 32
)(
    input  wire        clk,
    input  wire        reset_p,

    input  wire [11:0] adc_raw,
    input  wire        adc_valid,

    output wire [11:0] current_adc,
    output wire        display_valid,
    output wire        sensor_alarm,

    // AXI4-Lite Slave: s_axil
    input  wire [6:0]  s_axil_awaddr,
    input  wire        s_axil_awvalid,
    output wire        s_axil_awready,

    input  wire [31:0] s_axil_wdata,
    input  wire [3:0]  s_axil_wstrb,
    input  wire        s_axil_wvalid,
    output wire        s_axil_wready,

    output wire [1:0]  s_axil_bresp,
    output wire        s_axil_bvalid,
    input  wire        s_axil_bready,

    input  wire [6:0]  s_axil_araddr,
    input  wire        s_axil_arvalid,
    output wire        s_axil_arready,

    output wire [31:0] s_axil_rdata,
    output wire [1:0]  s_axil_rresp,
    output wire        s_axil_rvalid,
    input  wire        s_axil_rready
);

    // AXI register configuration outputs
    wire        guard_enable;
    wire        guard_clear_pulse;
    wire [11:0] guard_low_threshold;
    wire [11:0] guard_high_threshold;
    wire [11:0] guard_max_delta;
    wire [31:0] guard_stale_limit_cycles;

    // Core status/statistics
    wire [11:0] guard_min_adc;
    wire [11:0] guard_max_adc;
    wire [11:0] guard_last_delta;

    wire        guard_data_seen;
    wire        guard_under_alarm;
    wire        guard_over_alarm;
    wire        guard_delta_alarm;
    wire        guard_stale_alarm;

    wire [COUNTER_WIDTH-1:0] guard_sample_count;
    wire [COUNTER_WIDTH-1:0] guard_alarm_count;

    wire [31:0] guard_sample_count_axi;
    wire [31:0] guard_alarm_count_axi;

    // Counter values are always exposed as 32-bit AXI read data.
    generate
        if (COUNTER_WIDTH < 32) begin : g_counter_zero_extend
            assign guard_sample_count_axi =
                {{(32-COUNTER_WIDTH){1'b0}}, guard_sample_count};

            assign guard_alarm_count_axi =
                {{(32-COUNTER_WIDTH){1'b0}}, guard_alarm_count};
        end
        else begin : g_counter_truncate
            assign guard_sample_count_axi = guard_sample_count[31:0];
            assign guard_alarm_count_axi  = guard_alarm_count[31:0];
        end
    endgenerate

    sensor_guard_axi_lite_regs #(
        .C_S_AXI_ADDR_WIDTH     (7),
        .C_S_AXI_DATA_WIDTH     (32),
        .LOW_THRESHOLD_DEFAULT  (LOW_THRESHOLD_DEFAULT),
        .HIGH_THRESHOLD_DEFAULT (HIGH_THRESHOLD_DEFAULT),
        .MAX_DELTA_DEFAULT      (MAX_DELTA_DEFAULT),
        .STALE_LIMIT_DEFAULT    (STALE_LIMIT_DEFAULT)
    ) u_sensor_guard_axi_lite_regs (
        .clk                (clk),
        .reset_p            (reset_p),

        .s_axil_awaddr      (s_axil_awaddr),
        .s_axil_awvalid     (s_axil_awvalid),
        .s_axil_awready     (s_axil_awready),

        .s_axil_wdata       (s_axil_wdata),
        .s_axil_wstrb       (s_axil_wstrb),
        .s_axil_wvalid      (s_axil_wvalid),
        .s_axil_wready      (s_axil_wready),

        .s_axil_bresp       (s_axil_bresp),
        .s_axil_bvalid      (s_axil_bvalid),
        .s_axil_bready      (s_axil_bready),

        .s_axil_araddr      (s_axil_araddr),
        .s_axil_arvalid     (s_axil_arvalid),
        .s_axil_arready     (s_axil_arready),

        .s_axil_rdata       (s_axil_rdata),
        .s_axil_rresp       (s_axil_rresp),
        .s_axil_rvalid      (s_axil_rvalid),
        .s_axil_rready      (s_axil_rready),

        .enable             (guard_enable),
        .clear_pulse        (guard_clear_pulse),
        .low_threshold      (guard_low_threshold),
        .high_threshold     (guard_high_threshold),
        .max_delta          (guard_max_delta),
        .stale_limit_cycles (guard_stale_limit_cycles),

        .current_adc        (current_adc),
        .min_adc            (guard_min_adc),
        .max_adc            (guard_max_adc),
        .last_delta         (guard_last_delta),

        .data_seen          (guard_data_seen),
        .display_valid      (display_valid),
        .under_alarm        (guard_under_alarm),
        .over_alarm         (guard_over_alarm),
        .delta_alarm        (guard_delta_alarm),
        .stale_alarm        (guard_stale_alarm),
        .sensor_alarm       (sensor_alarm),

        .sample_count       (guard_sample_count_axi),
        .alarm_count        (guard_alarm_count_axi)
    );

    sensor_guard_core #(
        .COUNTER_WIDTH (COUNTER_WIDTH)
    ) u_sensor_guard_core (
        .clk                (clk),
        .reset_p            (reset_p),

        .enable             (guard_enable),
        .clear              (guard_clear_pulse),

        .adc_raw            (adc_raw),
        .adc_valid          (adc_valid),

        .low_threshold      (guard_low_threshold),
        .high_threshold     (guard_high_threshold),
        .max_delta          (guard_max_delta),
        .stale_limit_cycles (guard_stale_limit_cycles),

        .current_adc        (current_adc),
        .min_adc            (guard_min_adc),
        .max_adc            (guard_max_adc),
        .last_delta         (guard_last_delta),

        .data_seen          (guard_data_seen),
        .display_valid      (display_valid),

        .under_alarm        (guard_under_alarm),
        .over_alarm         (guard_over_alarm),
        .delta_alarm        (guard_delta_alarm),
        .stale_alarm        (guard_stale_alarm),
        .sensor_alarm       (sensor_alarm),

        .sample_count       (guard_sample_count),
        .alarm_count        (guard_alarm_count)
    );

endmodule