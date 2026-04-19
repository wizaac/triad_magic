// hdl/pin_test_all.v
// Cycles through ALL iCE40 CB132 package pins one at a time
// Press reset button to advance to next pin
// Current pin number shown on LEDs
// Active pin driven LOW, all others HIGH
// Probe Br connector positions to find which physical pin is which

module pin_test_all (
   input  wire        clk,
   input  wire        rst_n,   // press to advance to next pin

   output wire        p_b1,
   output wire        p_c1,
   output wire        p_c3,
   output wire        p_d3,
   output wire        p_d1,
   output wire        p_e1,
   output wire        p_d4,
   output wire        p_e4,
   output wire        p_f4,
   output wire        p_f3,
   output wire        p_h4,
   output wire        p_g4,
   output wire        p_j3,
   output wire        p_j1,
   output wire        p_g3,
   output wire        p_g1,
   output wire        p_h1,
   output wire        p_h3,
   output wire        p_k3,
   output wire        p_k4,
   output wire        p_l1,
   output wire        p_m1,
   output wire        p_n1,
   output wire        p_p1,
   output wire        p_a1,
   output wire        p_a2,
   output wire        p_a3,
   output wire        p_a4,
   output wire        p_a5,
   output wire        p_c5,
   output wire        p_d5,
   output wire        p_c4,
   output wire        p_d4b,   // second use — skip, same pin
   output wire        p_e4b,
   output wire        p_f4b,
   output wire        p_c6,
   output wire        p_d6,
   output wire        p_c7,
   output wire        p_d7,
   output wire        p_a6,
   output wire        p_a7,
   output wire        p_c9,
   output wire        p_d9,
   output wire        p_c10,
   output wire        p_a10,
   output wire        p_a11,
   output wire        p_c11,
   output wire        p_d10,
   output wire        p_d11,
   output wire        p_a12,
   output wire        p_c12,
   output wire        p_b14,
   output wire        p_d12,
   output wire        p_c14,
   output wire        p_d14,
   output wire        p_e14,
   output wire        p_e12,
   output wire        p_e11,
   output wire        p_f11,
   output wire        p_f12,
   output wire        p_g11,
   output wire        p_g12,
   output wire        p_h11,
   output wire        p_h12,
   output wire        p_j12,
   output wire        p_g14,
   output wire        p_f14,

   output wire [7:0]  led
);

   // ── Button debounce ───────────────────────────────────────────
   // rst_n is active low, released = high
   // we advance on the rising edge (button release)
   reg [19:0] debounce_cnt;
   reg        rst_prev;
   reg        advance;

   always @(posedge clk) begin
      rst_prev <= rst_n;
      advance  <= 0;
      if (rst_n && !rst_prev) begin  // rising edge = button released
         if (debounce_cnt == 20'd0) begin
            advance      <= 1;
            debounce_cnt <= 20'd100_000; // 1ms debounce at 100MHz
         end
      end
      if (debounce_cnt > 0)
         debounce_cnt <= debounce_cnt - 1;
   end

   // ── Pin counter ───────────────────────────────────────────────
   reg [6:0] pin_num;  // 0-66, covers all CB132 IO pins

   always @(posedge clk) begin
      if (advance) begin
         if (pin_num == 7'd66)
            pin_num <= 0;
         else
            pin_num <= pin_num + 1;
      end
   end

   assign led = pin_num[7:0];

   // ── Drive selected pin low, all others high ───────────────────
   assign p_b1   = (pin_num == 7'd0)  ? 1'b0 : 1'b1;  // IOL_2A
   assign p_c1   = (pin_num == 7'd1)  ? 1'b0 : 1'b1;  // IOL_2B
   assign p_c3   = (pin_num == 7'd2)  ? 1'b0 : 1'b1;  // IOL_4A
   assign p_d3   = (pin_num == 7'd3)  ? 1'b0 : 1'b1;  // IOL_4B
   assign p_d1   = (pin_num == 7'd4)  ? 1'b0 : 1'b1;  // IOL_5A
   assign p_e1   = (pin_num == 7'd5)  ? 1'b0 : 1'b1;  // IOL_5B
   assign p_d4   = (pin_num == 7'd6)  ? 1'b0 : 1'b1;  // IOL_8A
   assign p_e4   = (pin_num == 7'd7)  ? 1'b0 : 1'b1;  // IOL_8B
   assign p_f4   = (pin_num == 7'd8)  ? 1'b0 : 1'b1;  // IOL_9A
   assign p_f3   = (pin_num == 7'd9)  ? 1'b0 : 1'b1;  // IOL_9B
   assign p_h4   = (pin_num == 7'd10) ? 1'b0 : 1'b1;  // IOL_10A
   assign p_g4   = (pin_num == 7'd11) ? 1'b0 : 1'b1;  // IOL_10B
   assign p_j3   = (pin_num == 7'd12) ? 1'b0 : 1'b1;  // IOL_12A
   assign p_j1   = (pin_num == 7'd13) ? 1'b0 : 1'b1;  // IOL_12B
   assign p_g3   = (pin_num == 7'd14) ? 1'b0 : 1'b1;  // IOL_13A
   assign p_g1   = (pin_num == 7'd15) ? 1'b0 : 1'b1;  // IOL_13B
   assign p_h1   = (pin_num == 7'd16) ? 1'b0 : 1'b1;  // IOL_14A
   assign p_h3   = (pin_num == 7'd17) ? 1'b0 : 1'b1;  // IOL_14B
   assign p_k3   = (pin_num == 7'd18) ? 1'b0 : 1'b1;  // IOL_18A
   assign p_k4   = (pin_num == 7'd19) ? 1'b0 : 1'b1;  // IOL_18B
   assign p_l1   = (pin_num == 7'd20) ? 1'b0 : 1'b1;  // IOL_23A
   assign p_m1   = (pin_num == 7'd21) ? 1'b0 : 1'b1;  // IOL_23B
   assign p_n1   = (pin_num == 7'd22) ? 1'b0 : 1'b1;  // IOL_25A
   assign p_p1   = (pin_num == 7'd23) ? 1'b0 : 1'b1;  // IOL_25B
   assign p_a1   = (pin_num == 7'd24) ? 1'b0 : 1'b1;  // IOT_225
   assign p_a2   = (pin_num == 7'd25) ? 1'b0 : 1'b1;  // IOT_223
   assign p_a3   = (pin_num == 7'd26) ? 1'b0 : 1'b1;  // IOT_222
   assign p_a4   = (pin_num == 7'd27) ? 1'b0 : 1'b1;  // IOT_219
   assign p_a5   = (pin_num == 7'd28) ? 1'b0 : 1'b1;  // IOT_208
   assign p_c5   = (pin_num == 7'd29) ? 1'b0 : 1'b1;  // IOT_212
   assign p_d5   = (pin_num == 7'd30) ? 1'b0 : 1'b1;  // IOT_211
   assign p_c4   = (pin_num == 7'd31) ? 1'b0 : 1'b1;  // IOT_221
   assign p_c6   = (pin_num == 7'd32) ? 1'b0 : 1'b1;  // IOT_206
   assign p_d6   = (pin_num == 7'd33) ? 1'b0 : 1'b1;  // IOT_207
   assign p_c7   = (pin_num == 7'd34) ? 1'b0 : 1'b1;  // IOT_200
   assign p_d7   = (pin_num == 7'd35) ? 1'b0 : 1'b1;  // IOT_202
   assign p_a6   = (pin_num == 7'd36) ? 1'b0 : 1'b1;  // IOT_198
   assign p_a7   = (pin_num == 7'd37) ? 1'b0 : 1'b1;  // IOT_197
   assign p_c9   = (pin_num == 7'd38) ? 1'b0 : 1'b1;  // IOT_190
   assign p_d9   = (pin_num == 7'd39) ? 1'b0 : 1'b1;  // IOT_188
   assign p_c10  = (pin_num == 7'd40) ? 1'b0 : 1'b1;  // IOT_186
   assign p_a10  = (pin_num == 7'd41) ? 1'b0 : 1'b1;  // IOT_181
   assign p_a11  = (pin_num == 7'd42) ? 1'b0 : 1'b1;  // IOT_179
   assign p_c11  = (pin_num == 7'd43) ? 1'b0 : 1'b1;  // IOT_174
   assign p_d10  = (pin_num == 7'd44) ? 1'b0 : 1'b1;  // IOT_177
   assign p_d11  = (pin_num == 7'd45) ? 1'b0 : 1'b1;  // IOT_178
   assign p_a12  = (pin_num == 7'd46) ? 1'b0 : 1'b1;  // IOT_170
   assign p_c12  = (pin_num == 7'd47) ? 1'b0 : 1'b1;  // IOT_172
   assign p_b14  = (pin_num == 7'd48) ? 1'b0 : 1'b1;  // IOR_161
   assign p_d12  = (pin_num == 7'd49) ? 1'b0 : 1'b1;  // IOR_160
   assign p_c14  = (pin_num == 7'd50) ? 1'b0 : 1'b1;  // IOR_154
   assign p_d14  = (pin_num == 7'd51) ? 1'b0 : 1'b1;  // IOR_152
   assign p_e14  = (pin_num == 7'd52) ? 1'b0 : 1'b1;  // IOR_148
   assign p_e12  = (pin_num == 7'd53) ? 1'b0 : 1'b1;  // IOR_147
   assign p_e11  = (pin_num == 7'd54) ? 1'b0 : 1'b1;  // IOR_146
   assign p_f11  = (pin_num == 7'd55) ? 1'b0 : 1'b1;  // IOR_144
   assign p_f12  = (pin_num == 7'd56) ? 1'b0 : 1'b1;  // IOR_137
   assign p_g11  = (pin_num == 7'd57) ? 1'b0 : 1'b1;  // IOR_136
   assign p_g12  = (pin_num == 7'd58) ? 1'b0 : 1'b1;  // IOR_129
   assign p_h11  = (pin_num == 7'd59) ? 1'b0 : 1'b1;  // IOR_128
   assign p_h12  = (pin_num == 7'd60) ? 1'b0 : 1'b1;  // IOR_120
   assign p_j12  = (pin_num == 7'd61) ? 1'b0 : 1'b1;  // IOR_118
   assign p_g14  = (pin_num == 7'd62) ? 1'b0 : 1'b1;  // IOR_141
   assign p_f14  = (pin_num == 7'd63) ? 1'b0 : 1'b1;  // IOR_140

endmodule
