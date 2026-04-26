module chord_engine #(
   parameter LINEAR = 0//LOG if not LIN
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
   output reg         wb_ack
);


   // ── Quality encoding ──────────────────────────────────────────
   localparam QUAL_SUS2  = 3'd0;
   localparam QUAL_SUS4  = 3'd1;
   localparam QUAL_MAJ   = 3'd2;
   localparam QUAL_MIN   = 3'd3;
   localparam QUAL_DIM   = 3'd4;
   localparam QUAL_AUG   = 3'd5;
   localparam QUAL_POW   = 3'd7;  // all the way right = power chord


localparam REG_CHORD_ROOT_RAW_ADDR 		= 4'h0;
localparam REG_CHORD_QUALITY_RAW_ADDR 	= 4'h1;
localparam REG_CHORD_INVERSION_RAW_ADDR= 4'h2;
localparam REG_CHORD_LENGTH_RAW_ADDR	= 4'h3;

localparam REG_CHORD_ROOT_NOTE_ADDR 	= 4'h4;
localparam REG_CHORD_BASS_NOTE_ADDR 	= 4'h5;
localparam REG_CHORD_MID_NOTE_ADDR 		= 4'h6;
localparam REG_CHORD_HIGH_NOTE_ADDR 	= 4'h7;
localparam REG_CHORD_DURATION_ADDR 		= 4'h8;
localparam REG_CHORD_QUALITY_ADDR 		= 4'h9;
localparam REG_CHORD_STATUS_ADDR 		= 4'ha;


	reg [7:0] reg_chord_root_raw;//r/w
	reg [7:0] reg_chord_quality_raw;//r/w
	reg [7:0] reg_chord_inversion_raw;//r/w
	reg [7:0] reg_chord_length_raw;//rw/

	reg [7:0] reg_chord_root_note;//RO
	reg [7:0] reg_chord_bass_note;//RO
	reg [7:0] reg_chord_mid_note;//RO
	reg [7:0] reg_chord_high_note;//RO
	reg [7:0] reg_chord_duration;//RO
	reg [7:0] reg_chord_quality;//RO

	reg invalid_read_err;
	reg invalid_write_err;

         // ── Wishbone register interface ───────────────────────
   always @(posedge clk or negedge rst_n) begin
      if (rst_n) begin
			wb_ack <= 0;
			wb_rdat<='0;
         if (wb_cyc && wb_stb && !wb_ack) begin
            wb_ack <= 1;
				//WRITES
            if (wb_we) begin
               case (wb_addr)
                 REG_CHORD_ROOT_RAW_ADDR : begin
                     if (wb_wdat != reg_chord_root_raw) begin
                        reg_chord_root_raw       <= wb_wdat;
                     end
                  end
                  REG_CHORD_QUALITY_RAW_ADDR: begin
                     if (wb_wdat != reg_chord_quality_raw) begin
                        reg_chord_quality_raw    <= wb_wdat;
                     end
                  end
                 REG_CHORD_INVERSION_RAW_ADDR : begin
                     if (wb_wdat != reg_chord_inversion_raw) begin
                        reg_chord_inversion_raw       <= wb_wdat;
                     end
                  end
                 REG_CHORD_LENGTH_RAW_ADDR : begin
                     if (wb_wdat != reg_chord_length_raw) begin
                        reg_chord_length_raw       <= wb_wdat;
                     end
                  end
					default : invalid_write_err <= 1;
               endcase
            end else begin
				//READS
               case (wb_addr)
						REG_CHORD_ROOT_RAW_ADDR 		: wb_rdat <= reg_chord_root_raw;
						REG_CHORD_QUALITY_RAW_ADDR 	: wb_rdat <= reg_chord_quality_raw;
						REG_CHORD_INVERSION_RAW_ADDR 	: wb_rdat <= reg_chord_inversion_raw;
						REG_CHORD_LENGTH_RAW_ADDR 		: wb_rdat <= reg_chord_length_raw;
						REG_CHORD_ROOT_NOTE_ADDR		: wb_rdat <= reg_chord_root_note;	
						REG_CHORD_BASS_NOTE_ADDR		: wb_rdat <= reg_chord_bass_note;	
						REG_CHORD_MID_NOTE_ADDR			: wb_rdat <= reg_chord_mid_note; 		
						REG_CHORD_HIGH_NOTE_ADDR 		: wb_rdat <= reg_chord_high_note;	
						REG_CHORD_DURATION_ADDR 		: wb_rdat <= reg_chord_duration;	
						REG_CHORD_QUALITY_ADDR 			: wb_rdat <= reg_chord_quality;	
						REG_CHORD_STATUS_ADDR 			: wb_rdat <= {invalid_write_err,invalid_read_err,6'h00};	
						default: begin invalid_read_err <= 1; wb_rdat <=8'h00;end
               endcase
            end
         end
		end else begin
		//reset
			wb_ack <= 0;
			wb_rdat<='0;
			reg_chord_root_raw		<= '0;//r/w
			reg_chord_quality_raw	<= '0;//r/w
			reg_chord_inversion_raw	<= '0;//r/w
			reg_chord_length_raw		<= '0;//rw/
			invalid_read_err			<= '0;
			invalid_write_err			<= '0;
		end
	end//always


	//params for each note
	`include "notes.v"
	// gives us pot_to_8, pot_to12, pot_to_16 functions for decoding our audio-taper pots.
	`include "pot_decoder.v"
parameter ROOT_OCTAVE = 3;  // change this to shift whole instrument up/down

// ── Layer 1a: quality → interval vector ──────────────────────
reg [7:0] bass,mid,high;
wire [3:0] inversion=pot_to_16(reg_chord_inversion_raw);
reg [3:0] duration;
wire [7:0]  root =pot_to_12(reg_chord_root_raw);
wire [7:0] root_note = (ROOT_OCTAVE * 12) + root;
wire [2:0] quality = pot_to_8(reg_chord_quality_raw);

always @(*) begin
	bass = 8'h00;
	mid = 8'h00;
	high = 8'h00;
    case (quality)
        QUAL_SUS2: begin bass = root_note;      mid = root_note + 8'd2;  high = root_note + 8'd7;  end
        QUAL_SUS4: begin bass = root_note;      mid = root_note + 8'd5;  high = root_note + 8'd7;  end
        QUAL_DIM:  begin bass = root_note;      mid = root_note + 8'd3;  high = root_note + 8'd6;  end
        QUAL_MIN:  begin bass = root_note;      mid = root_note + 8'd3;  high = root_note + 8'd7;  end
        QUAL_MAJ:  begin bass = root_note;      mid = root_note + 8'd4;  high = root_note + 8'd7;  end
        QUAL_AUG:  begin bass = root_note;      mid = root_note + 8'd4;  high = root_note + 8'd8;  end
        QUAL_POW:  begin bass = root_note;      mid = root_note + 8'd7;  high = root_note + 8'd12; end
        default:   begin bass = root_note;      mid = root_note + 8'd4;  high = root_note + 8'd7;  end
    endcase
end

// ── Layer 1b: inversion → octave vector ──────────────────────
wire [23:0] oct_vec = inv_vector(inversion);
wire [7:0]  bass_oct = oct_vec[23:16];
wire [7:0]  mid_oct  = oct_vec[15:8];
wire [7:0]  high_oct = oct_vec[7:0];

// ── Layer 2: add octave vector to interval vector ─────────────
wire [7:0] bass_inv = bass + bass_oct;
wire [7:0] mid_inv  = mid  + mid_oct;
wire [7:0] high_inv = high + high_oct;

// ── Layer 3: sort network (3-element, 3 compare-and-swap) ─────
// swap(a,b) puts lower in a, higher in b
wire [7:0] s0_bass, s0_mid, s0_high;
wire [7:0] s1_bass, s1_mid, s1_high;
wire [7:0] s2_bass, s2_mid, s2_high;

// step 1: swap bass/mid
assign s0_bass = (bass_inv <= mid_inv)  ? bass_inv : mid_inv;
assign s0_mid  = (bass_inv <= mid_inv)  ? mid_inv  : bass_inv;
assign s0_high = high_inv;

// step 2: swap mid/high
assign s1_bass = s0_bass;
assign s1_mid  = (s0_mid <= s0_high)   ? s0_mid   : s0_high;
assign s1_high = (s0_mid <= s0_high)   ? s0_high  : s0_mid;

// step 3: swap bass/mid again to finish
assign s2_bass = (s1_bass <= s1_mid)   ? s1_bass  : s1_mid;
assign s2_mid  = (s1_bass <= s1_mid)   ? s1_mid   : s1_bass;
assign s2_high = s1_high;

assign bass_sorted = s2_bass;
assign mid_sorted  = s2_mid;
assign high_sorted = s2_high;



   always @(posedge clk or negedge rst_n) begin
		if(rst_n) begin
			reg_chord_root_note		= root;//RO
			reg_chord_bass_note		= bass_sorted;//RO
			reg_chord_mid_note		= mid_sorted;//RO
			reg_chord_high_note		= high_sorted;//RO
			reg_chord_duration		= {4'h0, duration};//RO
			reg_chord_quality			= {5'h00,quality};//RO
		end else begin 
			reg_chord_root_note		= '0;//RO
			reg_chord_bass_note		= '0;//RO
			reg_chord_mid_note		= '0;//RO
			reg_chord_high_note		= '0;//RO
			reg_chord_duration		= '0;//RO
			reg_chord_quality			= '0;//RO
		end
	end




endmodule

