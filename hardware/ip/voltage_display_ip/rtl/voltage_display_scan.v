`timescale 1ns / 1ps

module voltage_display_scan #(
    parameter integer SCAN_TICK_CYCLES = 100_000
)(
    input  wire       clk,
    input  wire       reset_p,
    input  wire       display_valid,
    input  wire [3:0] digit3,
    input  wire [3:0] digit2,
    input  wire [3:0] digit1,
    input  wire [3:0] digit0,
    output reg  [3:0] an,
    output reg  [6:0] seg,
    output reg        dp,
    output wire       frame_boundary
);

    reg [31:0] scan_counter;
    reg [1:0]  scan_index;
    reg [3:0]  active_digit;

    assign frame_boundary =
        (scan_index == 2'd3) &&
        ((SCAN_TICK_CYCLES <= 1) ||
         (scan_counter >= (SCAN_TICK_CYCLES - 1)));

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            scan_counter <= 32'd0;
            scan_index   <= 2'd0;
        end
        else if (SCAN_TICK_CYCLES <= 1) begin
            scan_counter <= 32'd0;
            scan_index   <= scan_index + 1'b1;
        end
        else if (scan_counter >= (SCAN_TICK_CYCLES - 1)) begin
            scan_counter <= 32'd0;
            scan_index   <= scan_index + 1'b1;
        end
        else begin
            scan_counter <= scan_counter + 1'b1;
        end
    end

    always @(*) begin
        an           = 4'b1111;
        seg          = 7'b1111111;
        dp           = 1'b1;
        active_digit = 4'd0;

        if (!reset_p) begin
            case (scan_index)
                2'd0: begin
                    an           = 4'b1110;
                    active_digit = digit0;
                end
                2'd1: begin
                    an           = 4'b1101;
                    active_digit = digit1;
                end
                2'd2: begin
                    an           = 4'b1011;
                    active_digit = digit2;
                end
                2'd3: begin
                    an           = 4'b0111;
                    active_digit = digit3;
                end
                default: begin
                    an           = 4'b1111;
                    active_digit = 4'd0;
                end
            endcase

            if (display_valid) begin
                seg = digit_to_segments(active_digit);
                if (scan_index == 2'd3)
                    dp = 1'b0;
            end
            else begin
                seg = 7'b0111111;
                dp  = 1'b1;
            end
        end
    end

    function [6:0] digit_to_segments;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: digit_to_segments = 7'b1000000;
                4'd1: digit_to_segments = 7'b1111001;
                4'd2: digit_to_segments = 7'b0100100;
                4'd3: digit_to_segments = 7'b0110000;
                4'd4: digit_to_segments = 7'b0011001;
                4'd5: digit_to_segments = 7'b0010010;
                4'd6: digit_to_segments = 7'b0000010;
                4'd7: digit_to_segments = 7'b1111000;
                4'd8: digit_to_segments = 7'b0000000;
                4'd9: digit_to_segments = 7'b0010000;
                default: digit_to_segments = 7'b1111111;
            endcase
        end
    endfunction

endmodule
