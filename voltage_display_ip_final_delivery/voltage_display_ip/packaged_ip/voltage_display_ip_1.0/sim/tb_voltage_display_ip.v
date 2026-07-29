`timescale 1ns / 1ps

module tb_voltage_display_ip;

    localparam integer SCAN_TICK_CYCLES = 2;

    reg         clk;
    reg         reset_p;
    reg  [11:0] current_adc;
    reg         display_valid;
    wire [3:0]  an;
    wire [6:0]  seg;
    wire        dp;

    reg  [11:0] conversion_adc;
    wire [11:0] conversion_mv;
    wire [3:0]  conversion_digit3;
    wire [3:0]  conversion_digit2;
    wire [3:0]  conversion_digit1;
    wire [3:0]  conversion_digit0;

    reg         decoder_valid;
    reg  [3:0]  decoder_digit;
    wire [3:0]  decoder_an;
    wire [6:0]  decoder_seg;
    wire        decoder_dp;
    wire        decoder_boundary;

    integer errors;
    integer index;
    integer expected_mv;
    reg [3:0] expected_digit3;
    reg [3:0] expected_digit2;
    reg [3:0] expected_digit1;
    reg [3:0] expected_digit0;

    voltage_display_ip #(
        .SCAN_TICK_CYCLES (SCAN_TICK_CYCLES)
    ) dut (
        .clk           (clk),
        .reset_p       (reset_p),
        .current_adc   (current_adc),
        .display_valid (display_valid),
        .an            (an),
        .seg           (seg),
        .dp            (dp)
    );

    voltage_display_convert u_conversion_check (
        .adc_raw   (conversion_adc),
        .millivolt (conversion_mv)
    );

    voltage_display_bcd u_bcd_check (
        .millivolt (conversion_mv),
        .digit3    (conversion_digit3),
        .digit2    (conversion_digit2),
        .digit1    (conversion_digit1),
        .digit0    (conversion_digit0)
    );

    voltage_display_scan #(
        .SCAN_TICK_CYCLES (SCAN_TICK_CYCLES)
    ) u_decoder_check (
        .clk            (clk),
        .reset_p        (reset_p),
        .display_valid  (decoder_valid),
        .digit3         (decoder_digit),
        .digit2         (decoder_digit),
        .digit1         (decoder_digit),
        .digit0         (decoder_digit),
        .an             (decoder_an),
        .seg            (decoder_seg),
        .dp             (decoder_dp),
        .frame_boundary (decoder_boundary)
    );

    always #5 clk = ~clk;

    function [6:0] expected_segment;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: expected_segment = 7'b1000000;
                4'd1: expected_segment = 7'b1111001;
                4'd2: expected_segment = 7'b0100100;
                4'd3: expected_segment = 7'b0110000;
                4'd4: expected_segment = 7'b0011001;
                4'd5: expected_segment = 7'b0010010;
                4'd6: expected_segment = 7'b0000010;
                4'd7: expected_segment = 7'b1111000;
                4'd8: expected_segment = 7'b0000000;
                4'd9: expected_segment = 7'b0010000;
                default: expected_segment = 7'b1111111;
            endcase
        end
    endfunction

    task record_error;
        input [8*120-1:0] message;
        begin
            errors = errors + 1;
            $display("ERROR: %0s at %0t", message, $time);
        end
    endtask

    task wait_main_an;
        input [3:0] expected_an;
        integer guard;
        begin
            guard = 0;
            while ((an !== expected_an) && (guard < 40)) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (an !== expected_an)
                record_error("timeout waiting for main anode");
        end
    endtask

    task wait_decoder_an;
        input [3:0] expected_an;
        integer guard;
        begin
            guard = 0;
            while ((decoder_an !== expected_an) && (guard < 40)) begin
                @(negedge clk);
                guard = guard + 1;
            end
            if (decoder_an !== expected_an)
                record_error("timeout waiting for decoder anode");
        end
    endtask

    task check_main_digit;
        input [3:0] expected_an;
        input [6:0] expected_seg;
        input       expected_dp;
        begin
            wait_main_an(expected_an);
            if (seg !== expected_seg)
                record_error("main segment pattern mismatch");
            if (dp !== expected_dp)
                record_error("main decimal point mismatch");
            if (!((an == 4'b1110) || (an == 4'b1101) ||
                  (an == 4'b1011) || (an == 4'b0111)))
                record_error("more or fewer than one anode active");
        end
    endtask

    task check_frame;
        input [3:0] e3;
        input [3:0] e2;
        input [3:0] e1;
        input [3:0] e0;
        input       valid_value;
        begin
            wait_main_an(4'b0111);
            wait_main_an(4'b1110);
            if (valid_value)
                check_main_digit(4'b1110, expected_segment(e0), 1'b1);
            else
                check_main_digit(4'b1110, 7'b0111111, 1'b1);
            if (valid_value)
                check_main_digit(4'b1101, expected_segment(e1), 1'b1);
            else
                check_main_digit(4'b1101, 7'b0111111, 1'b1);
            if (valid_value)
                check_main_digit(4'b1011, expected_segment(e2), 1'b1);
            else
                check_main_digit(4'b1011, 7'b0111111, 1'b1);
            if (valid_value)
                check_main_digit(4'b0111, expected_segment(e3), 1'b0);
            else
                check_main_digit(4'b0111, 7'b0111111, 1'b1);
        end
    endtask

    task apply_and_check;
        input [11:0] adc_value;
        input [3:0]  e3;
        input [3:0]  e2;
        input [3:0]  e1;
        input [3:0]  e0;
        begin
            current_adc   = adc_value;
            display_valid = 1'b1;
            check_frame(e3, e2, e1, e0, 1'b1);
        end
    endtask

    initial begin
`ifdef VOLTAGE_DISPLAY_STANDALONE_VCD
        $dumpfile("voltage_display_ip.vcd");
        $dumpvars(0, tb_voltage_display_ip);
