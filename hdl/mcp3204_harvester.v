module mcp3204_harvester #(
    parameter CLK_DIV   = 50,
    parameter NUM_CHIPS = 1
)(
    // Wishbone slave
    input  wire        wb_clk,
    input  wire        wb_rst,
    input  wire        wb_cyc,
    input  wire        wb_stb,
    input  wire        wb_we,
    input  wire [3:0]  wb_adr,
    input  wire [7:0]  wb_wdat,
    output reg  [7:0]  wb_rdat,
    output reg         wb_ack,

    // SPI bus (shared across all chips)
    output wire        spi_clk,
    output wire        spi_mosi,
    input  wire        spi_miso,

    // CS lines, one per chip, only NUM_CHIPS bits used
    output reg  [15:0] spi_cs_n
);

// ── Address map ───────────────────────────────────────────────────
localparam REG_STATUS_ADDR      = 4'h0;
localparam REG_READ_CHIP_ADDR   = 4'h1;
localparam REG_CH0_RAW_HI_ADDR  = 4'h2;
localparam REG_CH0_RAW_LO_ADDR  = 4'h3;
localparam REG_CH1_RAW_HI_ADDR  = 4'h4;
localparam REG_CH1_RAW_LO_ADDR  = 4'h5;
localparam REG_CH2_RAW_HI_ADDR  = 4'h6;
localparam REG_CH2_RAW_LO_ADDR  = 4'h7;
localparam REG_CH3_RAW_HI_ADDR  = 4'h8;
localparam REG_CH3_RAW_LO_ADDR  = 4'h9;

// ── Wishbone registers ────────────────────────────────────────────
reg [7:0] reg_status;           // bit7=busy, bit6=scan_complete, 5:0 reserved
reg [7:0] reg_read_chip;        // which chip's results are windowed for reads

// Result register file: [chip][channel][hi=0/lo=1]
reg [7:0] reg_raw [0:(NUM_CHIPS-1)][0:3][0:1];

// ── Internal scan state ───────────────────────────────────────────
reg [3:0] scan_chip;            // which chip we're currently converting
reg [1:0] scan_chan;            // which channel we're currently converting
reg       scan_complete;        // pulses when all chips+channels done

// ── SPI clock generation ──────────────────────────────────────────
reg [$clog2(CLK_DIV)-1:0] clk_cnt;
reg                        spi_clk_r;
reg                        busy;

wire spi_rising  = (clk_cnt == CLK_DIV/2 - 1);
wire spi_falling = (clk_cnt == CLK_DIV   - 1);

always @(posedge wb_clk) begin
    if (wb_rst) begin
        clk_cnt   <= 0;
        spi_clk_r <= 0;
    end else if (busy) begin
        clk_cnt <= clk_cnt + 1;
        if (spi_rising)  spi_clk_r <= 1;
        if (spi_falling) begin
            spi_clk_r <= 0;
            clk_cnt   <= 0;
        end
    end else begin
        clk_cnt   <= 0;
        spi_clk_r <= 0;
    end
end

assign spi_clk = spi_clk_r;

// ── Shift registers ───────────────────────────────────────────────
reg [23:0] tx_shift;
reg [23:0] rx_shift;
reg  [4:0] bit_cnt;

// TX word for current scan_chip/scan_chan
// MCP3204: 00001 1 D1 D0 + 16 don't-care bits
wire [23:0] tx_word = {
    5'b00001,       // leading zeros + start bit
    1'b1,           // SGL = single ended
    scan_chan[1],   // D2 (always 0 for 4-ch device, but use chan MSB)
    scan_chan[0],   // D1
    1'b0,           // D0
    15'b0           // don't care clocking bits
};

// ── Main FSM ──────────────────────────────────────────────────────
localparam ST_IDLE     = 2'd0;
localparam ST_CS_LOW   = 2'd1;
localparam ST_SHIFT    = 2'd2;
localparam ST_CS_HIGH  = 2'd3;

reg [1:0] state;

