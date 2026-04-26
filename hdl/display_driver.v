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
	output wire [7:0]  testbus,
   // Wishbone slave
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [7:0]  wb_addr,
   input  wire [7:0]  wb_wdat,
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack,

	output reg 		 	 oled_rst_n,
   output wire        oled_dc,
   // SPI physical pins
   output wire        spi_sclk,
   output wire        spi_mosi,
   output wire        spi_cs_n,

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

localparam COL_NOTE_START  = 8'h20;  // col 32
localparam COL_NOTE_END    = 8'h38;  // col 56  (25 cols)
localparam COL_RIGHT_START = 8'h39;  // col 57
localparam COL_RIGHT_END   = 8'h5F;  // col 95  (39 cols)
localparam PAGE_TOP        = 8'h00;
localparam PAGE_ADC_END    = 8'h01;  // ADC pages 0-1
localparam PAGE_QUAL_START = 8'h02;  // reg_chord_quality pages 2-5
localparam PAGE_BOT        = 8'h05;

localparam NOTE_BYTES      = 11'd150;  // 25 cols x 6 pages
localparam QUAL_BYTES      = 11'd156;   // 39 cols x 4 pages
localparam NOTE_ROM_BASE   = 12'h000;
localparam QUAL_ROM_BASE   = 12'h708;

localparam REGION_NOTE  = 2'd0;
localparam REGION_QUAL  = 2'd1;
localparam REGION_ADC   = 2'd2;
   // Init sequence length
   localparam INIT_LEN        = 8'd24;   // 23 init bytes + display on

   // Reset timing
   localparam RESET_PULSE_CYC = 24'd1000;       // ~10us at 100MHz
   localparam RESET_WAIT_CYC  = 24'd10_000_000; // 100ms at 100MHz
   // Reset timing


   // Address command sequence length
   localparam ADDR_CMD_LEN    = 4'd6;


	// Hex digit font: 16 glyphs × 5 cols × 1 page (5 bytes each = 80 bytes)
	// Bit0 = top pixel, 5-wide × 7-tall glyphs in an 8-row page

	function [7:0] hex_col;
   input [3:0] digit;
   input [2:0] col;   // 0-4
   reg [39:0] cols;   // 5 bytes for this digit
   begin
      case (digit)
         4'h0: cols = 40'h3E_41_41_41_3E;
         4'h1: cols = 40'h00_02_7F_00_00;
         4'h2: cols = 40'h43_61_51_49_47;
         4'h3: cols = 40'h43_41_41_41_3F;
         4'h4: cols = 40'h1F_08_08_08_7F;
         4'h5: cols = 40'h4F_49_49_49_71;
         4'h6: cols = 40'h3E_49_49_49_30;
         4'h7: cols = 40'h07_01_71_09_07;
         4'h8: cols = 40'h36_49_49_49_36;
         4'h9: cols = 40'h4F_49_49_49_7F;
         4'hA: cols = 40'h7E_09_09_09_7E;
         4'hB: cols = 40'h7F_49_49_49_36;
         4'hC: cols = 40'h7F_41_41_41_00;
         4'hD: cols = 40'h7F_41_41_22_1C;
         4'hE: cols = 40'h7F_49_49_49_41;
         4'hF: cols = 40'h7F_09_09_09_01;
         default: cols = 40'h0;
      endcase
      // cols[39:32]=col0, cols[31:24]=col1 ... cols[7:0]=col4
      hex_col = cols[39 - (col * 8) -: 8];
   end
endfunction

   // ── Internal registers ────────────────────────────────────────
   reg [7:0] reg_chord_root;
   reg [2:0] reg_chord_quality;
   reg       refresh_root_note;
   reg       refresh_chord_quality;
   reg [1:0] current_region;
	reg [8:0] init_byte_r;
	reg [8:0] addr_byte_r;

   // ── SPI master wishbone signals ───────────────────────────────
   reg        spi_wb_cyc, spi_wb_stb, spi_wb_we;
   reg  [1:0] spi_wb_addr;
   reg  [8:0] spi_wb_wdat;
   wire [8:0] spi_wb_rdat;
   wire       spi_wb_ack;
   wire       spi_miso;

	// Combinational wires — computed every cycle based on current state
	wire [8:0] cur_init_byte = init_byte(init_idx);
	wire [8:0] cur_addr_byte = addr_byte(current_region, addr_idx);

   // ── SPI master instantiation ──────────────────────────────────
   spi_master #(
      .DEVICE     ("SSD1306"),
      .USE_DC     (1),
      .WB_WIDTH   (9),
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
      .dc       (oled_dc),
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
// OLD cases used REGION_ROOT/QUAL/DEBUG with old col constants
// NEW — same structure, new constants and region names

