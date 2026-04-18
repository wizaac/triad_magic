// hdl/display_driver.v
// SSD1306 display driver for SparkFun 64x48 Micro OLED
// Handles init sequence and register-triggered bitmap updates
// Shares note/quality ROM with other instances via external ROM interface

module display_driver #(
   parameter CLK_DIV = 5    // 100MHz / (2*5) = 10MHz SPI for OLED
)(
   // System
   input  wire        clk,
   input  wire        rst_n,

   // Wishbone slave
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [7:0]  wb_addr,
   input  wire [7:0]  wb_wdat,
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack,

   // SPI physical pins
   output wire        spi_sclk,
   output wire        spi_mosi,
   output wire        spi_cs_n,

   // SSD1306 control pins
   output reg         oled_dc,
   output reg         oled_rst_n,

   // Shared ROM interface (read port)
   output reg  [11:0] rom_addr,
   input  wire [7:0]  rom_data,
   output reg         rom_en
);

   // ── SSD1306 display layout parameters ────────────────────────
   // The SSD1306 controller is 128x64 but SparkFun display is 64x48
   // Physical display occupies cols 32-95, pages 0-5
   // We split into three regions:
   //   Root:    left  half — cols 32-63,  pages 0-5 (32x48px)
   //   Quality: right half — cols 96-127, pages 3-5 (32x24px)
   //   Debug:   right half — cols 96-127, pages 0-2 (32x24px)
   localparam COL_ROOT_START  = 8'h20;  // col 32
   localparam COL_ROOT_END    = 8'h3F;  // col 63
   localparam COL_RIGHT_START = 8'h60;  // col 96
   localparam COL_RIGHT_END   = 8'h7F;  // col 127
   localparam PAGE_TOP        = 8'h00;  // page 0
   localparam PAGE_MID        = 8'h03;  // page 3
   localparam PAGE_BOT        = 8'h05;  // page 5

   // Bitmap sizes in bytes
   localparam NOTE_BYTES      = 11'd192; // 32 cols x 6 pages
   localparam QUAL_BYTES      = 11'd96;  // 32 cols x 3 pages
   localparam DEBUG_BYTES     = 11'd96;  // 32 cols x 3 pages

   // ROM layout
   localparam NOTE_ROM_BASE   = 12'd0;    // 12 notes * 192 = 2304 bytes
   localparam QUAL_ROM_BASE   = 12'd2304; // 6 qualities * 96 = 576 bytes
   localparam DEBUG_ROM_BASE  = 12'd2880; // debug region (if needed)

   // Init sequence length
   localparam INIT_LEN        = 8'd24;   // 23 init bytes + display on

   // Reset timing
   localparam RESET_PULSE_CYC = 24'd1000;       // ~10us at 100MHz
   localparam RESET_WAIT_CYC  = 24'd10_000_000; // 100ms at 100MHz

   // Address command sequence length
   localparam ADDR_CMD_LEN    = 4'd6;

   // ── Region select encoding ────────────────────────────────────
   localparam REGION_ROOT  = 2'd0;
   localparam REGION_QUAL  = 2'd1;
   localparam REGION_DEBUG = 2'd2;

   // ── Internal registers ────────────────────────────────────────
   reg [7:0] root;
   reg [2:0] quality;
   reg       root_dirty;
   reg       qual_dirty;
   reg [1:0] current_region;
	reg [8:0] init_byte_r;
	reg [8:0] addr_byte_r;

   // ── SPI master wishbone signals ───────────────────────────────
   reg        spi_wb_cyc, spi_wb_stb, spi_wb_we;
   reg  [1:0] spi_wb_addr;
   reg  [7:0] spi_wb_wdat;
   wire [7:0] spi_wb_rdat;
   wire       spi_wb_ack;
   wire       spi_miso;

	// Combinational wires — computed every cycle based on current state
	wire [8:0] cur_init_byte = init_byte(init_idx);
	wire [8:0] cur_addr_byte = addr_byte(current_region, addr_idx);

   // ── SPI master instantiation ──────────────────────────────────
   spi_master #(
      .CLK_DIV    (CLK_DIV),
      .FIFO_DEPTH (16)
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
   assign spi_miso = 1'b0;

   // ── Init sequence lookup ──────────────────────────────────────
   // Returns {dc, byte} for each init step
   // Pure combinational — no array, no initial block
   // Yosys synthesises this as a LUT/mux tree
   function [8:0] init_byte;
      input [7:0] idx;
      case (idx)
         8'd0:  init_byte = {1'b0, 8'hAE}; // display off
         8'd1:  init_byte = {1'b0, 8'hD5}; // set display clock
         8'd2:  init_byte = {1'b0, 8'h80}; //   divide ratio
         8'd3:  init_byte = {1'b0, 8'hA8}; // set multiplex
         8'd4:  init_byte = {1'b0, 8'h2F}; //   47 rows
         8'd5:  init_byte = {1'b0, 8'hD3}; // display offset
         8'd6:  init_byte = {1'b0, 8'h00}; //   0
         8'd7:  init_byte = {1'b0, 8'h40}; // start line = 0
         8'd8:  init_byte = {1'b0, 8'h8D}; // charge pump
         8'd9:  init_byte = {1'b0, 8'h14}; //   enable
         8'd10: init_byte = {1'b0, 8'h20}; // addressing mode
         8'd11: init_byte = {1'b0, 8'h00}; //   horizontal
         8'd12: init_byte = {1'b0, 8'hA1}; // segment re-map
         8'd13: init_byte = {1'b0, 8'hC8}; // COM scan direction
         8'd14: init_byte = {1'b0, 8'hDA}; // COM pins config
         8'd15: init_byte = {1'b0, 8'h12}; //
         8'd16: init_byte = {1'b0, 8'h81}; // contrast
         8'd17: init_byte = {1'b0, 8'hCF}; //
         8'd18: init_byte = {1'b0, 8'hD9}; // pre-charge period
         8'd19: init_byte = {1'b0, 8'hF1}; //
         8'd20: init_byte = {1'b0, 8'hDB}; // VCOMH deselect
         8'd21: init_byte = {1'b0, 8'h40}; //
         8'd22: init_byte = {1'b0, 8'hA4}; // use GDDRAM
         8'd23: init_byte = {1'b0, 8'hAF}; // display ON
         default: init_byte = {1'b0, 8'hE3}; // NOP
      endcase
   endfunction

   // ── Address command lookup ────────────────────────────────────
   // Returns {dc, byte} for each of the 6 address setup commands
   // given the current region being updated
   function [8:0] addr_byte;
      input [1:0] region;
      input [3:0] idx;
      case ({region, idx})
         // Root region: cols 32-63, pages 0-5
         {REGION_ROOT, 4'd0}: addr_byte = {1'b0, 8'h21};          // set col addr
         {REGION_ROOT, 4'd1}: addr_byte = {1'b0, COL_ROOT_START};  // start col
         {REGION_ROOT, 4'd2}: addr_byte = {1'b0, COL_ROOT_END};    // end col
         {REGION_ROOT, 4'd3}: addr_byte = {1'b0, 8'h22};          // set page addr
         {REGION_ROOT, 4'd4}: addr_byte = {1'b0, PAGE_TOP};        // start page
         {REGION_ROOT, 4'd5}: addr_byte = {1'b0, PAGE_BOT};        // end page

         // Quality region: cols 96-127, pages 3-5
         {REGION_QUAL, 4'd0}: addr_byte = {1'b0, 8'h21};
         {REGION_QUAL, 4'd1}: addr_byte = {1'b0, COL_RIGHT_START};
         {REGION_QUAL, 4'd2}: addr_byte = {1'b0, COL_RIGHT_END};
         {REGION_QUAL, 4'd3}: addr_byte = {1'b0, 8'h22};
         {REGION_QUAL, 4'd4}: addr_byte = {1'b0, PAGE_MID};
         {REGION_QUAL, 4'd5}: addr_byte = {1'b0, PAGE_BOT};

         // Debug region: cols 96-127, pages 0-2
         {REGION_DEBUG, 4'd0}: addr_byte = {1'b0, 8'h21};
         {REGION_DEBUG, 4'd1}: addr_byte = {1'b0, COL_RIGHT_START};
         {REGION_DEBUG, 4'd2}: addr_byte = {1'b0, COL_RIGHT_END};
         {REGION_DEBUG, 4'd3}: addr_byte = {1'b0, 8'h22};
         {REGION_DEBUG, 4'd4}: addr_byte = {1'b0, PAGE_TOP};
         {REGION_DEBUG, 4'd5}: addr_byte = {1'b0, PAGE_MID - 1};  // end page 2

         default: addr_byte = {1'b0, 8'hE3}; // NOP
      endcase
   endfunction

   // ── State machine states ──────────────────────────────────────
   localparam ST_RESET      = 4'd0;
   localparam ST_RESET_WAIT = 4'd1;
   localparam ST_INIT       = 4'd2;
   localparam ST_INIT_WAIT  = 4'd3;
   localparam ST_DISP_ON    = 4'd4; // folded into init_byte[23]
   localparam ST_IDLE       = 4'd5;
   localparam ST_ADDR_CMD   = 4'd6;
   localparam ST_ADDR_WAIT  = 4'd7;
   localparam ST_COPY       = 4'd8;
   localparam ST_COPY_WAIT  = 4'd9;

   reg [3:0]  state;
   reg [7:0]  init_idx;
   reg [10:0] copy_idx;
   reg [10:0] copy_len;
   reg [11:0] rom_base;
   reg [3:0]  addr_idx;
   reg [23:0] wait_cnt;

   // ── SPI write/idle tasks ──────────────────────────────────────
   task spi_write_byte;
      input [7:0] data;
      begin
         spi_wb_cyc  <= 1;
         spi_wb_stb  <= 1;
         spi_wb_we   <= 1;
         spi_wb_addr <= 2'b00;
         spi_wb_wdat <= data;
      end
   endtask

   task spi_idle;
      begin
         spi_wb_cyc <= 0;
         spi_wb_stb <= 0;
         spi_wb_we  <= 0;
      end
   endtask

   // ── Main FSM ──────────────────────────────────────────────────
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state          <= ST_RESET;
         oled_rst_n     <= 0;
         oled_dc        <= 0;
         root           <= 8'd0;
         quality        <= 3'd0;
         root_dirty     <= 1;
         qual_dirty     <= 1;
         current_region <= REGION_ROOT;
         init_idx       <= 0;
         copy_idx       <= 0;
         copy_len       <= 0;
         rom_base       <= 0;
         rom_addr       <= 0;
         rom_en         <= 0;
         addr_idx       <= 0;
         wait_cnt       <= 0;
         spi_wb_cyc     <= 0;
         spi_wb_stb     <= 0;
         spi_wb_we      <= 0;
         spi_wb_addr    <= 0;
         spi_wb_wdat    <= 0;
         wb_ack         <= 0;
         wb_rdat        <= 0;
      end else begin

         if (spi_wb_ack) spi_idle();
         wb_ack <= 0;

         // ── Wishbone register interface ───────────────────────
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack <= 1;
            if (wb_we) begin
               case (wb_addr)
                  8'h00: begin
                     if (wb_wdat[3:0] != root[3:0]) begin
                        root       <= wb_wdat;
                        root_dirty <= 1;
                     end
                  end
                  8'h01: begin
                     if (wb_wdat[2:0] != quality) begin
                        quality    <= wb_wdat[2:0];
                        qual_dirty <= 1;
                     end
                  end
               endcase
            end else begin
               case (wb_addr)
                  8'h00: wb_rdat <= root;
                  8'h01: wb_rdat <= {5'b0, quality};
               endcase
            end
         end

         // ── Display FSM ───────────────────────────────────────
         case (state)

            ST_RESET: begin
               oled_rst_n <= 0;
               wait_cnt   <= wait_cnt + 1;
               if (wait_cnt == RESET_PULSE_CYC) begin
                  oled_rst_n <= 1;
                  wait_cnt   <= 0;
                  state      <= ST_RESET_WAIT;
               end
            end

            ST_RESET_WAIT: begin
               wait_cnt <= wait_cnt + 1;
               if (wait_cnt == RESET_WAIT_CYC) begin
                  wait_cnt <= 0;
                  init_idx <= 0;
                  state    <= ST_INIT;
               end
            end

				ST_INIT: begin
				   if (!spi_wb_cyc) begin
				      if (init_idx < INIT_LEN) begin
				         oled_dc  <= cur_init_byte[8];
				         spi_write_byte(cur_init_byte[7:0]);
				         init_idx <= init_idx + 1;
				         state    <= ST_INIT_WAIT;
				      end else begin
				         state <= ST_IDLE;
				      end
				   end
				end

            ST_INIT_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_INIT;
               end
            end

            ST_IDLE: begin
               if (root_dirty) begin
                  current_region <= REGION_ROOT;
                  rom_base       <= NOTE_ROM_BASE + (root * NOTE_BYTES);
                  copy_len       <= NOTE_BYTES;
                  root_dirty     <= 0;
                  addr_idx       <= 0;
                  state          <= ST_ADDR_CMD;
               end else if (qual_dirty) begin
                  current_region <= REGION_QUAL;
                  rom_base       <= QUAL_ROM_BASE + (quality * QUAL_BYTES);
                  copy_len       <= QUAL_BYTES;
                  qual_dirty     <= 0;
                  addr_idx       <= 0;
                  state          <= ST_ADDR_CMD;
               end
            end


				ST_ADDR_CMD: begin
				   if (!spi_wb_cyc) begin
				      if (addr_idx < ADDR_CMD_LEN) begin
				         oled_dc  <= cur_addr_byte[8];
				         spi_write_byte(cur_addr_byte[7:0]);
				         addr_idx <= addr_idx + 1;
				         state    <= ST_ADDR_WAIT;
				      end else begin
				         oled_dc  <= 1;
				         copy_idx <= 0;
				         rom_en   <= 1;
				         rom_addr <= rom_base;
				         state    <= ST_COPY;
				      end
				   end
				end


            ST_ADDR_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_ADDR_CMD;
               end
            end

            ST_COPY: begin
               if (!spi_wb_cyc) begin
                  if (copy_idx < copy_len) begin
                     spi_write_byte(rom_data);
                     copy_idx <= copy_idx + 1;
                     if (copy_idx + 1 < copy_len)
                        rom_addr <= rom_base + copy_idx + 1;
                     else
                        rom_en <= 0;
                     state <= ST_COPY_WAIT;
                  end else begin
                     rom_en <= 0;
                     state  <= ST_IDLE;
                  end
               end
            end

            ST_COPY_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_COPY;
               end
            end

            default: state <= ST_IDLE;

         endcase
      end
   end

endmodule