always @(posedge wb_clk) begin
    if (wb_rst) begin
        state         <= ST_IDLE;
        busy          <= 0;
        scan_chip     <= 0;
        scan_chan     <= 0;
        scan_complete <= 0;
        spi_cs_n      <= 16'hFFFF;
        bit_cnt       <= 0;
        rx_shift      <= 0;
        tx_shift      <= 0;
    end else begin
        scan_complete <= 0;  // default: no strobe

        case (state)

            ST_IDLE: begin
                spi_cs_n <= 16'hFFFF;
                busy     <= 0;
                // immediately kick off next conversion
                state    <= ST_CS_LOW;
            end

            ST_CS_LOW: begin
                spi_cs_n             <= 16'hFFFF;
                spi_cs_n[scan_chip]  <= 1'b0;
                tx_shift             <= tx_word;
                rx_shift             <= 0;
                bit_cnt              <= 0;
                busy                 <= 1;
                state                <= ST_SHIFT;
            end

            ST_SHIFT: begin
                if (spi_falling) begin
                    tx_shift <= {tx_shift[22:0], 1'b0};
                    bit_cnt  <= bit_cnt + 1;
                    if (bit_cnt == 5'd23)
                        state <= ST_CS_HIGH;
                end
                if (spi_rising) begin
                    rx_shift <= {rx_shift[22:0], spi_miso};
                end
            end

            ST_CS_HIGH: begin
                spi_cs_n <= 16'hFFFF;
                busy     <= 0;

                // latch result into register file
                // null bit at rx_shift[12], result in rx_shift[11:0]
                reg_raw[scan_chip][scan_chan][0] <= rx_shift[11:4]; // hi byte
                reg_raw[scan_chip][scan_chan][1] <= {rx_shift[3:0], 4'b0}; // lo byte

                // advance scan position
                if (scan_chan == 2'd3) begin
                    scan_chan <= 0;
                    if (scan_chip == NUM_CHIPS - 1) begin
                        scan_chip     <= 0;
                        scan_complete <= 1;  // full sweep done
                    end else begin
                        scan_chip <= scan_chip + 1;
                    end
                end else begin
                    scan_chan <= scan_chan + 1;
                end

                state <= ST_IDLE;
            end

            default: state <= ST_IDLE;

        endcase
    end
end

assign spi_mosi = tx_shift[23];

// ── Status register maintenance ───────────────────────────────────
always @(posedge wb_clk) begin
    if (wb_rst) begin
        reg_status    <= 8'h00;
        reg_read_chip <= 8'h00;
    end else begin
        reg_status <= {busy, scan_complete, 6'b0};
    end
end

// ── Wishbone interface ────────────────────────────────────────────
wire [3:0] read_chip = reg_read_chip[3:0];

always @(posedge wb_clk) begin
    wb_ack  <= 0;
    wb_rdat <= 8'hFF;

    if (wb_rst) begin
        reg_read_chip <= 8'h00;
    end else if (wb_cyc && wb_stb && !wb_ack) begin
        wb_ack <= 1;

        if (wb_we) begin
            case (wb_adr)
                REG_READ_CHIP_ADDR: reg_read_chip <= wb_wdat;
                default: ;
            endcase
        end else begin
            case (wb_adr)
                REG_STATUS_ADDR:     wb_rdat <= reg_status;
                REG_READ_CHIP_ADDR:  wb_rdat <= reg_read_chip;
                REG_CH0_RAW_HI_ADDR: wb_rdat <= reg_raw[read_chip][0][0];
                REG_CH0_RAW_LO_ADDR: wb_rdat <= reg_raw[read_chip][0][1];
                REG_CH1_RAW_HI_ADDR: wb_rdat <= reg_raw[read_chip][1][0];
                REG_CH1_RAW_LO_ADDR: wb_rdat <= reg_raw[read_chip][1][1];
                REG_CH2_RAW_HI_ADDR: wb_rdat <= reg_raw[read_chip][2][0];
                REG_CH2_RAW_LO_ADDR: wb_rdat <= reg_raw[read_chip][2][1];
                REG_CH3_RAW_HI_ADDR: wb_rdat <= reg_raw[read_chip][3][0];
                REG_CH3_RAW_LO_ADDR: wb_rdat <= reg_raw[read_chip][3][1];
                default:             wb_rdat <= 8'hFF;
            endcase
        end
    end
end

endmodule
