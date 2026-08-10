`timescale 1ns / 1ps

module voltage_display_convert (
    input  wire [11:0] adc_raw,
    output reg  [11:0] millivolt
);

    reg [23:0] scaled_value;
    reg [12:0] quotient_base;
    reg [12:0] quotient_correction_sum;
    reg [12:0] converted_value;

    always @(*) begin
        scaled_value = ({12'd0, adc_raw} * 24'd3300) + 24'd2047;

        // Exact constant division by 4095 without a divider.
        // Let N = H*4096 + L. Then:
        //   floor(N/4095) = H + floor((H+L)/4095).
        // In this design H+L is below 8190, so the correction is 0 or 1.
        quotient_base = {1'b0, scaled_value[23:12]};
        quotient_correction_sum =
            {1'b0, scaled_value[11:0]} + quotient_base;
        if (quotient_correction_sum >= 13'd4095)
            converted_value = quotient_base + 1'b1;
        else
            converted_value = quotient_base;

        if (converted_value > 13'd3300)
            millivolt = 12'd3300;
        else
            millivolt = converted_value[11:0];
    end

endmodule
