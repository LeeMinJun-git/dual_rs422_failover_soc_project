`timescale 1ns / 1ps

module voltage_display_bcd (
    input  wire [11:0] millivolt,
    output reg  [3:0]  digit3,
    output reg  [3:0]  digit2,
    output reg  [3:0]  digit1,
    output reg  [3:0]  digit0
);

    reg [27:0] shift_register;
    integer index;

    always @(*) begin
        shift_register       = 28'd0;
        shift_register[11:0] = millivolt;

        // Twelve-bit combinational Double-Dabble conversion.
        for (index = 0; index < 12; index = index + 1) begin
            if (shift_register[15:12] >= 4'd5)
                shift_register[15:12] =
                    shift_register[15:12] + 2'd3;
            if (shift_register[19:16] >= 4'd5)
                shift_register[19:16] =
                    shift_register[19:16] + 2'd3;
            if (shift_register[23:20] >= 4'd5)
                shift_register[23:20] =
                    shift_register[23:20] + 2'd3;
            if (shift_register[27:24] >= 4'd5)
                shift_register[27:24] =
                    shift_register[27:24] + 2'd3;
            shift_register = shift_register << 1;
        end

        digit3 = shift_register[27:24];
        digit2 = shift_register[23:20];
        digit1 = shift_register[19:16];
        digit0 = shift_register[15:12];
    end

endmodule
