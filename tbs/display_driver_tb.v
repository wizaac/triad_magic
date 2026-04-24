`timescale 1ns/1ps
// tbs/display_driver_tb.sv
// SystemVerilog testbench for display_driver
// SPI monitor captures {dc, byte} pairs into a queue
// Checker compares against expected init sequence

module display_driver_tb;

   // ── Clock and reset ───────────────────────────────────────────
   logic clk;
   logic rst_n;

   initial clk = 0;
   always #5 clk = ~clk;   // 100MHz — 10ns period

   // ── DUT interface signals ─────────────────────────────────────
   logic        spi_sclk;
   logic        spi_mosi;
   logic        spi_cs_n;
   logic        oled_dc;
   logic        oled_rst_n;
   logic [11:0] rom_addr;
   logic        rom_en;
   logic [7:0]  rom_data;
   logic [7:0]  testbus;

   // Wishbone — tied off, we just want to watch autonomous behaviour
   logic        wb_cyc  = 0;
   logic        wb_stb  = 0;
   logic        wb_we   = 0;
   logic [7:0]  wb_addr = 0;
   logic [7:0]  wb_wdat = 0;
   logic [7:0]  wb_rdat;
   logic        wb_ack;

   // ── ROM ───────────────────────────────────────────────────────
   shared_rom rom_inst (
      .clk     (clk),
      .wb_cyc  (1'b0),
      .wb_stb  (1'b0),
      .wb_we   (1'b0),
      .wb_addr (12'h0),
      .wb_wdat (8'h0),
      .wb_rdat (),
      .wb_ack  (),
      .rd_addr (rom_addr),
      .rd_en   (rom_en),
      .rd_data (rom_data)
   );

   // ── DUT ───────────────────────────────────────────────────────
   display_driver #(
      .CLK_DIV (5)
   ) dut (
      .clk        (clk),
      .rst_n      (rst_n),
      .wb_cyc     (wb_cyc),
      .wb_stb     (wb_stb),
      .wb_we      (wb_we),
      .wb_addr    (wb_addr),
      .wb_wdat    (wb_wdat),
      .wb_rdat    (wb_rdat),
      .wb_ack     (wb_ack),
      .spi_sclk   (spi_sclk),
      .spi_mosi   (spi_mosi),
      .spi_cs_n   (spi_cs_n),
      .oled_dc    (oled_dc),
      .oled_rst_n (oled_rst_n),
      .rom_addr   (rom_addr),
      .rom_data   (rom_data),
      .rom_en     (rom_en),
      .testbus    (testbus)
   );

   // ── SPI capture queue ─────────────────────────────────────────
   // Each entry is {dc, byte} = 9 bits
   logic [8:0] captured [$];
   logic [8:0] expected_init [$];

   // ── Expected init sequence ────────────────────────────────────
   // Mirrors display_driver init_byte function exactly
   // {dc, byte} — all dc=0 (commands)
   task load_expected_init;
      expected_init = {};
      expected_init.push_back({1'b0, 8'hAE}); // display off
      expected_init.push_back({1'b0, 8'hD5}); // set display clock
      expected_init.push_back({1'b0, 8'h80}); //   divide ratio
      expected_init.push_back({1'b0, 8'hA8}); // set multiplex
      expected_init.push_back({1'b0, 8'h2F}); //   47 rows
      expected_init.push_back({1'b0, 8'hD3}); // display offset
      expected_init.push_back({1'b0, 8'h00}); //   0
      expected_init.push_back({1'b0, 8'h40}); // start line = 0
      expected_init.push_back({1'b0, 8'h8D}); // charge pump
      expected_init.push_back({1'b0, 8'h14}); //   enable
      expected_init.push_back({1'b0, 8'h20}); // addressing mode
      expected_init.push_back({1'b0, 8'h00}); //   horizontal
      expected_init.push_back({1'b0, 8'hA1}); // segment re-map
      expected_init.push_back({1'b0, 8'hC8}); // COM scan direction
      expected_init.push_back({1'b0, 8'hDA}); // COM pins config
      expected_init.push_back({1'b0, 8'h12}); //
      expected_init.push_back({1'b0, 8'h81}); // contrast
      expected_init.push_back({1'b0, 8'hCF}); //
      expected_init.push_back({1'b0, 8'hD9}); // pre-charge period
      expected_init.push_back({1'b0, 8'hF1}); //
      expected_init.push_back({1'b0, 8'hDB}); // VCOMH deselect
      expected_init.push_back({1'b0, 8'h40}); //
      expected_init.push_back({1'b0, 8'hA4}); // use GDDRAM
      expected_init.push_back({1'b0, 8'hAF}); // display ON
   endtask

   // ── SPI monitor ───────────────────────────────────────────────
   // Watches the SPI bus and reconstructs bytes from MOSI
   // Samples on rising SCLK edge (SPI mode 0)
   // Captures dc level at the time CS goes low
   // Pushes {dc_at_cs, byte} into captured queue when CS deasserts
   logic [7:0] shift_reg;
   logic [2:0] bit_count;
   logic       dc_latched;
   int         byte_count = 0;

   // Latch DC when CS goes low
   always @(negedge spi_cs_n)
      dc_latched <= oled_dc;

   // Sample MOSI on rising SCLK, MSB first
   always @(posedge spi_sclk) begin
      shift_reg <= {shift_reg[6:0], spi_mosi};
      bit_count <= bit_count + 1;
   end

   // Push completed byte when CS goes high
   always @(posedge spi_cs_n) begin
      if (bit_count == 0) begin
         // 8 bits were clocked (bit_count wraps 7->0 on 8th bit)
         captured.push_back({dc_latched, shift_reg});
         $display("[SPI] byte %0d: dc=%0b data=0x%02X",
                  byte_count, dc_latched, shift_reg);
         byte_count++;
      end
   end

   // ── Init sequence checker ─────────────────────────────────────
   task check_init_sequence;
      int errors = 0;
      int check_len;
      logic [8:0] cap, exp;

      $display("\n=== Init sequence check ===");
      $display("Expected %0d bytes, captured %0d bytes total",
               expected_init.size(), captured.size());

      check_len = (captured.size() < expected_init.size())
                  ? captured.size() : expected_init.size();

      for (int i = 0; i < check_len; i++) begin
         exp = expected_init[i];
         cap = captured[i];
         if (cap === exp) begin
            $display("[%02d] PASS  dc=%0b data=0x%02X", i, cap[8], cap[7:0]);
         end else begin
            $display("[%02d] FAIL  expected dc=%0b 0x%02X  got dc=%0b 0x%02X",
                     i, exp[8], exp[7:0], cap[8], cap[7:0]);
            errors++;
         end
      end

      if (captured.size() < expected_init.size()) begin
         $display("MISSING %0d bytes after index %0d",
                  expected_init.size() - captured.size(), captured.size()-1);
         errors++;
      end

      $display("\n=== Result: %0d error(s) in init sequence ===\n", errors);
   endtask

   // ── Stimulus ──────────────────────────────────────────────────
   // Reset timing mirrors real hardware:
   //   RESET_PULSE_CYC = 1000 cycles  (~10us)
   //   RESET_WAIT_CYC  = 10_000_000   (~100ms)
   //   Init: 24 bytes * ~100 cycles   (~2400 cycles)
   //   Root copy: 192 bytes * ~100    (~19200 cycles)
   //   Qual copy: 96 bytes  * ~100    (~9600 cycles)
   // Total budget: ~10_035_000 cycles = ~100.35ms
   // We run for 12_000_000 cycles to cover everything with margin

   localparam int RUN_CYCLES = 12_000_000;

   initial begin
      $display("=== display_driver_tb start ===");
      load_expected_init();

      // Assert reset
      rst_n = 0;
      bit_count = 0;
      shift_reg = 0;
      repeat (10) @(posedge clk);
      rst_n = 1;

      $display("Reset released at t=%0t", $time);

      // Run for enough cycles to cover reset wait + init + first two renders
      repeat (RUN_CYCLES) @(posedge clk);

      $display("\nSimulation complete at t=%0t", $time);
      $display("Total SPI bytes captured: %0d", captured.size());

      check_init_sequence();

      // Dump everything captured for manual inspection
      $display("\n=== Full capture dump ===");
      for (int i = 0; i < captured.size(); i++) begin
         $display("[%03d] dc=%0b 0x%02X", i, captured[i][8], captured[i][7:0]);
      end

      $finish;
   end

   // ── Timeout watchdog ─────────────────────────────────────────
   initial begin
      #200ms;
      $display("WATCHDOG: simulation exceeded 200ms wall time");
      $finish;
   end

endmodule
