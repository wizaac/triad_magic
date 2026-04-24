// hdl/chord_channel.v
// One physical channel: ADC reader + display driver.
// Chord engine and ADC decoder are not yet included.
//

// ── Address map ───────────────────────────────────────────────────────────
//   0x00-0x0F : chord_channel top-level regs (self)
//     0x00 : reg_bass_note  [7:0]
//     0x01 : reg_mid_note   [7:0]
//     0x02 : reg_high_note  [7:0]
//     0x03 : reg_length     [7:0]
//   0x10-0x1F : display_driver
//     0x10 : root      (display_driver 0x00)
//     0x11 : quality   (display_driver 0x01)
//     0x12 : adc_ch[0] (display_driver 0x02)
//     0x13 : adc_ch[1] (display_driver 0x03)
//     0x14 : adc_ch[2] (display_driver 0x04)
//     0x15 : adc_ch[3] (display_driver 0x05)
//   0x20-0x2F : adc_reader
//     0x20 : pot[0] raw [7:0]
//     0x21 : pot[1] raw [7:0]
//     0x22 : pot[2] raw [7:0]
//     0x23 : pot[3] raw [7:0]
//   0x30-0x3F : chord_engine  (reserved)
//   0x40-0x4F : adc_decoder   (reserved)
//
// ── SPI bus sharing ───────────────────────────────────────────────────────
// OLED and ADC share MOSI and SCLK lines on the breadboard.
// OLED takes priority: when oled_cs_n is low it owns the bus.
// ADC may be interrupted mid-transaction — acceptable since pot values
// refresh in milliseconds and a missed sample is undetectable.
//
// ── Sequencer overview ────────────────────────────────────────────────────
// Top-level state machine:
//   RESET → INIT → RUN_FORKLIFT_ROUTE → WAIT → RUN_FORKLIFT_ROUTE → WAIT → ...
//
// Within RUN_FORKLIFT_ROUTE, a two-level program counter drives the bus:
//   pc  : instruction index into forklift_route[]
//   mov_step : microcode step (READ_ASSERT → READ_WAIT → WRITE_ASSERT → WRITE_WAIT)
//
// Each instruction is a move: read src address, write dst address.
// Module selection is implicit in the address page (top 4 bits).
// Local register reads/writes bypass the bus entirely.



module chord_channel #(
    parameter SSD1306_CLK_DIV = 5,    // 100MHz / (2*5) = 10MHz
    parameter MCP3204_CLK_DIV = 50    // 100MHz / (2*50) = 1MHz
)(
    input  wire       clk,
    input  wire        rst_n,
    // ── Parent wishbone (read channel state) ──────────────────────────────
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [3:0]  wb_addr_i,
    input  wire [7:0]  wb_wdat_i,
    output reg  [7:0]  wb_rdat_o,
    output reg         wb_ack_o,

    // ── OLED SPI ──────────────────────────────────────────────────────────
    output wire        oled_sclk,
    output wire        oled_mosi,
    output wire        oled_cs_n,
    output wire        oled_dc,
    output wire        oled_rst_n,

    // ── ADC SPI ───────────────────────────────────────────────────────────
    output wire        adc_sclk,
    output wire        adc_mosi,
    input  wire        adc_miso,
    output wire        adc_cs_n,

    // ── Shared ROM read port ──────────────────────────────────────────────
    output wire [11:0] rom_addr,
    output wire        rom_en,
    input  wire [7:0]  rom_data,

    // ── Testbus outputs ───────────────────────────────────────────────────
    output wire [7:0]  testbus,   // chord_channel FSM state
    input  wire [7:0]  testbus_sel  
);

// ── Channel state registers ───────────────────────────────────────────────
localparam REG_BASS_NOTE	= 8'h00;
localparam REG_MID_NOTE		= 8'h01;
localparam REG_HIGH_NOTE	= 8'h02;
localparam REG_CHORD_LENGTH= 8'h03;
reg [7:0] reg_bass_note;
reg [7:0] reg_mid_note;
reg [7:0] reg_high_note;
reg [7:0] reg_chord_length;

