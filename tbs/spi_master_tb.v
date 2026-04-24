// hdl/spi_master_tb.v
`timescale 1ns/1ps

module spi_master_tb;

   // ── DUT parameters ───────────────────────────────────────────
   localparam CLK_DIV    = 4;    // small divider for fast simulation
   localparam FIFO_DEPTH = 4;

   // ── Clock and reset ──────────────────────────────────────────
   localparam CLK_PERIOD = 10;   // 100MHz
   reg clk, rst_n;

   initial clk = 0;
   always #(CLK_PERIOD/2) clk = ~clk;

   initial begin
      rst_n = 0;
      #(CLK_PERIOD * 5);
      rst_n = 1;
   end

   // ── DUT signals ──────────────────────────────────────────────
   reg        wb_cyc, wb_stb, wb_we;
   reg  [1:0] wb_addr;
   reg  [7:0] wb_wdat;
   wire [7:0] wb_rdat;
   wire       wb_ack;
   wire       sclk, mosi, cs_n;
   reg        miso;
   // ── Expose internal signal for test 5 ────────────────────────
   wire tx_empty_wire = dut.tx_empty;


   // ── DUT instantiation ────────────────────────────────────────
   spi_master #(
      .CLK_DIV    (CLK_DIV),
      .FIFO_DEPTH (FIFO_DEPTH)
   ) dut (
      .clk      (clk),
      .rst_n    (rst_n),
      .wb_cyc   (wb_cyc),
      .wb_stb   (wb_stb),
      .wb_we    (wb_we),
      .wb_addr  (wb_addr),
      .wb_wdat  (wb_wdat),
      .wb_rdat  (wb_rdat),
      .wb_ack   (wb_ack),
      .sclk     (sclk),
      .mosi     (mosi),
      .miso     (miso),
      .cs_n     (cs_n)
   );

   // ── Wishbone write task ──────────────────────────────────────
   task wb_write;
      input [1:0] addr;
      input [7:0] data;
      begin
         @(posedge clk);
         wb_cyc  <= 1;
         wb_stb  <= 1;
         wb_we   <= 1;
         wb_addr <= addr;
         wb_wdat <= data;
         @(posedge clk);
         wait(wb_ack);
         @(posedge clk);
         wb_cyc  <= 0;
         wb_stb  <= 0;
         wb_we   <= 0;
      end
   endtask

   // ── Wishbone read task ───────────────────────────────────────
   task wb_read;
      input  [1:0] addr;
      output [7:0] data;
      begin
         @(posedge clk);
         wb_cyc  <= 1;
         wb_stb  <= 1;
         wb_we   <= 0;
         wb_addr <= addr;
         @(posedge clk);
         wait(wb_ack);
         data    = wb_rdat;
         @(posedge clk);
         wb_cyc  <= 0;
         wb_stb  <= 0;
      end
   endtask

   // ── SPI slave model ──────────────────────────────────────────
   // Captures MOSI bits and drives a known pattern back on MISO
   reg  [7:0] spi_rx_byte;
   reg  [7:0] spi_tx_byte;

   initial spi_tx_byte = 8'hA5;  // known pattern to send back

   always @(posedge sclk) begin
      spi_rx_byte = {spi_rx_byte[6:0], mosi};
   end

   // drive MISO on falling edge (Mode 0)
   integer miso_bit;
   initial miso_bit = 7;
	// drive MISO on negedge cs_n for first bit, then negedge sclk
	always @(negedge cs_n) begin
	   miso_bit = 7;
	   miso     = spi_tx_byte[7];  // pre-drive MSB when CS asserts
	end
	
	always @(negedge sclk) begin
	   if (!cs_n && miso_bit > 0) begin
	      miso_bit = miso_bit - 1;
	      miso     = spi_tx_byte[miso_bit];
	   end
	end
	
	always @(posedge cs_n) begin
	   miso = 0;
	end
   // ── Test stimulus ────────────────────────────────────────────
   reg [7:0] read_data;
   reg [7:0] status;

   initial begin
      // initialise wishbone
      wb_cyc  = 0;
      wb_stb  = 0;
      wb_we   = 0;
      wb_addr = 0;
      wb_wdat = 0;
      miso    = 0;

      // wait for reset
      wait(rst_n);
      @(posedge clk);

      // ── Test 1: check reset state of status register ─────────
      $display("\n--- Test 1: status register after reset ---");
      wb_read(2'b10, status);
      $display("Status = 0x%0h (expect 0x02 = tx_empty set)", status);
      if (status[0] !== 1'b1)
         $error("FAIL: tx_empty should be set after reset");
      else
         $display("PASS: tx_empty set");

      // ── Test 2: write a byte to TX FIFO and watch SPI ────────
      $display("\n--- Test 2: write 0xC3 to TX FIFO ---");
      wb_write(2'b00, 8'hC3);
      $display("Wrote 0xC3 to TX FIFO");

      // wait for SPI transfer to complete (cs_n goes high again)
      wait(!cs_n);
      $display("CS asserted, transfer started");
      wait(cs_n);
      $display("CS deasserted, transfer complete");
      $display("SPI slave received: 0x%0h (expect 0xC3)", spi_rx_byte);
      if (spi_rx_byte !== 8'hC3)
         $error("FAIL: MOSI data mismatch");
      else
         $display("PASS: MOSI data correct");

      // ── Test 3: read back the byte the slave sent ─────────────
      $display("\n--- Test 3: read RX FIFO ---");
      @(posedge clk);
      wb_read(2'b01, read_data);
      $display("RX FIFO returned: 0x%0h (expect 0xA5)", read_data);
      if (read_data !== 8'hA5)
         $error("FAIL: MISO data mismatch");
      else
         $display("PASS: MISO data correct");

      // ── Test 4: fill TX FIFO to full ──────────────────────────
      $display("\n--- Test 4: fill TX FIFO ---");
      wb_write(2'b00, 8'hAA);
      wb_write(2'b00, 8'hBB);
      wb_write(2'b00, 8'hCC);
      wb_write(2'b00, 8'hDD);
      wb_read(2'b10, status);
      $display("Status after filling TX FIFO = 0x%0h (expect tx_full set)", status);
      if (status[2] !== 1'b1)
         $error("FAIL: tx_full should be set");
      else
         $display("PASS: tx_full set");

      // wait for all transfers to drain
      wait(tx_empty_wire);
      $display("TX FIFO drained");

      // ── Test 5: verify status clears after drain ──────────────
      $display("\n--- Test 5: status after drain ---");
      @(posedge clk);
      wb_read(2'b10, status);
      $display("Status = 0x%0h (expect tx_empty set)", status);
      if (status[0] !== 1'b1)
         $error("FAIL: tx_empty should be set after drain");
      else
         $display("PASS: tx_empty set after drain");

      $display("\n=== All tests complete ===");
      #(CLK_PERIOD * 20);
      $finish;
   end

   // ── Timeout watchdog ─────────────────────────────────────────
   initial begin
      #1000000;
      $error("TIMEOUT: simulation ran too long");
      $finish;
   end

   // ── Waveform dump ─────────────────────────────────────────────
   initial begin
      $dumpfile("build/spi_master_tb.vcd");
      $dumpvars(0, spi_master_tb);
   end

endmodule
