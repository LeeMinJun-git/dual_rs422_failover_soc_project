`timescale 1ns / 1ps

module voltage_display_ip #(
    parameter integer SCAN_TICK_CYCLES = 100_000
)(
    input  wire        clk,
    input  wire        reset_p,
    input  wire [11:0] current_adc,
    input  wire        display_valid,
    output wire [3:0]  an,
    output wire [6:0]  seg,
    output wire        dp
);

    reg  [11:0] frame_adc;
    reg         frame_valid;
    wire [11:0] frame_millivolt;
    wire [3:0]  digit3;
    wire [3:0]  digit2;
    wire [3:0]  digit1;
    wire [3:0]  digit0;
    wire        frame_boundary;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            frame_adc   <= 12'd0;
            frame_valid <= 1'b0;
        end
        else if (frame_boundary) begin
            frame_adc   <= current_adc;
            frame_valid <= display_valid;
        end
    end

    voltage_display_convert u_voltage_display_convert (
        .adc_raw    (frame_adc),
        .millivolt  (frame_millivolt)
    );

    voltage_display_bcd u_voltage_display_bcd (
        .millivolt (frame_millivolt),
        .digit3    (digit3),
        .digit2    (digit2),
        .digit1    (digit1),
        .digit0    (digit0)
    );

    voltage_display_scan #(
        .SCAN_TICK_CYCLES (SCAN_TICK_CYCLES)
    ) u_voltage_display_scan (
        .clk            (clk),
        .reset_p        (reset_p),
        .display_valid  (frame_valid),
        .digit3         (digit3),
        .digit2         (digit2),
        .digit1         (digit1),
        .digit0         (digit0),
        .an             (an),
        .seg            (seg),
        .dp             (dp),
        .frame_boundary (frame_boundary)
    );

endmodule
