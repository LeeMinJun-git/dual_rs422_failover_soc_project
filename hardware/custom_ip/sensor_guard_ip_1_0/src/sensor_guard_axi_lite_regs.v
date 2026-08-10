`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// sensor_guard_axi_lite_regs
//
// AXI4-Lite register block for sensor_guard_core
//
// Verilog-2005
// Reset: Active-High Asynchronous
//
// Register Map
//   0x00 CONTROL       RW   bit0=enable, bit1=clear W1P
//   0x04 THRESHOLD     RW   [11:0]=low, [27:16]=high
//   0x08 MAX_DELTA     RW   [11:0]=max_delta
//   0x0C STALE_LIMIT   RW   [31:0]=stale_limit_cycles
//   0x10 CURRENT_ADC   RO   [11:0]=current_adc
//   0x14 MIN_MAX       RO   [11:0]=min_adc, [27:16]=max_adc
//   0x18 STATUS        RO   bit0=enable
//                            bit1=data_seen
//                            bit2=display_valid
//                            bit3=under_alarm
//                            bit4=over_alarm
//                            bit5=delta_alarm
//                            bit6=stale_alarm
//                            bit7=sensor_alarm
//   0x1C SAMPLE_COUNT  RO   [31:0]=sample_count
//   0x20 ALARM_COUNT   RO   [31:0]=alarm_count
//   0x24 LAST_DELTA    RO   [11:0]=last_delta
//   0x28 IP_VERSION    RO   32'h0001_0000
//////////////////////////////////////////////////////////////////////////////////

module sensor_guard_axi_lite_regs #(
    parameter integer C_S_AXI_ADDR_WIDTH      = 7,
    parameter integer C_S_AXI_DATA_WIDTH      = 32,
    parameter integer LOW_THRESHOLD_DEFAULT   = 410,
    parameter integer HIGH_THRESHOLD_DEFAULT  = 3685,
    parameter integer MAX_DELTA_DEFAULT       = 512,
    parameter integer STALE_LIMIT_DEFAULT     = 50_000_000
)(
    input  wire                              clk,
    input  wire                              reset_p,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axil_awaddr,
    input  wire                              s_axil_awvalid,
    output wire                              s_axil_awready,

    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axil_wdata,
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axil_wstrb,
    input  wire                              s_axil_wvalid,
    output wire                              s_axil_wready,

    output reg  [1:0]                        s_axil_bresp,
    output reg                               s_axil_bvalid,
    input  wire                              s_axil_bready,

    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axil_araddr,
    input  wire                              s_axil_arvalid,
    output wire                              s_axil_arready,

    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axil_rdata,
    output reg  [1:0]                        s_axil_rresp,
    output reg                               s_axil_rvalid,
    input  wire                              s_axil_rready,

    output reg                               enable,
    output reg                               clear_pulse,
    output reg  [11:0]                       low_threshold,
    output reg  [11:0]                       high_threshold,
    output reg  [11:0]                       max_delta,
    output reg  [31:0]                       stale_limit_cycles,

    input  wire [11:0]                       current_adc,
    input  wire [11:0]                       min_adc,
    input  wire [11:0]                       max_adc,
    input  wire [11:0]                       last_delta,

    input  wire                              data_seen,
    input  wire                              display_valid,
    input  wire                              under_alarm,
    input  wire                              over_alarm,
    input  wire                              delta_alarm,
    input  wire                              stale_alarm,
    input  wire                              sensor_alarm,

    input  wire [31:0]                       sample_count,
    input  wire [31:0]                       alarm_count
);

    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;

    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CONTROL      = 7'h00;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_THRESHOLD    = 7'h04;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_MAX_DELTA    = 7'h08;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STALE_LIMIT  = 7'h0C;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_CURRENT_ADC  = 7'h10;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_MIN_MAX      = 7'h14;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_STATUS       = 7'h18;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_SAMPLE_COUNT = 7'h1C;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_ALARM_COUNT  = 7'h20;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_LAST_DELTA   = 7'h24;
    localparam [C_S_AXI_ADDR_WIDTH-1:0] ADDR_IP_VERSION   = 7'h28;

    localparam [31:0] IP_VERSION_VALUE = 32'h0001_0000;

    // One-entry independent AW/W holding registers.
    reg                              aw_hold_valid;
    reg [C_S_AXI_ADDR_WIDTH-1:0]     aw_hold_addr;

    reg                              w_hold_valid;
    reg [C_S_AXI_DATA_WIDTH-1:0]     w_hold_data;
    reg [(C_S_AXI_DATA_WIDTH/8)-1:0] w_hold_strb;

    wire aw_accept;
    wire w_accept;
    wire write_have_addr;
    wire write_have_data;
    wire write_commit;

    wire [C_S_AXI_ADDR_WIDTH-1:0]     write_addr;
    wire [C_S_AXI_DATA_WIDTH-1:0]     write_data;
    wire [(C_S_AXI_DATA_WIDTH/8)-1:0] write_strb;

    assign s_axil_awready = !aw_hold_valid && !s_axil_bvalid;
    assign s_axil_wready  = !w_hold_valid  && !s_axil_bvalid;

    assign aw_accept = s_axil_awvalid && s_axil_awready;
    assign w_accept  = s_axil_wvalid  && s_axil_wready;

    assign write_have_addr = aw_hold_valid || aw_accept;
    assign write_have_data = w_hold_valid  || w_accept;
    assign write_commit = !s_axil_bvalid &&
                          write_have_addr &&
                          write_have_data;

    assign write_addr = aw_hold_valid ? aw_hold_addr : s_axil_awaddr;
    assign write_data = w_hold_valid  ? w_hold_data  : s_axil_wdata;
    assign write_strb = w_hold_valid  ? w_hold_strb  : s_axil_wstrb;

    // Read channel allows one outstanding response.
    wire read_accept;

    assign s_axil_arready = !s_axil_rvalid;
    assign read_accept = s_axil_arvalid && s_axil_arready;

    // Current writable register images.
    wire [31:0] control_current;
    wire [31:0] threshold_current;
    wire [31:0] max_delta_current;

    assign control_current = {30'd0, 1'b0, enable};
    assign threshold_current = {
        4'd0,
        high_threshold,
        4'd0,
        low_threshold
    };
    assign max_delta_current = {20'd0, max_delta};

    // WSTRB merge.
    reg [31:0] merged_control;
    reg [31:0] merged_threshold;
    reg [31:0] merged_max_delta;
    reg [31:0] merged_stale_limit;

    integer byte_index;

    always @(*) begin
        merged_control     = control_current;
        merged_threshold   = threshold_current;
        merged_max_delta   = max_delta_current;
        merged_stale_limit = stale_limit_cycles;

        for (byte_index = 0;
             byte_index < (C_S_AXI_DATA_WIDTH/8);
             byte_index = byte_index + 1) begin
            if (write_strb[byte_index]) begin
                merged_control[(byte_index*8) +: 8] =
                    write_data[(byte_index*8) +: 8];

                merged_threshold[(byte_index*8) +: 8] =
                    write_data[(byte_index*8) +: 8];

                merged_max_delta[(byte_index*8) +: 8] =
                    write_data[(byte_index*8) +: 8];

                merged_stale_limit[(byte_index*8) +: 8] =
                    write_data[(byte_index*8) +: 8];
            end
        end
    end

    // Address validation.
    reg write_addr_supported;
    reg read_addr_supported;

    always @(*) begin
        write_addr_supported = 1'b0;

        if (write_addr[1:0] == 2'b00) begin
            case (write_addr)
                ADDR_CONTROL,
                ADDR_THRESHOLD,
                ADDR_MAX_DELTA,
                ADDR_STALE_LIMIT:
                    write_addr_supported = 1'b1;

                default:
                    write_addr_supported = 1'b0;
            endcase
        end
    end

    always @(*) begin
        read_addr_supported = 1'b0;

        if (s_axil_araddr[1:0] == 2'b00) begin
            case (s_axil_araddr)
                ADDR_CONTROL,
                ADDR_THRESHOLD,
                ADDR_MAX_DELTA,
                ADDR_STALE_LIMIT,
                ADDR_CURRENT_ADC,
                ADDR_MIN_MAX,
                ADDR_STATUS,
                ADDR_SAMPLE_COUNT,
                ADDR_ALARM_COUNT,
                ADDR_LAST_DELTA,
                ADDR_IP_VERSION:
                    read_addr_supported = 1'b1;

                default:
                    read_addr_supported = 1'b0;
            endcase
        end
    end

    // Read mux.
    reg [31:0] read_data_mux;

    always @(*) begin
        read_data_mux = 32'd0;

        case (s_axil_araddr)
            ADDR_CONTROL:
                read_data_mux = control_current;

            ADDR_THRESHOLD:
                read_data_mux = threshold_current;

            ADDR_MAX_DELTA:
                read_data_mux = max_delta_current;

            ADDR_STALE_LIMIT:
                read_data_mux = stale_limit_cycles;

            ADDR_CURRENT_ADC:
                read_data_mux = {20'd0, current_adc};

            ADDR_MIN_MAX:
                read_data_mux = {
                    4'd0,
                    max_adc,
                    4'd0,
                    min_adc
                };

            ADDR_STATUS:
                read_data_mux = {
                    24'd0,
                    sensor_alarm,
                    stale_alarm,
                    delta_alarm,
                    over_alarm,
                    under_alarm,
                    display_valid,
                    data_seen,
                    enable
                };

            ADDR_SAMPLE_COUNT:
                read_data_mux = sample_count;

            ADDR_ALARM_COUNT:
                read_data_mux = alarm_count;

            ADDR_LAST_DELTA:
                read_data_mux = {20'd0, last_delta};

            ADDR_IP_VERSION:
                read_data_mux = IP_VERSION_VALUE;

            default:
                read_data_mux = 32'd0;
        endcase
    end

    // Write channel and writable registers.
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            aw_hold_valid      <= 1'b0;
            aw_hold_addr       <= {C_S_AXI_ADDR_WIDTH{1'b0}};
            w_hold_valid       <= 1'b0;
            w_hold_data        <= {C_S_AXI_DATA_WIDTH{1'b0}};
            w_hold_strb        <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};

            s_axil_bresp       <= AXI_RESP_OKAY;
            s_axil_bvalid      <= 1'b0;

            enable             <= 1'b0;
            clear_pulse        <= 1'b0;
            low_threshold      <= LOW_THRESHOLD_DEFAULT;
            high_threshold     <= HIGH_THRESHOLD_DEFAULT;
            max_delta          <= MAX_DELTA_DEFAULT;
            stale_limit_cycles <= STALE_LIMIT_DEFAULT;
        end
        else begin
            clear_pulse <= 1'b0;

            if (s_axil_bvalid && s_axil_bready)
                s_axil_bvalid <= 1'b0;

            if (aw_accept) begin
                aw_hold_valid <= 1'b1;
                aw_hold_addr  <= s_axil_awaddr;
            end

            if (w_accept) begin
                w_hold_valid <= 1'b1;
                w_hold_data  <= s_axil_wdata;
                w_hold_strb  <= s_axil_wstrb;
            end

            if (write_commit) begin
                aw_hold_valid <= 1'b0;
                w_hold_valid  <= 1'b0;

                s_axil_bvalid <= 1'b1;

                if (write_addr_supported) begin
                    s_axil_bresp <= AXI_RESP_OKAY;

                    case (write_addr)
                        ADDR_CONTROL: begin
                            enable <= merged_control[0];

                            if (write_strb[0] && write_data[1])
                                clear_pulse <= 1'b1;
                        end

                        ADDR_THRESHOLD: begin
                            low_threshold  <= merged_threshold[11:0];
                            high_threshold <= merged_threshold[27:16];
                        end

                        ADDR_MAX_DELTA: begin
                            max_delta <= merged_max_delta[11:0];
                        end

                        ADDR_STALE_LIMIT: begin
                            stale_limit_cycles <= merged_stale_limit;
                        end

                        default: begin
                        end
                    endcase
                end
                else begin
                    s_axil_bresp <= AXI_RESP_SLVERR;
                end
            end
        end
    end

    // Read response channel.
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            s_axil_rdata  <= {C_S_AXI_DATA_WIDTH{1'b0}};
            s_axil_rresp  <= AXI_RESP_OKAY;
            s_axil_rvalid <= 1'b0;
        end
        else begin
            if (s_axil_rvalid && s_axil_rready)
                s_axil_rvalid <= 1'b0;

            if (read_accept) begin
                s_axil_rvalid <= 1'b1;

                if (read_addr_supported) begin
                    s_axil_rdata <= read_data_mux;
                    s_axil_rresp <= AXI_RESP_OKAY;
                end
                else begin
                    s_axil_rdata <= {C_S_AXI_DATA_WIDTH{1'b0}};
                    s_axil_rresp <= AXI_RESP_SLVERR;
                end
            end
        end
    end

endmodule