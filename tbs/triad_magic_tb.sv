// tbs/triad_magic_tb.sv
// Top-level testbench for triad_magic.
//
// MCP3204 behavioural model:
//   Responds to the real 3-byte SPI protocol on each CS assertion.
//   Returns the current sweep value for the requested channel.
//   Protocol: 24 clocks per transaction.
//     TX: 0x06, {ch[1:0], 6'b0}, 0x00
//     RX byte 1: don't care
//     RX byte 2: {4'bx, null_bit=0, data[11:9]}  — top 3 bits of result
//     RX byte 3: data[8:0] padded — bottom 9 bits (we only use [8:1] = [7:0])
//   adc_reader captures rx_byte2[3:0] as high nibble and rx_byte3[7:4]
//   as low nibble giving top 8 bits of a 12-bit result.
//
// Sweep:
//   All four pots sweep simultaneously from 0 to 4095 in 32 equal steps.
//   Each step holds for HOLD_CYCLES to allow the chord_channel sequencer
//   to complete several full program cycles and update the display.
//   Step size = 4096 / 32 = 128.

`timescale 1ns/1ps

module triad_magic_tb;

// ── Clock and reset ───────────────────────────────────────────────────────
localparam CLK_PERIOD = 10;  // 100MHz = 10ns period

reg clk     = 0;
reg pin_rst_n = 0;

always #(CLK_PERIOD/2) clk = ~clk;

// Release reset after 20 cycles
initial begin
    repeat(20) @(posedge clk);
    pin_rst_n = 1;
end

// ── DUT wires ─────────────────────────────────────────────────────────────
wire OLED_SCLK, OLED_MOSI, OLED_CS_N, OLED_DC, OLED_RST_N;
wire ADC_SCLK,  ADC_MOSI,  ADC_CS_N;
wire [7:0] led;
reg  ADC_MISO = 1;  // default high (idle)

triad_magic #(
    .SSD1306_CLK_DIV (5),
    .MCP3204_CLK_DIV (50),
    .TESTBUS_SEL     (1)   // watch display_driver state on LEDs
) dut (
    .clk        (clk),
    .pin_rst_n  (pin_rst_n),
    .OLED_SCLK  (OLED_SCLK),
    .OLED_MOSI  (OLED_MOSI),
    .OLED_CS_N  (OLED_CS_N),
    .OLED_DC    (OLED_DC),
    .OLED_RST_N (OLED_RST_N),
    .ADC_SCLK   (ADC_SCLK),
    .ADC_MOSI   (ADC_MOSI),
    .ADC_MISO   (ADC_MISO),
    .ADC_CS_N   (ADC_CS_N),
    .led        (led)
);

// ── Sweep state ───────────────────────────────────────────────────────────
// 32 steps across 0-4095, all four pots sweep the same value simultaneously.
// Differentiate channels by offsetting: ch0=val, ch1=val+341, ch2=val+682, ch3=val+1023
// (offsets wrap mod 4096 so all channels are always in range)
localparam SWEEP_STEPS  = 33;
localparam SWEEP_INC    = 4020 / SWEEP_STEPS;  // 128
localparam HOLD_CYCLES  = 500_000;              // 5ms at 100MHz — several program cycles

int  sweep_step  = 0;
logic [11:0] sweep_val = 0;

// ── MCP3204 behavioural model ─────────────────────────────────────────────
// Monitors ADC_SCLK, ADC_MOSI, ADC_CS_N.
// Drives ADC_MISO with the correct 12-bit response.
//
// Transaction structure (24 SCK edges):
//   Bits 0-7  (byte 1 RX/TX): leading zeros + start bit — we watch for start
//   Bits 8-15 (byte 2 RX/TX): channel select arrives on MOSI[7:6]
//   Bits 16-23(byte 3 RX/TX): don't care TX; we shift out result[3:0] + padding
//
// MISO response alignment (per MCP3204 datasheet Figure 6-1):
//   After start bit detected, null bit then B11..B0 MSB first.
//   Null bit lands at bit 12 of the 24-bit frame (byte 2 bit 4).
//   B11..B8 land in byte 2 bits [3:0].
//   B7..B0  land in byte 3 bits [7:0].
//
// We pre-load a 24-bit shift register on CS falling edge and clock it out.

logic [23:0] miso_shift;
logic [7:0]  rx_shift;
logic [1:0]  rx_channel;
int          bit_count;
logic [11:0] adc_val;

// Compute the sweep value for a given channel with offset
function automatic logic [11:0] ch_val;
    input [1:0] ch;
    logic [13:0] v;
    begin
        v = sweep_val + (ch * 341);
        ch_val = v[11:0];  // wrap mod 4096
    end
endfunction

// Build the 24-bit MISO response frame for a given 12-bit ADC value.
// Frame layout (what the slave shifts out MSB first):
//   [23:13] = don't care (11 bits, received as byte1 + byte2[7:5])
//   [12]    = null bit (0)
//   [11:0]  = adc result MSB first
function automatic logic [23:0] build_miso_frame;
    input [11:0] val;
    begin
        build_miso_frame = {12'b0, 1'b0, val};  // null + 12 data bits, top 11 don't care
    end
endfunction

// MCP3204 model — runs as a continuous process watching CS
initial begin
    ADC_MISO  = 1;
    bit_count = 0;
    rx_shift  = 0;

    forever begin
        // Wait for CS to go low (transaction start)
        @(negedge ADC_CS_N);
        bit_count  = 0;
        rx_shift   = 0;
        rx_channel = 0;
        miso_shift = 24'b0;

        // Clock in all 24 bits
        repeat(24) begin
            @(posedge ADC_SCLK);
            // Sample MOSI on rising edge
            rx_shift = {rx_shift[6:0], ADC_MOSI};
            bit_count = bit_count + 1;

            // After byte 2 arrives (16 bits in) we know the channel
            if (bit_count == 16) begin
                rx_channel = rx_shift[7:6];  // channel in top two bits of byte 2
                adc_val    = ch_val(rx_channel);
                miso_shift = build_miso_frame(adc_val);
            end

            // Drive MISO on falling edge — data valid before next rising edge
            @(negedge ADC_SCLK);
            // Shift out MISO MSB first, aligned so null bit and data land correctly
            // miso_shift[23] is the first bit out — counts down as bit_count goes up
            ADC_MISO = miso_shift[23 - bit_count];
        end

        // Wait for CS to go high, then idle MISO
        @(posedge ADC_CS_N);
        ADC_MISO = 1;
    end
end

// ── Sweep driver ──────────────────────────────────────────────────────────
// Advances sweep_val every HOLD_CYCLES, loops forever.
initial begin
    sweep_val  = 0;
    sweep_step = 0;

    // Wait for reset to release and display init to settle
    @(posedge pin_rst_n);
    repeat(200) @(posedge clk);

    forever begin
        // Hold current value for enough cycles for sequencer to run several loops
        repeat(HOLD_CYCLES) @(posedge clk);

        sweep_step = sweep_step + 1;
        sweep_val  = (sweep_step * SWEEP_INC) % 4096;

        $display("[TB] sweep step %0d — val=0x%03X (%0d)",
                 sweep_step, sweep_val, sweep_val);

        // After one full sweep, stop
        if (sweep_step == SWEEP_STEPS) begin
            $display("[TB] sweep complete — finishing simulation");
            repeat(HOLD_CYCLES) @(posedge clk);
            $finish;
        end
    end
end

// ── Waveform dump ─────────────────────────────────────────────────────────
initial begin
    $dumpfile("waves/triad_magic.vcd");
    $dumpvars(0, triad_magic_tb);
end

// ── Timeout watchdog ──────────────────────────────────────────────────────
// Catches hangs — if simulation runs longer than expected, abort.
// 32 steps * 500k cycles * 10ns = 160ms simulated = ~160M cycles
localparam TIMEOUT_CYCLES = 200_000_000;

initial begin
    repeat(TIMEOUT_CYCLES) @(posedge clk);
    $display("[TB] TIMEOUT — simulation exceeded %0d cycles", TIMEOUT_CYCLES);
    $finish;
end

// ── Signal monitors ───────────────────────────────────────────────────────
// Print key events to transcript so you can correlate with waveforms

// ADC CS assertion — marks start of each ADC transaction
always @(negedge ADC_CS_N)
    $display("[ADC] CS asserted  t=%0t", $time);

always @(posedge ADC_CS_N)
    $display("[ADC] CS deasserted t=%0t  MISO_last=%b", $time, ADC_MISO);

// LED changes — testbus activity
always @(led)
    $display("[LED] testbus=0x%02X  t=%0t", led, $time);

// OLED CS — marks display SPI transactions
always @(negedge OLED_CS_N)
    $display("[OLED] CS asserted  t=%0t", $time);

endmodule