function [8:0] addr_byte;
   input [1:0] region;
   input [3:0] idx;
   case ({region, idx})
      // NOTE: cols 32-56, pages 0-5
      {REGION_NOTE, 4'd0}: addr_byte = {1'b0, 8'h21};
      {REGION_NOTE, 4'd1}: addr_byte = {1'b0, COL_NOTE_START};
      {REGION_NOTE, 4'd2}: addr_byte = {1'b0, COL_NOTE_END};
      {REGION_NOTE, 4'd3}: addr_byte = {1'b0, 8'h22};
      {REGION_NOTE, 4'd4}: addr_byte = {1'b0, PAGE_TOP};
      {REGION_NOTE, 4'd5}: addr_byte = {1'b0, PAGE_BOT};

      // QUALITY: cols 57-95, pages 4-5
      {REGION_QUAL, 4'd0}: addr_byte = {1'b0, 8'h21};
      {REGION_QUAL, 4'd1}: addr_byte = {1'b0, COL_RIGHT_START};
      {REGION_QUAL, 4'd2}: addr_byte = {1'b0, COL_RIGHT_END};
      {REGION_QUAL, 4'd3}: addr_byte = {1'b0, 8'h22};
      {REGION_QUAL, 4'd4}: addr_byte = {1'b0, PAGE_QUAL_START};
      {REGION_QUAL, 4'd5}: addr_byte = {1'b0, PAGE_BOT};

      // ADC: cols 57-95, pages 0-3
      {REGION_ADC,  4'd0}: addr_byte = {1'b0, 8'h21};
      {REGION_ADC,  4'd1}: addr_byte = {1'b0, COL_RIGHT_START};
      {REGION_ADC,  4'd2}: addr_byte = {1'b0, COL_RIGHT_END};
      {REGION_ADC,  4'd3}: addr_byte = {1'b0, 8'h22};
      {REGION_ADC,  4'd4}: addr_byte = {1'b0, PAGE_TOP};
      {REGION_ADC,  4'd5}: addr_byte = {1'b0, PAGE_ADC_END};

      default: addr_byte = {1'b0, 8'hE3};
   endcase
endfunction
// Add alongside existing reg_chord_root/quality/refresh_root_note/refresh_chord_quality:
reg        refresh_adc;
reg [7:0] reg_adc_ch [0:3];
reg [1:0]  adc_pg;
reg [5:0]  adc_col;
reg        adc_done;


// Grid mapping:
//   pages 0-1, cols  0-18 : ch0   (top-left)
//   pages 0-1, cols 20-38 : ch1   (top-right)
//   pages 2-3, cols  0-18 : ch2   (bottom-left)
//   pages 2-3, cols 20-38 : ch3   (bottom-right)
//
// Each cell: 2 digits × 5 cols = 10 cols, 
//   left-padded by 4 cols so digits sit centered in 19-col half
// Col 19 is a blank separator between left and right cells

function [7:0] adc_byte;
   input [1:0] pg;
   input [5:0] col;
   reg [7:0]  chval;
   reg [3:0]  nibble;
   reg [5:0]  cell_col;   // col within the 19-col cell (0-18)
   reg        right_cell;
   reg [2:0]  digit_idx;
   reg [2:0]  col_in_digit;
   begin
      // col 19 is always blank separator
      if (col == 6'd19) begin
         adc_byte = 8'h00;
      end else begin
         right_cell = (col >= 6'd20);
         cell_col   = right_cell ? (col - 6'd20) : col;

         // channel select: top half = ch0/ch1, bottom half = ch2/ch3
         case ({pg[0], right_cell})
            2'b00: chval = reg_adc_ch[0];
            2'b01: chval = reg_adc_ch[1];
            2'b10: chval = reg_adc_ch[2];
            2'b11: chval = reg_adc_ch[3];
         endcase

         // 4px left pad then 2 digits (10 cols), rest blank
         // cols 0-3   : blank pad
         // cols 4-8   : digit 0 (high nibble), 5 cols
         // cols 9-13  : digit 1 (low nibble),  5 cols
         // cols 14-18 : blank pad
         if (cell_col < 6'd4 || cell_col >= 6'd14) begin
            adc_byte = 8'h00;
         end else begin
            digit_idx    = (cell_col < 6'd9) ? 3'd0 : 3'd1;
            col_in_digit = (cell_col < 6'd9) ? (cell_col - 6'd4)
                                              : (cell_col - 6'd9);
            nibble   = (digit_idx == 0) ? chval[7:4] : chval[3:0];
            adc_byte = hex_col(nibble, col_in_digit[2:0]);
         end
      end
   end
endfunction

// Add to state localparam block:
localparam ST_ADC_COPY   = 4'd11;
localparam ST_ADC_WAIT   = 4'd12;
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
   localparam ST_COPY_PRIME  = 4'd10;

	localparam REG_CHORD_ROOT_ADDR		= 8'h00;
	localparam REG_CHORD_QUALITY_ADDR	= 8'h01;
	localparam REG_ADC_CH_0_ADDR 	= 8'h02;
	localparam REG_ADC_CH_1_ADDR 	= 8'h03;
	localparam REG_ADC_CH_2_ADDR 	= 8'h04;
	localparam REG_ADC_CH_3_ADDR 	= 8'h05;
   reg [3:0]  state;
   reg [7:0]  init_idx;
   reg [10:0] copy_idx;
   reg [10:0] copy_len;
   reg [11:0] rom_base;
   reg [3:0]  addr_idx;
   reg [23:0] wait_cnt;

   // ── SPI write/idle tasks ──────────────────────────────────────
   task spi_write_byte;
      input [8:0] data;
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

	assign testbus = {state, refresh_chord_quality, refresh_root_note,refresh_adc,1'b0};

   // ── Main FSM ──────────────────────────────────────────────────
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         state          <= ST_RESET;
         oled_rst_n     <= 0;
         reg_chord_root           <= 8'h00;
         reg_chord_quality        <= 3'h0;
         refresh_root_note     <= 1;
         refresh_chord_quality     <= 1;
         current_region <= REGION_NOTE;
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
			refresh_adc      <= 1;
			adc_pg         <= 0;
			adc_col        <= 0;
			adc_done       <= 0;
			reg_adc_ch[0]      <= 8'hDE;
			reg_adc_ch[1]      <= 8'hAD;
			reg_adc_ch[2]      <= 8'hBE;
			reg_adc_ch[3]      <= 8'hEF;
      end else begin

         if (spi_wb_ack) spi_idle();
         wb_ack <= 0;
			wb_rdat<='0;
         // ── Wishbone register interface ───────────────────────
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack <= 1;
				
            if (wb_we) begin
               case (wb_addr)
                 REG_CHORD_ROOT_ADDR : begin
                     if (wb_wdat != reg_chord_root) begin
                        reg_chord_root       <= wb_wdat;
                        refresh_root_note <= 1;
                     end
                  end
                  REG_CHORD_QUALITY_ADDR: begin
                     if (wb_wdat[2:0] != reg_chord_quality) begin
                        reg_chord_quality    <= wb_wdat[2:0];
                        refresh_chord_quality <= 1;
                     end
                  end
						// Add to existing case (wb_addr) inside wb_we block:
						REG_ADC_CH_0_ADDR: begin reg_adc_ch[0] <= wb_wdat; refresh_adc <= 1; end
						REG_ADC_CH_1_ADDR: begin reg_adc_ch[1] <= wb_wdat; refresh_adc <= 1; end
						REG_ADC_CH_2_ADDR: begin reg_adc_ch[2] <= wb_wdat; refresh_adc <= 1; end
						REG_ADC_CH_3_ADDR: begin reg_adc_ch[3] <= wb_wdat; refresh_adc <= 1; end
               endcase
            end else begin
               case (wb_addr)
                  REG_CHORD_ROOT_ADDR: wb_rdat <= reg_chord_root;
                  REG_CHORD_QUALITY_ADDR :wb_rdat <= {5'b0, reg_chord_quality};
						default: wb_rdat <= 8'h00;
               endcase
            end
         end

         // ── Display FSM ───────────────────────────────────────
         case (state)

            ST_RESET: begin
               oled_rst_n <= 0;
               wait_cnt   <= wait_cnt + 1;
               if (wait_cnt >= RESET_PULSE_CYC) begin
                  oled_rst_n <= 1;
                  wait_cnt   <= 0;
                  state      <= ST_RESET_WAIT;
               end
            end

            ST_RESET_WAIT: begin
               wait_cnt <= wait_cnt + 1;
               if (wait_cnt >= RESET_WAIT_CYC) begin
                  wait_cnt <= 0;
                  init_idx <= 0;
                  state    <= ST_INIT;
               end
            end

				ST_INIT: begin
				   if (!spi_wb_cyc) begin
				      if (init_idx < INIT_LEN) begin
				         spi_write_byte(cur_init_byte);
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
				   if (refresh_root_note) begin
				      current_region <= REGION_NOTE;
				      rom_base       <= NOTE_ROM_BASE + (reg_chord_root[3:0] * NOTE_BYTES);
				      copy_len       <= NOTE_BYTES;
				      refresh_root_note     <= 0;
				      addr_idx       <= 0;
				      state          <= ST_ADDR_CMD;
				   end else if (refresh_chord_quality) begin
				      current_region <= REGION_QUAL;
				      rom_base       <= QUAL_ROM_BASE + ({9'b0, reg_chord_quality} * QUAL_BYTES);
				      copy_len       <= QUAL_BYTES;
				      refresh_chord_quality     <= 0;
				      addr_idx       <= 0;
				      state          <= ST_ADDR_CMD;
				   end else if (refresh_adc) begin
				      current_region <= REGION_ADC;
				      refresh_adc      <= 0;
				      addr_idx       <= 0;
				      state          <= ST_ADDR_CMD;
				   end
            end


				ST_ADDR_CMD: begin
				   if (!spi_wb_cyc) begin
				      if (addr_idx < ADDR_CMD_LEN) begin
				         spi_write_byte(cur_addr_byte);
				         addr_idx <= addr_idx + 1;
				         state    <= ST_ADDR_WAIT;
				      end else begin
							addr_idx <= 0;
							if (current_region == REGION_ADC) begin
							   adc_pg  <= 0;
							   adc_col <= 0;
							   state   <= ST_ADC_COPY;
							end else begin
							   copy_idx <= 0;
							   rom_en   <= 1;
							   rom_addr <= rom_base;
							   state    <= ST_COPY_PRIME;
							end
				      end
				   end
				end

            ST_ADDR_WAIT: begin
               if (spi_wb_ack) begin
                  spi_idle();
                  state <= ST_ADDR_CMD;
               end
            end

				// ST_COPY_PRIME:
				ST_COPY_PRIME: begin
				    state <= ST_COPY;  // rom_data now valid
				end

            ST_COPY: begin
               if (!spi_wb_cyc) begin
                  if (copy_idx < copy_len) begin
                     spi_write_byte({1'b1,rom_data});
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
				ST_ADC_COPY: begin
				   if (!spi_wb_cyc) begin
				      adc_done <= 0;
				      spi_write_byte({1'b1, adc_byte(adc_pg, adc_col)});
				      if (adc_col == 6'd38) begin
				         adc_col <= 0;
				         if (adc_pg == 2'd1) begin
				            adc_done <= 1;
				            adc_pg   <= 0;
				         end else begin
				            adc_pg <= adc_pg + 1;
				         end
				      end else begin
				         adc_col <= adc_col + 1;
				      end
				      state <= ST_ADC_WAIT;
				   end
				end
				
				ST_ADC_WAIT: begin
				   if (spi_wb_ack) begin
				      spi_idle();
				      state <= adc_done ? ST_IDLE : ST_ADC_COPY;
				   end
				end
            default: state <= ST_IDLE;

         endcase
      end
   end

endmodule
