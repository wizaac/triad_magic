// hdl/spi_master.v
// SPI Mode 0 (CPOL=0, CPHA=0) master with parameterized clock divider
// TX and RX FIFOs bridging wishbone and SPI
// Wishbone slave interface: 8-bit data bus

module spi_master #(
   parameter CLK_DIV    = 50,   // sclk = clk / (2 * CLK_DIV)
   parameter FIFO_DEPTH = 4     // depth of TX and RX FIFOs
)(
   // System
   input  wire       clk,
   input  wire       rst_n,

   // Wishbone slave
   input  wire       wb_cyc,
   input  wire       wb_stb,
   input  wire       wb_we,
   input  wire [1:0] wb_addr,   // 00=TX FIFO, 01=RX FIFO, 10=status
   input  wire [7:0] wb_wdat,
   output reg  [7:0] wb_rdat,
   output reg        wb_ack,

   // SPI
   output reg        sclk,
   output reg        mosi,
   input  wire       miso,
   output reg        cs_n
);

   // ── FIFO storage ────────────────────────────────────────────
   reg [7:0] tx_fifo [0:FIFO_DEPTH-1];
   reg [7:0] rx_fifo [0:FIFO_DEPTH-1];

   reg [$clog2(FIFO_DEPTH):0] tx_wr_ptr, tx_rd_ptr;
   reg [$clog2(FIFO_DEPTH):0] rx_wr_ptr, rx_rd_ptr;

   wire tx_empty = (tx_wr_ptr == tx_rd_ptr);
   wire rx_empty = (rx_wr_ptr == rx_rd_ptr);
   wire tx_full  = (tx_wr_ptr[$clog2(FIFO_DEPTH)] != tx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                   (tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);
   wire rx_full  = (rx_wr_ptr[$clog2(FIFO_DEPTH)] != rx_rd_ptr[$clog2(FIFO_DEPTH)]) &&
                   (rx_wr_ptr[$clog2(FIFO_DEPTH)-1:0] == rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]);

   // ── Clock divider ────────────────────────────────────────────
   reg [$clog2(CLK_DIV)-1:0] clk_cnt;
   reg                        sclk_en;  // pulses at sclk rate

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
	
	always @(posedge clk) begin
	   miso_r <= miso;
	end
   // ── SPI FSM ──────────────────────────────────────────────────
   localparam IDLE     = 2'd0;
   localparam CS_HOLD  = 2'd1;  // assert CS, wait one sclk before shifting
   localparam SHIFT    = 2'd2;
   localparam CS_DEASS = 2'd3;  // deassert CS, wait one sclk after shifting

   reg [1:0]  state;
   reg [2:0]  bit_cnt;    // counts 0..7
   reg        sclk_phase; // 0=low half, 1=high half of sclk period
   reg [7:0]  shift_reg;
   reg [7:0]  rx_shift;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state      <= IDLE;
         cs_n       <= 1;
         sclk       <= 0;
         mosi       <= 0;
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
                  // pop from TX FIFO
                  shift_reg <= tx_fifo[tx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                  tx_rd_ptr <= tx_rd_ptr + 1;
                  state     <= CS_HOLD;
               end
            end

            CS_HOLD: begin
               if (sclk_en) begin
                  cs_n    <= 0;
                  mosi    <= shift_reg[7]; // pre-drive MSB
                  bit_cnt <= 0;
                  state   <= SHIFT;
               end
            end

            SHIFT: begin
               if (sclk_en) begin
                  sclk_phase <= ~sclk_phase;
                  if (!sclk_phase) begin
                     // rising edge — sample MISO
                     sclk     <= 1;
                     rx_shift <= {miso_r,rx_shift[7:1]};
                  end else begin
                     // falling edge — shift out next bit
                     sclk <= 0;
                     if (bit_cnt == 3'd7) begin
                        state <= CS_DEASS;
                     end else begin
                        bit_cnt   <= bit_cnt + 1;
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        mosi      <= shift_reg[6]; // next bit
                     end
                  end
               end
            end

            CS_DEASS: begin
               if (sclk_en) begin
                  cs_n <= 1;
                  // push to RX FIFO if not full
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

   // ── Wishbone interface ───────────────────────────────────────
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         wb_ack    <= 0;
         wb_rdat   <= 0;
         tx_wr_ptr <= 0;
         rx_rd_ptr <= 0;
      end else begin
         wb_ack <= 0;
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack <= 1;
            case (wb_addr)
               2'b00: begin  // TX FIFO write
                  if (wb_we && !tx_full) begin
                     tx_fifo[tx_wr_ptr[$clog2(FIFO_DEPTH)-1:0]] <= wb_wdat;
                     tx_wr_ptr <= tx_wr_ptr + 1;
                  end
               end
               2'b01: begin  // RX FIFO read
                  if (!wb_we && !rx_empty) begin
                     wb_rdat   <= rx_fifo[rx_rd_ptr[$clog2(FIFO_DEPTH)-1:0]];
                     rx_rd_ptr <= rx_rd_ptr + 1;
                  end
               end
               2'b10: begin  // status register (read only)
                  wb_rdat <= {4'b0, rx_full, rx_empty, tx_full, tx_empty};
               end
            endcase
         end
      end
   end

endmodule
