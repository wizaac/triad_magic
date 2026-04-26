// hdl/adc_reader.v
// MCP3204 SPI ADC reader
// Continuously samples all 4 channels and exposes results via wishbone
// MCP3204 transaction: 3 bytes TX, 3 bytes RX, result in RX[1][3:0]:RX[2][7:0]

module adc_reader #(
   parameter CLK_DIV = 50   // 100MHz / (2*50) = 1MHz SPI for MCP3204
)(
   input  wire        clk,
   input  wire        rst_n,

   // Wishbone slave (read-only, exposes raw 8-bit pot values)
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [2:0]  wb_addr,  // 0-3 = pot channels
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack,

   // SPI physical pins
   output wire        spi_sclk,
   output wire        spi_mosi,
   input  wire        spi_miso,
   output wire        spi_cs_n
);

   // ── Channel command bytes ─────────────────────────────────────
   // MCP3204 single-ended channel select:
   // Byte 1: 0x06 for all channels (start bit + single-ended mode)
   // Byte 2: channel select in bits [7:6]
   //   CH0: 0x00, CH1: 0x40, CH2: 0x80, CH3: 0xC0
   localparam CMD_BYTE1 = 8'h06;

   function [7:0] ch_byte2;
      input [1:0] ch;
      case (ch)
         2'd0: ch_byte2 = 8'h00;
         2'd1: ch_byte2 = 8'h40;
         2'd2: ch_byte2 = 8'h80;
         2'd3: ch_byte2 = 8'hC0;
      endcase
   endfunction

   // ── Output registers ──────────────────────────────────────────
   reg [7:0] pot [0:3];   // top 8 bits of 12-bit result per channel

   // ── SPI master wishbone signals ───────────────────────────────
   reg        spi_wb_cyc, spi_wb_stb, spi_wb_we;
   reg  [1:0] spi_wb_addr;
   reg  [7:0] spi_wb_wdat;
   wire [7:0] spi_wb_rdat;
   wire       spi_wb_ack;

   // ── SPI master instantiation ──────────────────────────────────
   spi_master #(
      .CLK_DIV    (CLK_DIV),
      .FIFO_DEPTH (4)
   ) spi (
      .clk      (clk),
      .rst_n    (rst_n),
      .wb_cyc   (spi_wb_cyc),
      .wb_stb   (spi_wb_stb),
      .wb_we    (spi_wb_we),
      .wb_addr  (spi_wb_addr),
      .wb_wdat  (spi_wb_wdat),
      .wb_rdat  (spi_wb_rdat),
      .wb_ack   (spi_wb_ack),
      .sclk     (spi_sclk),
      .mosi     (spi_mosi),
      .miso     (spi_miso),
      .cs_n     (spi_cs_n)
   );

   // ── SPI status register bits ──────────────────────────────────
   localparam SPI_ADDR_TX     = 2'b00;
   localparam SPI_ADDR_RX     = 2'b01;
   localparam SPI_ADDR_STATUS = 2'b10;

   // ── FSM states ────────────────────────────────────────────────
   localparam ST_SEND1      = 4'd0;  // write byte 1 to TX FIFO
   localparam ST_SEND1_WAIT = 4'd1;  // wait for ack
   localparam ST_SEND2      = 4'd2;  // write byte 2 to TX FIFO
   localparam ST_SEND2_WAIT = 4'd3;  // wait for ack
   localparam ST_SEND3      = 4'd4;  // write byte 3 (don't care)
   localparam ST_SEND3_WAIT = 4'd5;  // wait for ack
   localparam ST_WAIT_DONE  = 4'd6;  // wait for SPI to finish
   localparam ST_READ_STATUS = 4'd7; // check RX FIFO has 3 bytes
   localparam ST_READ1      = 4'd8;  // read and discard RX byte 1
   localparam ST_READ1_WAIT = 4'd9;  // wait for ack
   localparam ST_READ2      = 4'd10; // read RX byte 2 (high nibble)
   localparam ST_READ2_WAIT = 4'd11; // wait for ack
   localparam ST_READ3      = 4'd12; // read RX byte 3 (low byte)
   localparam ST_READ3_WAIT = 4'd13; // wait for ack
   localparam ST_NEXT_CH    = 4'd14; // advance to next channel

   reg [3:0]  state;
   reg [1:0]  channel;     // current channel being sampled 0-3
   reg [3:0]  rx2_nibble;  // top nibble saved from RX byte 2
   reg [7:0]  wait_cnt;    // small delay between transactions

   // ── SPI write/read/idle tasks ─────────────────────────────────
   task spi_write;
      input [7:0] data;
      begin
         spi_wb_cyc  <= 1;
         spi_wb_stb  <= 1;
         spi_wb_we   <= 1;
         spi_wb_addr <= SPI_ADDR_TX;
         spi_wb_wdat <= data;
      end
   endtask

   task spi_read;
      begin
         spi_wb_cyc  <= 1;
         spi_wb_stb  <= 1;
         spi_wb_we   <= 0;
         spi_wb_addr <= SPI_ADDR_RX;
      end
   endtask

   task spi_status;
      begin
         spi_wb_cyc  <= 1;
         spi_wb_stb  <= 1;
         spi_wb_we   <= 0;
         spi_wb_addr <= SPI_ADDR_STATUS;
      end
   endtask

   task spi_idle;
      begin
         spi_wb_cyc <= 0;
         spi_wb_stb <= 0;
         spi_wb_we  <= 0;
      end
   endtask

   // ── Combinational channel byte ────────────────────────────────
   wire [7:0] cur_ch_byte2 = ch_byte2(channel);

   // ── Main FSM ──────────────────────────────────────────────────
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state       <= ST_SEND1;
         channel     <= 0;
         rx2_nibble  <= 0;
         wait_cnt    <= 0;
         pot[0]      <= 8'h00;
         pot[1]      <= 8'h00;
         pot[2]      <= 8'h00;
         pot[3]      <= 8'h00;
         spi_wb_cyc  <= 0;
         spi_wb_stb  <= 0;
         spi_wb_we   <= 0;
         spi_wb_addr <= 0;
         spi_wb_wdat <= 0;
         wb_ack      <= 0;
         wb_rdat     <= 0;
      end else begin

         if (spi_wb_ack) spi_idle();
         wb_ack <= 0;
			wb_rdat<='0;
         // ── Wishbone read interface ───────────────────────────
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack  <= 1;
            wb_rdat <= pot[wb_addr[1:0]];
         end

         // ── ADC sampling FSM ──────────────────────────────────
         case (state)

            ST_SEND1: begin
               if (!spi_wb_cyc) begin
                  spi_write(CMD_BYTE1);
                  state <= ST_SEND1_WAIT;
               end
            end

            ST_SEND1_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_SEND2;
               end
            end

            ST_SEND2: begin
               if (!spi_wb_cyc) begin
                  spi_write(cur_ch_byte2);
                  state <= ST_SEND2_WAIT;
               end
            end

            ST_SEND2_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_SEND3;
               end
            end

            ST_SEND3: begin
               if (!spi_wb_cyc) begin
                  spi_write(8'h00);  // don't care byte
                  state <= ST_SEND3_WAIT;
               end
            end

            ST_SEND3_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_WAIT_DONE;
               end
            end

            // wait for SPI master to finish clocking all 3 bytes
            // poll status until rx_empty is clear (data available)
            ST_WAIT_DONE: begin
               if (!spi_wb_cyc) begin
                  spi_status();
                  state <= ST_READ_STATUS;
               end
            end

            ST_READ_STATUS: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  // status[2] = rx_empty, wait until cleared
                  if (!spi_wb_rdat[2])
                     state <= ST_READ1;
                  else
                     state <= ST_WAIT_DONE;
               end
            end

            ST_READ1: begin
               if (!spi_wb_cyc) begin
                  spi_read();
                  state <= ST_READ1_WAIT;
               end
            end

            // discard first RX byte, nothing useful in it
            ST_READ1_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_READ2;
               end
            end

            ST_READ2: begin
               if (!spi_wb_cyc) begin
                  spi_read();
                  state <= ST_READ2_WAIT;
               end
            end

            // save top nibble of result from RX byte 2
            ST_READ2_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  rx2_nibble <= spi_wb_rdat[4:1];
                  state      <= ST_READ3;
               end
            end

            ST_READ3: begin
               if (!spi_wb_cyc) begin
                  spi_read();
                  state <= ST_READ3_WAIT;
               end
            end

            // assemble 12-bit result, take top 8 bits
            // full 12-bit: {rx2_nibble[3:0], rx_byte3[7:0]}
            // top 8 bits:  {rx2_nibble[3:0], rx_byte3[7:4]}
            ST_READ3_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  pot[channel] <= {rx2_nibble, spi_wb_rdat[7:4]};
                  state        <= ST_NEXT_CH;
               end
            end

            // advance to next channel with a brief gap
            ST_NEXT_CH: begin
               wait_cnt <= wait_cnt + 1;
               if (wait_cnt == 8'd10) begin
                  wait_cnt <= 0;
                  channel  <= channel + 1;  // wraps 3→0 naturally
                  state    <= ST_SEND1;
               end
            end

            default: state <= ST_SEND1;

         endcase
      end
   end

endmodule
