// hdl/triad_magic.v
// Top-level module for the triad_magic project.
// One chord_channel active, three reserved for future expansion.
// Shared ROM lives here — read port passed down to chord_channel.
// All SPI pins passed straight through to physical ports.
// Testbus mux selects which module drives the LEDs — set TESTBUS_SEL
// before build to choose debug source.

module triad_magic #(
    parameter SSD1306_CLK_DIV = 5,    // 100MHz / (2*5)  = 10MHz OLED SPI
    parameter MCP3204_CLK_DIV = 50,   // 100MHz / (2*50) = 1MHz  ADC SPI
    // Testbus mux select:
    //   0 = chord_channel top-level
    //   1 = display_driver (via chord_channel passthrough)
    //   2 = adc_reader     (via chord_channel passthrough)
    parameter TESTBUS_SEL     = 1
)(
    input  wire       clk,
    input  wire       pin_rst_n,

    // OLED SPI — channel 0
    output wire       OLED_SCLK,
    output wire       OLED_MOSI,
    output wire       OLED_CS_N,
    output wire       OLED_DC,
    output wire       OLED_RST_N,

    // ADC SPI — channel 0
    output wire       ADC_SCLK,
    output wire       ADC_MOSI,
    input  wire       ADC_MISO,
    output wire       ADC_CS_N,

    // Debug LEDs
    output wire [7:0] led
);

// ── Power-on reset stretcher ──────────────────────────────────────────────
reg [7:0] por_count = 8'h00;
wire rst_n;

always @(posedge clk) begin
    if (!pin_rst_n)
        por_count <= 8'h00;
    else if (!(&por_count))
        por_count <= por_count + 1;
end

assign rst_n = &por_count;

// ── Shared ROM ────────────────────────────────────────────────────────────
// One ROM instance shared across all channels.
// Each chord_channel gets a read port. The glitch engine will eventually
// sit between the channel arbitration and this ROM.
wire [11:0] ch0_rom_addr;
wire        ch0_rom_en;
wire [7:0]  ch0_rom_data;

shared_rom rom_inst (
    .clk     (clk),
    .wb_cyc  (1'b0),
    .wb_stb  (1'b0),
    .wb_we   (1'b0),
    .wb_addr (12'h0),
    .wb_wdat (8'h0),
    .wb_rdat (),
    .wb_ack  (),
    .rd_addr (ch0_rom_addr),
    .rd_en   (ch0_rom_en),
    .rd_data (ch0_rom_data)
);

// ── Testbus wires from chord_channel ─────────────────────────────────────
wire [7:0] ch0_testbus;

// ── Testbus mux ───────────────────────────────────────────────────────────
assign led = ch0_testbus;

// ── Channel 0 ─────────────────────────────────────────────────────────────
chord_channel #(
    .SSD1306_CLK_DIV (SSD1306_CLK_DIV),
    .MCP3204_CLK_DIV (MCP3204_CLK_DIV)
) ch0 (
    .clk            (clk),
    .rst_n          (rst_n),

    // No parent wishbone yet — tied off until triad_magic needs to read
    // channel state for DAC output. chord_channel runs autonomously.
    .wb_cyc_i       (1'b0),
    .wb_stb_i       (1'b0),
    .wb_we_i        (1'b0),
    .wb_addr_i      (4'h0),
    .wb_wdat_i      (8'h0),
    .wb_rdat_o      (),
    .wb_ack_o       (),

    // OLED SPI
    .oled_sclk      (OLED_SCLK),
    .oled_mosi      (OLED_MOSI),
    .oled_cs_n      (OLED_CS_N),
    .oled_dc        (OLED_DC),
    .oled_rst_n     (OLED_RST_N),

    // ADC SPI
    .adc_sclk       (ADC_SCLK),
    .adc_mosi       (ADC_MOSI),
    .adc_miso       (ADC_MISO),
    .adc_cs_n       (ADC_CS_N),

    // Shared ROM read port
    .rom_addr       (ch0_rom_addr),
    .rom_en         (ch0_rom_en),
    .rom_data       (ch0_rom_data),

    // Testbus outputs — all exposed, mux selects which drives LEDs
    .testbus    (ch0_testbus),
    .testbus_sel(TESTBUS_SEL)

);

endmodule


