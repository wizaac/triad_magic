`timescale 1ns/1ps
// tbs/display_scroll_test_tb.sv
// Wrapper testbench for display_scroll_test
// Observes the sequencer state machine and wishbone transactions
// to verify root/quality cycling behaviour

module display_scroll_test_tb;

   // ── Clock and reset ───────────────────────────────────────────
   logic clk;
   logic pin_rst_n;

   initial clk = 0;
   always #5 clk = ~clk;  // 100MHz

   // ── DUT outputs ───────────────────────────────────────────────
   logic OLED_SDI;
   logic OLED_SCLK;
   logic OLED_CS;
   logic OLED_DC;
   logic OLED_RST_N;
   logic [7:0] led;

   // ── DUT instantiation ─────────────────────────────────────────
   display_scroll_test #(
      .CLK_DIV (5)
   ) dut (
      .clk        (clk),
      .pin_rst_n  (pin_rst_n),
      .OLED_SDI   (OLED_SDI),
      .OLED_SCLK  (OLED_SCLK),
      .OLED_CS    (OLED_CS),
      .OLED_DC    (OLED_DC),
      .OLED_RST_N (OLED_RST_N),
      .led        (led)
   );

   // ── Sequencer state names for display ─────────────────────────
   localparam SEQ_WAIT    = 3'd0;
   localparam SEQ_WR_ROOT = 3'd1;
   localparam SEQ_WR_QUAL = 3'd2;
   localparam SEQ_HOLD    = 3'd3;
   localparam SEQ_NEXT    = 3'd4;

   // ── Sequencer state monitor ───────────────────────────────────
   // Prints whenever seq_state or root/qual indices change
   logic [2:0] seq_state_prev;
   logic [3:0] root_prev;
   logic [2:0] qual_prev;

   always @(posedge clk) begin
      seq_state_prev <= dut.seq_state;
      root_prev      <= dut.root_idx;
      qual_prev      <= dut.qual_idx;

      if (dut.seq_state !== seq_state_prev) begin
         case (dut.seq_state)
            SEQ_WAIT:    $display("[%0t] SEQ_WAIT",    $time);
            SEQ_WR_ROOT: $display("[%0t] SEQ_WR_ROOT  root=%0d qual=%0d",
                                  $time, dut.root_idx, dut.qual_idx);
            SEQ_WR_QUAL: $display("[%0t] SEQ_WR_QUAL  root=%0d qual=%0d",
                                  $time, dut.root_idx, dut.qual_idx);
            SEQ_HOLD:    $display("[%0t] SEQ_HOLD     root=%0d qual=%0d",
                                  $time, dut.root_idx, dut.qual_idx);
            SEQ_NEXT:    $display("[%0t] SEQ_NEXT     root=%0d qual=%0d",
                                  $time, dut.root_idx, dut.qual_idx);
            default:     $display("[%0t] SEQ_???=%0d", $time, dut.seq_state);
         endcase
      end

      if (dut.root_idx !== root_prev || dut.qual_idx !== qual_prev)
         $display("[%0t] indices -> root=%0d qual=%0d",
                  $time, dut.root_idx, dut.qual_idx);
   end

   // ── Wishbone monitor ──────────────────────────────────────────
   // Prints every wishbone write to display_driver
   always @(posedge clk) begin
      if (dut.wb_cyc && dut.wb_stb && dut.wb_we && dut.wb_ack) begin
         if (dut.wb_addr == 8'h00)
            $display("[%0t] WB write root=0x%02X", $time, dut.wb_wdat);
         else if (dut.wb_addr == 8'h01)
            $display("[%0t] WB write qual=0x%02X", $time, dut.wb_wdat);
      end
   end

   // ── Display driver state monitor ─────────────────────────────
   // Prints when display driver state changes
   logic [3:0] disp_state_prev;
   always @(posedge clk) begin
      disp_state_prev <= dut.disp_testbus[7:4];
      if (dut.disp_testbus[7:4] !== disp_state_prev)
         $display("[%0t] DISP state=%0d dirty:root=%0b qual=%0b",
                  $time,
                  dut.disp_testbus[7:4],
                  dut.disp_testbus[2],
                  dut.disp_testbus[3]);
   end

   // ── Stimulus ──────────────────────────────────────────────────
   // Run long enough to see:
   //   POR stretch (256 cycles)
   //   OLED reset pulse (1000 cycles)
   //   OLED reset wait (10M cycles)
   //   Init sequence (~2400 cycles)
   //   First root render (~19200 cycles)
   //   First qual render (~9600 cycles)
   //   SEQ_HOLD (100M cycles) -- too long to run fully, use short hold
   //
   // We run for 15M cycles to see init + first two renders + start of hold
   // The 1s hold will not complete in sim -- that's fine, we just want
   // to see the sequencer advance past SEQ_WAIT into SEQ_HOLD

   localparam int RUN_CYCLES = 90_000_000;

   initial begin
      $display("=== display_scroll_test_tb start ===");
      $display("Running %0d cycles (~%0.1f ms)", RUN_CYCLES, RUN_CYCLES/100000.0);

      pin_rst_n = 0;
      repeat (10) @(posedge clk);
      pin_rst_n = 1;
      $display("[%0t] pin_rst_n released", $time);

      repeat (RUN_CYCLES) @(posedge clk);

      $display("\n=== Simulation complete ===");
      $display("Final seq_state=%0d root=%0d qual=%0d",
               dut.seq_state, dut.root_idx, dut.qual_idx);
      $display("Testbus: state=%0d root_dirty=%0b qual_dirty=%0b",
               dut.disp_testbus[7:4],
               dut.disp_testbus[2],
               dut.disp_testbus[3]);
      $finish;
   end

   // ── Watchdog ──────────────────────────────────────────────────
   initial begin
      #300ms;
      $display("WATCHDOG: exceeded 300ms");
      $finish;
   end

endmodule
