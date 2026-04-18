// hdl/potentiometer_decoder.v
// Translates raw 8-bit pot values into musical parameters
// for the chord engine. Pure combinational logic — no clock needed
// for the decode itself, registered outputs for clean wishbone interface.
//
// Input pot mapping (from potentiometer_reader):
//   pot[0] = root      → 0-11  (12 note zones, top 4 bits / 16)
//   pot[1] = quality   → 0-7   (8 quality zones, top 3 bits)
//   pot[2] = spacing   → 0-11  (12 voicing presets, top 4 bits)
//   pot[3] = length    → pulse count (16 zones, top 4 bits)

module potentiometer_decoder (
   input  wire        clk,
   input  wire        rst_n,

   // Raw pot values from potentiometer_reader
   input  wire [7:0]  pot_root,
   input  wire [7:0]  pot_quality,
   input  wire [7:0]  pot_spacing,
   input  wire [7:0]  pot_length,

   // Wishbone slave
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [3:0]  wb_addr,
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack
);

   // ── Quality encoding ──────────────────────────────────────────
   localparam QUAL_SUS2  = 3'd0;
   localparam QUAL_SUS4  = 3'd1;
   localparam QUAL_MAJ   = 3'd2;
   localparam QUAL_MIN   = 3'd3;
   localparam QUAL_DIM   = 3'd4;
   localparam QUAL_AUG   = 3'd5;
   // 3'd6 spare
   localparam QUAL_PWR   = 3'd7;  // all the way right = power chord

   // ── Length encoding (pulse counts in 16th note units) ─────────
   localparam LEN_REST    = 7'd0;
   localparam LEN_16TH    = 7'd1;
   localparam LEN_D16TH   = 7'd2;   // dotted 16th = 1.5 × 16th
   localparam LEN_8TH     = 7'd2;   // same pulses as dotted 16th?
   // Actually let's be precise: if pulse = 16th note then:
   // 16th        = 1 pulse
   // dotted 16th = 1.5 pulses — not integer, skip
   // 8th         = 2 pulses
   // dotted 8th  = 3 pulses
   // quarter     = 4 pulses
   // dotted qtr  = 6 pulses
   // half        = 8 pulses
   // dotted half = 12 pulses
   // whole       = 16 pulses
   // dotted whole= 24 pulses
   // double whole= 32 pulses
   // 3 bars      = 48 pulses
   // 4 bars      = 64 pulses

   // ── Combinational decode ──────────────────────────────────────
   // root: top 4 bits give 0-15, clamp to 0-11
   wire [3:0] root_zone = pot_root[7:4];
   wire [3:0] root_out  = (root_zone > 4'd11) ? 4'd11 : root_zone;

   // quality: top 3 bits give 0-7 directly
   wire [2:0] quality_out = pot_quality[7:5];

   // spacing: top 4 bits give 0-15, clamp to 0-11
   wire [3:0] spacing_zone = pot_spacing[7:4];
   wire [3:0] spacing_out  = (spacing_zone > 4'd11) ? 4'd11 : spacing_zone;

   // length: top 4 bits select from pulse count table
   wire [3:0] length_zone = pot_length[7:4];
   reg  [6:0] length_out;

   always @(*) begin
      case (length_zone)
         4'd0:  length_out = 7'd0;   // rest
         4'd1:  length_out = 7'd1;   // 16th
         4'd2:  length_out = 7'd2;   // 8th
         4'd3:  length_out = 7'd3;   // dotted 8th
         4'd4:  length_out = 7'd4;   // quarter
         4'd5:  length_out = 7'd6;   // dotted quarter
         4'd6:  length_out = 7'd8;   // half
         4'd7:  length_out = 7'd12;  // dotted half
         4'd8:  length_out = 7'd16;  // whole
         4'd9:  length_out = 7'd24;  // dotted whole
         4'd10: length_out = 7'd32;  // double whole
         4'd11: length_out = 7'd48;  // 3 bars
         4'd12: length_out = 7'd64;  // 4 bars
         4'd13: length_out = 7'd64;  // spare (4 bars)
         4'd14: length_out = 7'd64;  // spare (4 bars)
         4'd15: length_out = 7'd64;  // spare (4 bars)
         default: length_out = 7'd4; // default quarter note
      endcase
   end

   // ── Spacing displacement vector lookup ───────────────────────
   // Each entry is {top_oct[1:0], mid_oct[1:0], root_oct[1:0]}
   // packed into 6 bits
   // chord engine applies: note[i] = root + interval[i] + oct[i]*12
   reg [5:0] spacing_vec;

   always @(*) begin
      case (spacing_out)
         4'd0:  spacing_vec = {2'd0, 2'd0, 2'd0}; // close root position
         4'd1:  spacing_vec = {2'd0, 2'd0, 2'd1}; // first inversion
         4'd2:  spacing_vec = {2'd0, 2'd1, 2'd1}; // second inversion
         4'd3:  spacing_vec = {2'd1, 2'd0, 2'd0}; // open top up
         4'd4:  spacing_vec = {2'd1, 2'd0, 2'd1}; // open first inv
         4'd5:  spacing_vec = {2'd1, 2'd1, 2'd0}; // open second inv
         4'd6:  spacing_vec = {2'd2, 2'd0, 2'd0}; // very open top
         4'd7:  spacing_vec = {2'd0, 2'd1, 2'd0}; // mid up
         4'd8:  spacing_vec = {2'd1, 2'd0, 2'd2}; // drop 2
         4'd9:  spacing_vec = {2'd2, 2'd1, 2'd0}; // wide spread
         4'd10: spacing_vec = {2'd2, 2'd0, 2'd1}; // pyramid
         4'd11: spacing_vec = {2'd2, 2'd1, 2'd1}; // max spread
         default: spacing_vec = 6'd0;
      endcase
   end

   // ── Wishbone register map ─────────────────────────────────────
   // 0x0: root_out    [3:0]
   // 0x1: quality_out [2:0]
   // 0x2: spacing_out [3:0]  voicing index
   // 0x3: spacing_vec [5:0]  displacement vector for chord engine
   // 0x4: length_out  [6:0]  pulse count
   // 0x5: pot_root    [7:0]  raw (debug)
   // 0x6: pot_quality [7:0]  raw (debug)
   // 0x7: pot_spacing [7:0]  raw (debug)
   // 0x8: pot_length  [7:0]  raw (debug)

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
      end
   end

endmodule
