// hdl/display_scroll_test.v
// Aliveness / scroll test top-level for SparkFun Micro OLED
// Port names match PCF exactly (board signal names, not internal net names)
// Cycles all 12 root notes x 6 qualities at ~1s per frame using the
// existing AA/55 checkerboard ROM content — no ROM changes needed
// display_top.v is untouched; this is a parallel test target

module display_scroll_test #(
   parameter CLK_DIV = 5    // 100MHz / (2*5) = 10MHz SPI
)(
   input  wire       clk,        // 100MHz system clock
   input  wire       pin_rst_n,      // active-low reset (CU button)

   // OLED SPI — names match PCF board signal names
   output wire       OLED_SDI,   // MOSI  purple  C1
   output wire       OLED_SCLK,  // SCLK  blue    B1
   output wire       OLED_CS,    // CS_N  gray    C5
   output wire       OLED_DC,    // DC    yellow  C3
   output wire       OLED_RST_N, // RST_N orange  C4

   // Debug LEDs on CU board
   output wire [7:0] led
);
// Power-on reset stretcher
// iCE40 initialises all regs to 0, so por_count starts at 0
// rst_n stays low until counter reaches max, then releases high
reg [7:0] por_count = 8'h00;
wire rst_n;

always @(posedge clk) begin
    if (!pin_rst_n)
        por_count <= 8'h00;
    else if (!(&por_count))  // count up until all ones
        por_count <= por_count + 1;
end

assign rst_n = &por_count;  // high only when counter is 0xFF



   // ── ROM interface ─────────────────────────────────────────────
   wire [11:0] rom_addr;
   wire        rom_en;
   wire [7:0]  rom_data;

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

   // ── Wishbone wires to display driver ─────────────────────────
   reg        wb_cyc, wb_stb, wb_we;
   reg  [7:0] wb_addr;
   reg  [7:0] wb_wdat;
   wire [7:0] wb_rdat;
   wire       wb_ack;

   // ── Display driver ────────────────────────────────────────────
   display_driver #(
      .CLK_DIV (CLK_DIV)
   ) disp (
      .clk        (clk),
      .rst_n      (rst_n),
		.testbus    (disp_testbus),
      .wb_cyc     (wb_cyc),
      .wb_stb     (wb_stb),
      .wb_we      (wb_we),
      .wb_addr    (wb_addr),
      .wb_wdat    (wb_wdat),
      .wb_rdat    (wb_rdat),
      .wb_ack     (wb_ack),
      .spi_sclk   (OLED_SCLK),
      .spi_mosi   (OLED_SDI),
      .spi_cs_n   (OLED_CS),
      .oled_dc    (OLED_DC),
      .oled_rst_n (OLED_RST_N),
      .rom_addr   (rom_addr),
      .rom_data   (rom_data),
      .rom_en     (rom_en)
   );

   // ── Alive counter — LEDs[1:0] tick at ~0.75 Hz ───────────────
   // Gives instant visual confirmation the bitstream loaded and
   // the clock is running before the display finishes init

	wire [7:0] disp_testbus;
   reg [26:0] alive_cnt;
   always @(posedge slow_clk or negedge rst_n)begin
      if (!rst_n) alive_cnt <= 0;
      else        alive_cnt <= alive_cnt + 1;
	end

assign led = disp_testbus;

reg [26:0] slow_cnt;
reg        slow_clk;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        slow_cnt <= 0;
        slow_clk <= 0;
    end else if (slow_cnt == 27'd2_499_999) begin
        slow_cnt <= 0;
        slow_clk <= ~slow_clk;
    end else begin
        slow_cnt <= slow_cnt + 1;
    end
end

   // ── Test sequencer ────────────────────────────────────────────
   // Waits for display init + initial dirty renders to finish,
   // then writes root/quality pairs via wishbone and holds each
   // combination for ~1 second before advancing
   //
   // Sequence order: root 0-11 at quality 0, then root 0-11 at
   // quality 1, ... through quality 5.  Full cycle = 72 frames.

   localparam SEQ_WAIT    = 3'd0; // wait for init + first render
   localparam SEQ_WR_ROOT = 3'd1; // write root note register
   localparam SEQ_WR_QUAL = 3'd2; // write quality register
   localparam SEQ_HOLD    = 3'd3; // hold frame for ~1s
   localparam SEQ_NEXT    = 3'd4; // advance indices

   // Mirror display_driver state encoding to detect ST_IDLE
   localparam ST_IDLE = 4'd5;

   reg [2:0]  seq_state;
   reg [3:0]  root_idx;   // 0-11
   reg [2:0]  qual_idx;   // 0-5
   reg [26:0] hold_cnt;   // 100MHz * 1s = 100_000_000

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         seq_state <= SEQ_WAIT;
         root_idx  <= 0;
         qual_idx  <= 0;
         hold_cnt  <= 0;
         wb_cyc    <= 0;
         wb_stb    <= 0;
         wb_we     <= 0;
         wb_addr   <= 0;
         wb_wdat   <= 0;
      end else begin

         // Deassert wishbone the cycle after ack
         if (wb_ack) begin
            wb_cyc <= 0;
            wb_stb <= 0;
            wb_we  <= 0;
         end

         case (seq_state)

            // Wait until init completes and the two startup dirty
            // renders (root=0, qual=0) have both been sent
            SEQ_WAIT: begin
               if (disp.state      == ST_IDLE &&
                   !disp.root_dirty &&
                   !disp.qual_dirty)
                  seq_state <= SEQ_HOLD; // show frame 0 for a full second first
            end

            // Write root index to display driver register 0x00
            SEQ_WR_ROOT: begin
               if (!wb_cyc) begin
                  wb_cyc    <= 1;
                  wb_stb    <= 1;
                  wb_we     <= 1;
                  wb_addr   <= 8'h00;
                  wb_wdat   <= {4'h0, root_idx};
                  seq_state <= SEQ_WR_QUAL;
               end
            end

            // Write quality index to register 0x01 once root ack'd
            SEQ_WR_QUAL: begin
               if (wb_ack && !wb_cyc) begin
                  wb_cyc    <= 1;
                  wb_stb    <= 1;
                  wb_we     <= 1;
                  wb_addr   <= 8'h01;
                  wb_wdat   <= {5'h0, qual_idx};
                  seq_state <= SEQ_HOLD;
                  hold_cnt  <= 0;
               end
            end

            // Hold current frame for ~1 second
            SEQ_HOLD: begin
               hold_cnt <= hold_cnt + 1;
               if (hold_cnt == 27'd100_000_000) begin
                  hold_cnt  <= 0;
                  seq_state <= SEQ_NEXT;
               end
            end

            // Advance: root 0→11 then bump quality, wrap both at max
            SEQ_NEXT: begin
               if (root_idx == 4'd11) begin
                  root_idx <= 0;
                  qual_idx <= (qual_idx == 3'd5) ? 3'd0 : qual_idx + 1;
               end else begin
                  root_idx <= root_idx + 1;
               end
               seq_state <= SEQ_WR_ROOT;
            end

            default: seq_state <= SEQ_WAIT;

         endcase
      end
   end

endmodule
