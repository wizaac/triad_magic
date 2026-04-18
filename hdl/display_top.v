// hdl/display_top.v
// Top level for display driver hardware test
// Connects display_driver and shared_rom to physical pins
// Target: Alchitry CU + Br expander + SparkFun Micro OLED

module display_top (
   input  wire clk,        // 100MHz
   input  wire rst_n,      // active low reset (button on CU)

   // OLED SPI signals (Br Bank A pins)
   output wire oled_sclk,
   output wire oled_mosi,
   output wire oled_cs_n,
   output wire oled_dc,
   output wire oled_rst_n,

   // Debug LEDs on CU
   output wire [7:0] led
);

   // ── ROM interface wires ──────────────────────────────────────
   wire [11:0] rom_addr;
   wire        rom_en;
   wire [7:0]  rom_data;

   // ── Shared ROM instantiation ─────────────────────────────────
   // ROM wishbone port tied off — no runtime font loading yet
   shared_rom rom_inst (
      .clk      (clk),
      .wb_cyc   (1'b0),
      .wb_stb   (1'b0),
      .wb_we    (1'b0),
      .wb_addr  (12'h0),
      .wb_wdat  (8'h0),
      .wb_rdat  (),
      .wb_ack   (),
      .rd_addr  (rom_addr),
      .rd_en    (rom_en),
      .rd_data  (rom_data)
   );

   // ── Display driver wishbone wires ────────────────────────────
   // driven by test sequencer below
   reg        wb_cyc, wb_stb, wb_we;
   reg  [7:0] wb_addr;
   reg  [7:0] wb_wdat;
   wire [7:0] wb_rdat;
   wire       wb_ack;

   // ── Display driver instantiation ────────────────────────────
   display_driver #(
      .CLK_DIV (5)    // 100MHz / (2*5) = 10MHz SPI
   ) disp (
      .clk        (clk),
      .rst_n      (rst_n),
      .wb_cyc     (wb_cyc),
      .wb_stb     (wb_stb),
      .wb_we      (wb_we),
      .wb_addr    (wb_addr),
      .wb_wdat    (wb_wdat),
      .wb_rdat    (wb_rdat),
      .wb_ack     (wb_ack),
      .spi_sclk   (oled_sclk),
      .spi_mosi   (oled_mosi),
      .spi_cs_n   (oled_cs_n),
      .oled_dc         (oled_dc),
      .oled_rst_n (oled_rst_n),
      .rom_addr   (rom_addr),
      .rom_data   (rom_data),
      .rom_en     (rom_en)
   );



   // ── Test sequencer ───────────────────────────────────────────
   // After display init completes, cycles through all 12 root
   // notes and all 6 qualities so we can see the placeholder
   // bitmaps on the screen and verify the hardware is working
   localparam SEQ_IDLE     = 3'd0;
   localparam SEQ_WAIT     = 3'd1;  // wait for init
   localparam SEQ_WR_ROOT  = 3'd2;
   localparam SEQ_WR_QUAL  = 3'd3;
   localparam SEQ_DELAY    = 3'd4;
   localparam SEQ_NEXT     = 3'd5;

   reg [2:0]  seq_state;
   reg [3:0]  root_idx;    // 0-11
   reg [2:0]  qual_idx;    // 0-5
   reg [26:0] delay_cnt;   // ~1 second at 100MHz

   // expose current root and quality on LEDs for debug
   assign led = {1'b0, qual_idx, root_idx};

   // probe display driver state to know when init is done
   wire [3:0] disp_state = disp.state;
   localparam ST_IDLE = 4'd5;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         seq_state <= SEQ_WAIT;
         root_idx  <= 0;
         qual_idx  <= 0;
         delay_cnt <= 0;
         wb_cyc    <= 0;
         wb_stb    <= 0;
         wb_we     <= 0;
         wb_addr   <= 0;
         wb_wdat   <= 0;
      end else begin

         // deassert wishbone after ack
         if (wb_ack) begin
            wb_cyc <= 0;
            wb_stb <= 0;
            wb_we  <= 0;
         end

         case (seq_state)

            // wait until display driver finishes init
            // and clears the initial dirty flags
            SEQ_WAIT: begin
               if (disp_state == ST_IDLE &&
                   !disp.root_dirty &&
                   !disp.qual_dirty) begin
                  seq_state <= SEQ_DELAY;
                  delay_cnt <= 0;
               end
            end

            // write new root note
            SEQ_WR_ROOT: begin
               if (!wb_cyc) begin
                  wb_cyc  <= 1;
                  wb_stb  <= 1;
                  wb_we   <= 1;
                  wb_addr <= 8'h00;
                  wb_wdat <= {4'h0, root_idx};
                  seq_state <= SEQ_WR_QUAL;
               end
            end

            // write quality
            SEQ_WR_QUAL: begin
               if (wb_ack && !wb_cyc) begin
                  wb_cyc  <= 1;
                  wb_stb  <= 1;
                  wb_we   <= 1;
                  wb_addr <= 8'h01;
                  wb_wdat <= {5'h0, qual_idx};
                  seq_state <= SEQ_DELAY;
                  delay_cnt <= 0;
               end
            end

            // hold current display for ~1 second
            SEQ_DELAY: begin
               delay_cnt <= delay_cnt + 1;
               if (delay_cnt == 27'd100_000_000) begin
                  delay_cnt <= 0;
                  seq_state <= SEQ_NEXT;
               end
            end

            // advance to next root/quality combination
            SEQ_NEXT: begin
               if (root_idx == 4'd11) begin
                  root_idx <= 0;
                  if (qual_idx == 3'd5)
                     qual_idx <= 0;
                  else
                     qual_idx <= qual_idx + 1;
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
