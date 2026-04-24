// hdl/adc_decoder.v
// Translates raw 8-bit pot values into musical parameters
// for the chord engine. Pure combinational logic — no clock needed
// for the decode itself, registered outputs for clean wishbone interface.
//
// Input pot mapping (from adc_reader):
//   pot[0] = root      → 0-11  (12 note zones, top 4 bits / 16)
//   pot[1] = quality   → 0-7   (8 quality zones, top 3 bits)
//   pot[2] = spacing   → 0-11  (12 voicing presets, top 4 bits)
//   pot[3] = length    → pulse count (16 zones, top 4 bits)

module adc_decoder #(
   parameter CLK_DIV = 5    // 100MHz / (2*5) = 10MHz SPI for OLED
)(
   input  wire        clk,
   input  wire        rst_n,
	output wire [7:0]  testbus,

   // Wishbone slave
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [3:0]  wb_addr,
   input  wire [7:0]  wb_wdta,
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack,
   // SPI physical pins
   output wire        spi_sclk,
   output wire        spi_mosi,
   output wire        spi_miso,
   output wire        spi_cs_n

);

   // ── Quality encoding ──────────────────────────────────────────
   localparam QUAL_SUS2  = 3'd0;
   localparam QUAL_SUS4  = 3'd1;
   localparam QUAL_MAJ   = 3'd2;
   localparam QUAL_MIN   = 3'd3;
   localparam QUAL_DIM   = 3'd4;
   localparam QUAL_AUG   = 3'd5;
   localparam QUAL_PWR   = 3'd7;  // all the way right = power chord

   // ── SPI master wishbone signals ───────────────────────────────
   reg        spi_wb_cyc, spi_wb_stb, spi_wb_we;
   reg  [1:0] spi_wb_addr;
   reg  [8:0] spi_wb_wdat;
   wire [8:0] spi_wb_rdat;
   wire       spi_wb_ack;
   wire       spi_miso;

  // ── SPI master instantiation ──────────────────────────────────
   spi_master #(
      .DEVICE     ("MCP3204"),
      .USE_DC     (0),
      .WB_WIDTH   (8),
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
      .dc       (oled_dc),
      .cs_n     (spi_cs_n)
   );


   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         wb_ack  <= 0;
         wb_rdat <= 0;
      end else begin
         wb_ack <= 0;
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack <= 1;
            if (!wb_we) begin
               case (wb_addr)
                  4'h0: wb_rdat <= {4'b0, root_out};
                  4'h1: wb_rdat <= {5'b0, quality_out};
                  4'h2: wb_rdat <= {4'b0, spacing_out};
                  4'h3: wb_rdat <= {2'b0, spacing_vec};
                  4'h4: wb_rdat <= {1'b0, length_out};
                  4'h5: wb_rdat <= pot_root;
                  4'h6: wb_rdat <= pot_quality;
                  4'h7: wb_rdat <= pot_spacing;
                  4'h8: wb_rdat <= pot_length;
                  default: wb_rdat <= 8'hFF;
               endcase
            end
         end
reg[7:0] cmd_byte [3];//only the first five bits matter, two bytes of zero transmitted to keep the clock running.
assign cmd_byte[1] <= 8'h00;
assign cmd_byte[2] <= 8'h00;
reg[11:0] adc_array [1:0]
case(pot_reader_state)
INIT: 
	//No init commands need to go to the chip, go straight to start (maybe include reset delay/master init driver later)
	pot_reader_next_state <= CHANNEL_START;// 

CHANNEL_START:begin
	bytes_sent <= 0;
	cmd_byte[0] <= {mcp3204_start_bit, 2'b1,channel,3'b000};
	pot_reader_next_state <= SEND_WB_CMD_BYTE;
end
SEND_WB_CMD_BYTE: begin
	write_spi_wb_byte(cmd_byte[bytes_sent]);
	pot_reader_next_state <= WAIT_ACK;
end
WAIT_ACK: begin
	wait_spi_ack();
	if(bytes_sent >= 3 )begin
		bytes_sent = bytes_sent + 1;
		pot_reader_next_state <= SEND_WB_CMD_BYTE;// The chip needs two bytes of do-not-care.. why not just resend the exact command 3 times?
	end else begin
		pot_reader_next_state <= GET_SPI_DATA;// The chip needs two bytes of do-not-care.. why not just resend the exact command 3 times?
	end
end
GET_SPI_DATA:begin
	bytes_read = 0;
	pot_reader_next_state <= WAIT_SPI_FIFO_NOT_EMPTY;// The chip needs two bytes of do-not-care.. why not just resend the exact command 3 times?
begin
GET_SPI_WB_BYTE: begin
	raw_byte = read_spi_wb_byte(rd_fifo);
	if(bytes_read == 0)begin
		adc_array[channel][11:8] = raw_byte[3:0];
		pot_reader_next_state <= GET_SPI_WB_BYTE;// 
	end else if(bytes_read == 1) begin
		adc_array[channel][11:8] = raw_byte[3:0];
		pot_reader_next_state <= CHANNEL_CLEANUP;// 
	end
end
CHANNEL_CLEANUP:begin
	channel <= channel + 1;//4-channels,two bits. channel select field on adc is two bits(D1,D0 in cmd byte)
	if(channel == 0)//start of new cycle, wait for refresh to let other modules use the SPI
		pot_reader_next_state <= WAIT_FOR_REFRESH_PERIOD;// 
	else
		pot_reader_next_state <= CHANNEL_START;// 		
end
WAIT_FOR_REFRESH_PERIOD: begin
	downtime_counter <= downtime_counter + 1;
	if(downtime_counter >= DOWNTIME) begin
		pot_reader_next_state <= CHANNEL_START;// 
	end else begin
		pot_reader_next_state <= WAIT_FOR_REFRESH_PERIOD;
	end
end
endcase
			//Read Pot State machine
			//init: no init sequence on SPI require
			//IDLE: Idle is downtime between sampling rate; takes 20 bytes of SPI uptime per cycle
			//Read Ch1
			//Read Ch2
			//Read Ch3
			//Read Ch4
			//Read is write_wb x3 ({start_bit, single-ended channel,do-not-care-bit,channel select [1:0],3'b0},8'b0.8'bo)
			//SPI master will fill up rdfifo, so wb_read(rd_fifo) x3
			//Loop through with a vector for channel select
			//Burst read all 4 channels, then wait a long time to leave the bus open for other drivers
			//explicit states for all 4 channels lets us write to specific registers in specific states,
			//or channel select could be used as addr for a write. Case(channel_sel): 1: pot_root = spi_wb_rdata

      end
   end

endmodule