// ── Top-level wishbone handler ────────────────────────────────────────────
// Exposes channel state registers to the parent module.
// Completely independent of the internal sequencer bus.
reg [7:0] self_rdat;
reg       self_ack;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        self_ack      <= 0;
        self_rdat     <= 0;
        wb_ack_o    <= 0;
        wb_rdat_o   <= 0;
    end else begin
        wb_ack_o <= 0;
        if (wb_cyc_i && wb_stb_i && !wb_ack_o) begin
            wb_ack_o <= 1;
            if (wb_we_i) begin
                case (wb_addr_i)
						default: begin end
                    //These are read-only regs REG_BASS_NOTE  :reg_bass_note <= wb_wdat;
                    //These are read-only regs REG_MID_NOTE   :reg_mid_note  <= wb_wdat;
                    //These are read-only regs REG_HIGH_NOTE  :reg_high_note <= wb_wdat;
                    //These are read-only regs REG_CHORD_LENGTH:reg_chord_length    <= wb_wdat;
                endcase
            end else begin
                case (wb_addr_i)
                    REG_BASS_NOTE   : wb_rdat_o <=reg_bass_note;
                    REG_MID_NOTE    : wb_rdat_o <=reg_mid_note;
                    REG_HIGH_NOTE   : wb_rdat_o <=reg_high_note;
                    REG_CHORD_LENGTH: wb_rdat_o <=reg_chord_length;
                    default: wb_rdat_o <= 8'hFF;
                endcase
            end
        end
    end
end


// ── Internal shared wishbone bus ──────────────────────────────────────────
// Driven exclusively by the sequencer.
// Slaves are gated by sel_* — unselected modules see cyc/stb low.
// rdat and ack are OR-reduced: safe because exactly one sel_* is high
// at a time and unselected modules reset their outputs to zero.
reg        wb_cyc;
reg        wb_stb;
reg        wb_we;
reg  [7:0] wb_addr;
reg  [7:0] wb_wdat;

// Per-slave response wires
wire [7:0] disp_wb_rdat;
wire       disp_wb_ack;
wire [7:0] adc_wb_rdat;
wire       adc_wb_ack;

// OR-reduced bus response
wire [7:0] wb_rdat = disp_wb_rdat | adc_wb_rdat;
wire       wb_ack  = disp_wb_ack  | adc_wb_ack;