`endif

        clk            = 1'b0;
        reset_p        = 1'b0;
        current_adc    = 12'd0;
        display_valid  = 1'b0;
        conversion_adc = 12'd0;
        decoder_valid  = 1'b1;
        decoder_digit  = 4'd0;
        errors         = 0;

        // Active-high asynchronous reset and reset output blanking.
        #3 reset_p = 1'b1;
        #1;
        if (an !== 4'b1111 || seg !== 7'b1111111 || dp !== 1'b1)
            record_error("FND outputs are not all off during reset");
        if (decoder_an !== 4'b1111 ||
            decoder_seg !== 7'b1111111 || decoder_dp !== 1'b1)
            record_error("decoder outputs are not all off during reset");

        #7 reset_p = 1'b0;

        // Invalid display, dash font and DP off.
        display_valid = 1'b0;
        check_frame(4'd0, 4'd0, 4'd0, 4'd0, 1'b0);

        // Conversion formula, saturation bound and BCD for all ADC codes.
        for (index = 0; index < 4096; index = index + 1) begin
            conversion_adc = index[11:0];
            #1;
            expected_mv = ((index * 3300) + 2047) / 4095;
            if (expected_mv > 3300)
                expected_mv = 3300;
            expected_digit3 = expected_mv / 1000;
            expected_digit2 = (expected_mv / 100) % 10;
            expected_digit1 = (expected_mv / 10) % 10;
            expected_digit0 = expected_mv % 10;
            if (conversion_mv !== expected_mv[11:0])
                record_error("ADC to millivolt conversion mismatch");
            if (conversion_mv > 12'd3300)
                record_error("millivolt saturation exceeded 3300");
            if ({conversion_digit3, conversion_digit2,
                 conversion_digit1, conversion_digit0} !==
                {expected_digit3, expected_digit2,
                 expected_digit1, expected_digit0})
                record_error("binary to BCD conversion mismatch");
        end

        conversion_adc = 12'd0;    #1;
        if ({conversion_digit3, conversion_digit2,
             conversion_digit1, conversion_digit0} !== 16'h0000)
            record_error("BCD mismatch for 0 mV");
        conversion_adc = 12'd409;  #1;
        if (conversion_mv !== 12'd330)
            record_error("ADC 409 did not convert to 330 mV");
        conversion_adc = 12'd2048; #1;
        if (conversion_mv !== 12'd1650)
            record_error("ADC 2048 did not convert to 1650 mV");
        conversion_adc = 12'd3102; #1;
        if (conversion_mv !== 12'd2500)
            record_error("ADC 3102 did not convert to 2500 mV");
        conversion_adc = 12'd4095; #1;
        if (conversion_mv !== 12'd3300)
            record_error("ADC 4095 did not convert to 3300 mV");

        // All decimal fonts, anode order, one-hot activation and DP position.
        for (index = 0; index < 10; index = index + 1) begin
            decoder_digit = index[3:0];
            decoder_valid = 1'b1;
            wait_decoder_an(4'b0111);
            wait_decoder_an(4'b1110);
            if (decoder_seg !== expected_segment(index[3:0]) ||
                decoder_dp !== 1'b1)
                record_error("digit0 font/anode/DP mismatch");
            wait_decoder_an(4'b1101);
            if (decoder_seg !== expected_segment(index[3:0]) ||
                decoder_dp !== 1'b1)
                record_error("digit1 font/anode/DP mismatch");
            wait_decoder_an(4'b1011);
            if (decoder_seg !== expected_segment(index[3:0]) ||
                decoder_dp !== 1'b1)
                record_error("digit2 font/anode/DP mismatch");
            wait_decoder_an(4'b0111);
            if (decoder_seg !== expected_segment(index[3:0]) ||
                decoder_dp !== 1'b0)
                record_error("digit3 font/anode/DP mismatch");
        end

        decoder_valid = 1'b0;
        wait_decoder_an(4'b1110);
        if (decoder_seg !== 7'b0111111 || decoder_dp !== 1'b1)
            record_error("dash pattern or invalid DP mismatch");

        // Required displayed voltages.
        apply_and_check(12'd0,    4'd0, 4'd0, 4'd0, 4'd0);
        apply_and_check(12'd409,  4'd0, 4'd3, 4'd3, 4'd0);
        apply_and_check(12'd2048, 4'd1, 4'd6, 4'd5, 4'd0);
        apply_and_check(12'd3102, 4'd2, 4'd5, 4'd0, 4'd0);
        apply_and_check(12'd4095, 4'd3, 4'd3, 4'd0, 4'd0);

        // Mid-frame ADC change: old frame must finish, next frame is all new.
        current_adc   = 12'd2048;
        display_valid = 1'b1;
        check_frame(4'd1, 4'd6, 4'd5, 4'd0, 1'b1);
        wait_main_an(4'b1110);
        check_main_digit(4'b1110, expected_segment(4'd0), 1'b1);
        wait_main_an(4'b1101);
        current_adc = 12'd4095;
        check_main_digit(4'b1101, expected_segment(4'd5), 1'b1);
        check_main_digit(4'b1011, expected_segment(4'd6), 1'b1);
        check_main_digit(4'b0111, expected_segment(4'd1), 1'b0);
        check_main_digit(4'b1110, expected_segment(4'd0), 1'b1);
        check_main_digit(4'b1101, expected_segment(4'd0), 1'b1);
        check_main_digit(4'b1011, expected_segment(4'd3), 1'b1);
        check_main_digit(4'b0111, expected_segment(4'd3), 1'b0);

        // Mid-frame valid change: no mixed frame, dashes within one frame.
        current_adc   = 12'd3102;
        display_valid = 1'b1;
        check_frame(4'd2, 4'd5, 4'd0, 4'd0, 1'b1);
        wait_main_an(4'b1110);
        check_main_digit(4'b1110, expected_segment(4'd0), 1'b1);
        wait_main_an(4'b1101);
        display_valid = 1'b0;
        check_main_digit(4'b1101, expected_segment(4'd0), 1'b1);
        check_main_digit(4'b1011, expected_segment(4'd5), 1'b1);
        check_main_digit(4'b0111, expected_segment(4'd2), 1'b0);
        check_main_digit(4'b1110, 7'b0111111, 1'b1);
        check_main_digit(4'b1101, 7'b0111111, 1'b1);
        check_main_digit(4'b1011, 7'b0111111, 1'b1);
        check_main_digit(4'b0111, 7'b0111111, 1'b1);

        // Invalid-to-valid recovery.
        current_adc   = 12'd409;
        display_valid = 1'b1;
        check_frame(4'd0, 4'd3, 4'd3, 4'd0, 1'b1);

        // Reset after operation and verify scan resumes.
        #2 reset_p = 1'b1;
        #1;
        if (an !== 4'b1111 || seg !== 7'b1111111 || dp !== 1'b1)
            record_error("asynchronous reset failed after operation");
        #4 reset_p = 1'b0;
        current_adc   = 12'd4095;
        display_valid = 1'b1;
        check_frame(4'd3, 4'd3, 4'd0, 4'd0, 1'b1);

        if (errors == 0)
            $display("VOLTAGE_DISPLAY_IP TEST PASS");
        else
            $display("VOLTAGE_DISPLAY_IP TEST FAIL: %0d error(s)", errors);

        $finish;
    end

endmodule
