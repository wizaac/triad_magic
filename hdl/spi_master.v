// hdl/spi_master.v
// SPI Mode 0 (CPOL=0, CPHA=0) master with parameterized clock divider
// TX and RX FIFOs bridging wishbone and SPI
// Wishbone slave interface: WB_WIDTH-bit data bus
//
// Device parameter is documentation only — no logic derived from it.
// Set USE_DC=1 for devices with a D/C sideband pin (e.g. SSD1306).
// When USE_DC=1, WB_WIDTH must be 9: wb_wdat = {dc, data[7:0]}.
// The DC bit is latched from the TX FIFO entry when the byte is popped
// and held stable on the dc output pin for the entire CS transaction,
// from CS_HOLD through CS_DEASS. Glitches between transactions are
// irrelevant — the SSD1306 samples D/C only on the 8th SCLK rising edge.
//
// Supported DEVICE values (documentation only):
//   "SSD1306"  — 10MHz max, USE_DC=1, WB_WIDTH=9
//   "MCP3204"  — 2MHz max,  USE_DC=0, WB_WIDTH=8
//   "MCP4911"  — 20MHz max, USE_DC=0, WB_WIDTH=8

module spi_master #(
   parameter DEVICE     = "Generic", // documentation label
   parameter USE_DC     = 0,         // 1 = DC sideband pin present
   parameter WB_WIDTH   = 8,         // 8 or 9 (must be 9 when USE_DC=1)
   parameter CLK_DIV    = 50,        // sclk = clk / (2 * CLK_DIV)
   parameter FIFO_DEPTH = 4          // depth of TX and RX FIFOs
)(
   // System
   input  wire                  clk,
   input  wire                  rst_n,

   // Wishbone slave
   input  wire                  wb_cyc,
   input  wire                  wb_stb,
   input  wire                  wb_we,
   input  wire [1:0]            wb_addr,  // 00=TX, 01=RX, 10=status
   input  wire [WB_WIDTH-1:0]   wb_wdat,
   output reg  [WB_WIDTH-1:0]   wb_rdat,
   output reg                   wb_ack,

   // SPI
   output reg                   sclk,
   output reg                   mosi,
   input  wire                  miso,
   output reg                   cs_n,

   // DC sideband — only meaningful when USE_DC=1
   // Held stable for the entire CS transaction
   output reg                   dc
);

   // ── FIFO storage ─────────────────────────────────────────────
   // Each entry is WB_WIDTH bits wide: {dc, data[7:0]} or {data[7:0]}
   reg [WB_WIDTH-1:0] tx_fifo [0:FIFO_DEPTH-1];
   reg [WB_WIDTH-1:0] rx_fifo [0:FIFO_DEPTH-1];

   reg [$clog2(FIFO_DEPTH):0] tx_wr_ptr, tx_rd_ptr;
   reg [$clog2(FIFO_DEPTH):0] rx_wr_ptr, rx_rd_ptr;

   wire tx_empty = (tx_wr_ptr == tx_rd_ptr);
   wire rx_empty = (rx_wr_ptr == rx_rd_ptr);
   wire tx_full  = (tx_wr_ptr[$clog2(FIFO_DEPTH)]   != tx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                   (tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);
   wire rx_full  = (rx_wr_ptr[$clog2(FIFO_DEPTH)]   != rx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                   (rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);

   // ── Clock divider ─────────────────────────────────────────────
   reg [$clog2(CLK_DIV)-1:0] clk_cnt;
   reg                        sclk_en;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         clk_cnt <= 0;
         sclk_en <= 0;
      end else begin
         sclk_en <= 0;
         if (clk_cnt == CLK_DIV - 1) begin
            clk_cnt <= 0;
            sclk_en <= 1;
         end else begin
            clk_cnt <= clk_cnt + 1;
         end
      end
   end

   reg miso_r;
   always @(posedge clk) miso_r <= miso;

   // ── SPI FSM ───────────────────────────────────────────────────
   localparam IDLE     = 2'd0;
   localparam CS_HOLD  = 2'd1;
   localparam SHIFT    = 2'd2;
   localparam CS_DEASS = 2'd3;

   reg [1:0]  state;
   reg [2:0]  bit_cnt;
   reg        sclk_phase;
   reg [7:0]  shift_reg;
   reg [7:0]  rx_shift;
   reg        dc_latched;   // DC value latched from FIFO entry at pop

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state      <= IDLE;
         cs_n       <= 1;
         sclk       <= 0;
         mosi       <= 0;
         dc         <= 0;
         dc_latched <= 0;
         bit_cnt    <= 0;
         sclk_phase <= 0;
         shift_reg  <= 0;
         rx_shift   <= 0;
         tx_rd_ptr  <= 0;
         rx_wr_ptr  <= 0;
      end else begin
         case (state)

            IDLE: begin
               cs_n       <= 1;
               sclk       <= 0;
               sclk_phase <= 0;
               if (!tx_empty && sclk_en) begin
                  // Pop from TX FIFO
                  // When USE_DC=1, MSB of entry is the DC bit
                  shift_reg  <= tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]][7:0];
                  dc_latched <= (USE_DC) ?
                                tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]][8] :
                                1'b0;
                  tx_rd_ptr  <= tx_rd_ptr + 1;
                  state      <= CS_HOLD;
               end
            end

            CS_HOLD: begin
               if (sclk_en) begin
                  cs_n    <= 0;
                  dc      <= dc_latched; // stable from here through CS_DEASS
                  mosi    <= shift_reg[7];
                  bit_cnt <= 0;
                  state   <= SHIFT;
               end
            end

            SHIFT: begin
               if (sclk_en) begin
                  sclk_phase <= ~sclk_phase;
                  if (!sclk_phase) begin
                     // Rising edge — sample MISO
                     sclk     <= 1;
                     rx_shift <= { rx_shift[6:0],miso_r};
                  end else begin
                     // Falling edge — shift out next bit
                     sclk <= 0;
                     if (bit_cnt == 3'd7) begin
                        state <= CS_DEASS;
                     end else begin
                        bit_cnt   <= bit_cnt + 1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        mosi      <= shift_reg[6];
                     end
                  end
               end
            end

            CS_DEASS: begin
               if (sclk_en) begin
                  cs_n <= 1;
                  if (!rx_full) begin
                     rx_fifo[rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= rx_shift;
                     rx_wr_ptr <= rx_wr_ptr + 1;
                  end
                  state <= IDLE;
               end
            end

         endcase
      end
   end

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      wb_ack    <= 0;
      wb_rdat   <= 0;
      tx_wr_ptr <= 0;
      rx_rd_ptr <= 0;
   end else begin
      wb_ack <= 0;
      if (wb_cyc && wb_stb && !wb_ack) begin
         // no unconditional wb_ack here
         case (wb_addr)
            2'b00: begin  // TX FIFO write — only ack if space available
               if (wb_we && !tx_full) begin
                  tx_fifo[tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= wb_wdat;
                  tx_wr_ptr <= tx_wr_ptr + 1;
                  wb_ack    <= 1;
               end
               // no ack if full — display_driver holds cyc/stb and retries
            end
            2'b01: begin  // RX FIFO read
               wb_ack <= 1;
               if (!wb_we && !rx_empty) begin
                  wb_rdat   <= rx_fifo[rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                  rx_rd_ptr <= rx_rd_ptr + 1;
               end
            end
            2'b10: begin  // status register
               wb_ack  <= 1;
               wb_rdat <= {{WB_WIDTH-8{1'b0}}, rx_full, rx_empty,
                           tx_full, tx_empty, 4'b0};
            end
         endcase
      end
   end
end
endmodule