// Address page decode — top 4 bits select the module
wire sel_disp  = (wb_addr[7:4] == 4'h1);
wire sel_adc   = (wb_addr[7:4] == 4'h2);
wire sel_chord = (wb_addr[7:4] == 4'h3);  // reserved
wire sel_dec   = (wb_addr[7:4] == 4'h4);  // reserved

// ── Display driver ────────────────────────────────────────────────────────
wire [7:0] disp_testbus_raw;
assign testbus_disp = disp_testbus_raw;


// ── Display driver ────────────────────────────────────────────────────────
display_driver #(
    .CLK_DIV (SSD1306_CLK_DIV)
) disp (
    .clk        (clk),
    .rst_n      (rst_n),
    .testbus    (testbus),
    .wb_cyc     (wb_cyc & sel_disp),
    .wb_stb     (wb_stb & sel_disp),
    .wb_we      (wb_we),
    .wb_addr    ({4'h0,wb_addr[3:0]}),           // display driver uses [3:0] internally; slice data since top byte=module select, bottom byte= reg in that module
    .wb_wdat    (wb_wdat),
    .wb_rdat    (disp_wb_rdat),
    .wb_ack     (disp_wb_ack),
    .spi_sclk   (oled_sclk),
    .spi_mosi   (oled_mosi),
    .spi_cs_n   (oled_cs_n),
    .oled_dc    (oled_dc),
    .oled_rst_n (oled_rst_n),
    .rom_addr   (rom_addr),
    .rom_data   (rom_data),
    .rom_en     (rom_en)
);

// ── ADC reader ────────────────────────────────────────────────────────────
adc_reader #(
    .CLK_DIV    (MCP3204_CLK_DIV)
) adc (
    .clk      (clk),
    .rst_n    (rst_n),
    .wb_cyc   (wb_cyc & sel_adc),
    .wb_stb   (wb_stb & sel_adc),
    .wb_we    (wb_we),
    .wb_addr  (wb_addr[2:0]),
    .wb_rdat  (adc_wb_rdat),
    .wb_ack   (adc_wb_ack),
    .spi_sclk (adc_sclk),
    .spi_mosi (adc_mosi),
    .spi_miso (adc_miso),
    .spi_cs_n (adc_cs_n)
);

// ── Address map base addresses ────────────────────────────────────────────
localparam BASE_SELF  = 8'h00;
localparam BASE_DISP  = 8'h10;
localparam BASE_ADC   = 8'h20;
localparam BASE_CHORD = 8'h30;   // reserved
localparam BASE_DEC   = 8'h40;   // reserved

// ── Microcode step encoding ───────────────────────────────────────────────
// This sequencer executes a MOV instruction between connected address space wishbone entities
localparam MOV_READ_WB  = 2'd0;
localparam MOV_READ_WB_WAIT_ACK    = 2'd1;
localparam MOV_WRITE_WB = 2'd2;
localparam MOV_READ_WB_WRITE_WAIT_ACK   = 2'd3;

// ── Program ROM ───────────────────────────────────────────────────────────
// Each instruction: { src_addr[7:0], dst_addr[7:0] }
// Module is implicit in the address page — no separate mod field.
// NOPs are self→self moves (BASE_SELF|0x00 → BASE_SELF|0x00).
// Slots 8-11 are placeholders for chord engine / decoder moves.

localparam FORKLIFT_ROUTE_LEN = 12;
localparam INSTR_W  = 6;


// The program — edit this to change what the sequencer does each frame
reg [INSTR_W-1:0] forklift_route [0:FORKLIFT_ROUTE_LEN-1];
// Internal bus register map
localparam REG_SELF_BASS      = 8'h00;
localparam REG_SELF_MID       = 8'h01;
localparam REG_SELF_HIGH      = 8'h02;
localparam REG_SELF_LENGTH    = 8'h03;

localparam REG_DISP_ROOT      = 8'h10;
localparam REG_DISP_QUALITY   = 8'h11;
localparam REG_DISP_ADC_CH0   = 8'h12;
localparam REG_DISP_ADC_CH1   = 8'h13;
localparam REG_DISP_ADC_CH2   = 8'h14;
localparam REG_DISP_ADC_CH3   = 8'h15;

localparam REG_ADC_POT0       = 8'h20;
localparam REG_ADC_POT1       = 8'h21;
localparam REG_ADC_POT2       = 8'h22;
localparam REG_ADC_POT3       = 8'h23;
initial begin
    //              src address              dst address
    forklift_route[0]  = { REG_ADC_POT0,  REG_DISP_ADC_CH0};  // pot[0] → disp adc_ch[0]
    forklift_route[1]  = { REG_ADC_POT1,  REG_DISP_ADC_CH1};  // pot[1] → disp adc_ch[1]
    forklift_route[2]  = { REG_ADC_POT2,  REG_DISP_ADC_CH2};  // pot[2] → disp adc_ch[2]
    forklift_route[3]  = { REG_ADC_POT3,  REG_DISP_ADC_CH3};  // pot[3] → disp adc_ch[3]
    forklift_route[4]  = { REG_ADC_POT0,  REG_DISP_ROOT   };  // pot[0] → disp root
    forklift_route[5]  = { REG_ADC_POT1,  REG_DISP_QUALITY};  // pot[1] → disp quality
end


// ── Sequencer registers ───────────────────────────────────────────────────
reg [3:0]  pc;           // instruction pointer
reg [1:0]  mov_step;          // microcode step within current instruction
reg [7:0]  tmp_dat;      // data latched from src read, forwarded to dst write
reg        forklift_route_done;    // pulses high when last instruction acks
// ── Decode current instruction ────────────────────────────────────────────
wire [7:0] cur_src_addr = forklift_route[pc][15:8];
wire [7:0] cur_dst_addr = forklift_route[pc][7:0];

wire src_is_self = (cur_src_addr[7:4] == 4'h0);
wire dst_is_self = (cur_dst_addr[7:4] == 4'h0);


// ── Top-level state machine ───────────────────────────────────────────────
localparam SEQ_RESET    = 2'd0;
localparam SEQ_INIT     = 2'd1;
localparam SEQ_RUN_FORKLIFT_ROUTE = 2'd2;
localparam SEQ_WAIT     = 2'd3;

reg [1:0]  seq_state;
reg [26:0] wait_cnt;

// One millisecond at 100MHz — tune to taste
localparam SAMPLE_PERIOD = 27'd100_000;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        seq_state <= SEQ_RESET;
        wait_cnt  <= 0;
    end else begin
        case (seq_state)
            SEQ_RESET: begin
                seq_state <= SEQ_INIT;
            end

            SEQ_INIT: begin
                // One-shot: clear PC, let display driver finish its own init
                // The display driver handles SSD1306 init autonomously after rst_n.
                // We just need to wait until it reaches ST_IDLE before writing to it.
                // For now transition immediately — display driver queues writes internally.
                seq_state <= SEQ_RUN_FORKLIFT_ROUTE;
            end
				//FIXME a more general case would have a load program/select program state here
				// We only have forklift so we load that one. This might even be better as a "processor enable" state than a load program
            SEQ_RUN_FORKLIFT_ROUTE: begin
                if (forklift_route_done)
                    seq_state <= SEQ_WAIT;
					 else
						  seq_state <= SEQ_RUN_FORKLIFT_ROUTE;
            end

            SEQ_WAIT: begin
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt == SAMPLE_PERIOD) begin
                    wait_cnt  <= 0;
                    seq_state <= SEQ_RUN_FORKLIFT_ROUTE;
                end
            end
        endcase
    end
end



// ── Wishbone bus tasks ────────────────────────────────────────────────────
// All internal bus driving goes through these — never assign wb_* directly.

task wb_read;
    input [7:0] addr;
    begin
        wb_cyc  <= 1;
        wb_stb  <= 1;
        wb_we   <= 0;
        wb_addr <= addr;
    end
endtask

task wb_write;
    input [7:0] addr;
    input [7:0] data;
    begin
        wb_cyc  <= 1;
        wb_stb  <= 1;
        wb_we   <= 1;
        wb_addr <= addr;
        wb_wdat <= data;
    end
endtask

task wb_deassert;
    begin
        wb_cyc <= 0;
        wb_stb <= 0;
        wb_we  <= 0;
    end
endtask

task advance_pc;
    begin
        if (pc == FORKLIFT_ROUTE_LEN - 1) begin
            forklift_route_done <= 1;
            pc        <= 0;
        end else begin
            pc <= pc + 1;
        end
    end
endtask

// ── Sequencer execute block ───────────────────────────────────────────────
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc        <= 0;
        mov_step       <= MOV_READ_WB;
        tmp_dat   <= 0;
        forklift_route_done <= 0;
        wb_deassert();
        wb_wdat   <= 0;
    end else if (seq_state == SEQ_RUN_FORKLIFT_ROUTE) begin
        forklift_route_done <= 0;

        case (mov_step)

            MOV_READ_WB: begin
                if (src_is_self) begin
                    // Local register read — no bus latency, latch and skip ahead
                    case (cur_src_addr[3:0])
                        4'h0: tmp_dat <= reg_bass_note;
                        4'h1: tmp_dat <= reg_mid_note;
                        4'h2: tmp_dat <= reg_high_note;
                        4'h3: tmp_dat <= reg_chord_length;
                        default: tmp_dat <= 8'hFF;
                    endcase
                    mov_step <= MOV_WRITE_WB;
                end else begin
                    wb_read(cur_src_addr);
                    mov_step <= MOV_READ_WB_WAIT_ACK;
                end
            end

            MOV_READ_WB_WAIT_ACK: begin
                if (wb_ack) begin
                    tmp_dat <= wb_rdat;
                    wb_deassert();
                    mov_step <= MOV_WRITE_WB;
                end
            end

            MOV_WRITE_WB: begin
                if (dst_is_self) begin
                    // Local register write — no bus latency
                    case (cur_dst_addr[3:0])
                        4'h0: reg_bass_note <= tmp_dat;
                        4'h1: reg_mid_note  <= tmp_dat;
                        4'h2: reg_high_note <= tmp_dat;
                        4'h3: reg_chord_length    <= tmp_dat;
                    endcase
                    mov_step <= MOV_READ_WB;
                    advance_pc();
                end else begin
                    wb_write(cur_dst_addr, tmp_dat);
                    mov_step <= MOV_READ_WB_WRITE_WAIT_ACK;
                end
            end

            MOV_READ_WB_WRITE_WAIT_ACK: begin
                if (wb_ack) begin
                    wb_deassert();
                    mov_step <= MOV_READ_WB;
                    advance_pc();
                end
            end

        endcase
    end else begin
        // Outside RUN_FORKLIFT_ROUTE — hold bus idle, reset PC ready for next run
        pc        <= 0;
        mov_step       <= MOV_READ_WB;
        forklift_route_done <= 0;
        wb_deassert();
    end
end
endmodule
