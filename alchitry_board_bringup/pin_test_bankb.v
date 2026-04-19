// hdl/pin_test_bankb.v
// Drives every Bank B iCE40 pin LOW
// Probe each Br connector position with multimeter (0V = that pin is live)
// Aliveness counter on LED[1:0] confirms bitstream is running

module pin_test_bankb (
   input  wire clk,
   input  wire rst_n,

   // IOR bank pins (not conflicting with LEDs)
   output wire ior_118,  // J12
   output wire ior_120,  // H12
   output wire ior_128,  // H11  (B27 row1 col9)
   output wire ior_129,  // G12
   output wire ior_136,  // G11  (B29? row2 col9)
   output wire ior_137,  // F12
   output wire ior_140,  // F14
   output wire ior_141,  // G14
   output wire ior_144,  // F11  (B33 row1 col8 - confirmed)
   output wire ior_146,  // E11  (B35 row2 col8 - confirmed)
   output wire ior_147,  // E12
   output wire ior_148,  // E14
   output wire ior_152,  // D14
   output wire ior_154,  // C14
   output wire ior_160,  // D12
   output wire ior_161,  // B14

   // IOT bank pins
   output wire iot_170,  // A12
   output wire iot_172,  // C12  (B39? row1 col7)
   output wire iot_174,  // C11
   output wire iot_177,  // D10
   output wire iot_178,  // D11
   output wire iot_179,  // A11
   output wire iot_181,  // A10
   output wire iot_186,  // C10
   output wire iot_188,  // D9
   output wire iot_190,  // C9
   output wire iot_197,  // A7
   output wire iot_198,  // A6
   output wire iot_200,  // C7
   output wire iot_202,  // D7   (B45? row1 col6)
   output wire iot_206,  // C6
   output wire iot_207,  // D6
   output wire iot_208,  // A5
   output wire iot_211,  // D5
   output wire iot_212,  // C5
   output wire iot_219,  // A4
   output wire iot_221,  // C4
   output wire iot_222,  // A3
   output wire iot_223,  // A2
   output wire iot_225,  // A1

   output wire [7:0] led
);

   // ── Aliveness counter ─────────────────────────────────────────
   reg [26:0] alive_cnt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) alive_cnt <= 0;
      else        alive_cnt <= alive_cnt + 1;
   end
   assign led[1:0] = alive_cnt[26:25];
   assign led[7:2] = 6'b0;

   // ── Drive everything low ──────────────────────────────────────
   assign ior_118 = 0;
   assign ior_120 = 0;
   assign ior_128 = 0;
   assign ior_129 = 0;
   assign ior_136 = 0;
   assign ior_137 = 0;
   assign ior_140 = 0;
   assign ior_141 = 0;
   assign ior_144 = 0;
   assign ior_146 = 0;
   assign ior_147 = 0;
   assign ior_148 = 0;
   assign ior_152 = 0;
   assign ior_154 = 0;
   assign ior_160 = 0;
   assign ior_161 = 0;

   assign iot_170 = 0;
   assign iot_172 = 0;
   assign iot_174 = 0;
   assign iot_177 = 0;
   assign iot_178 = 0;
   assign iot_179 = 0;
   assign iot_181 = 0;
   assign iot_186 = 0;
   assign iot_188 = 0;
   assign iot_190 = 0;
   assign iot_197 = 0;
   assign iot_198 = 0;
   assign iot_200 = 0;
   assign iot_202 = 0;
   assign iot_206 = 0;
   assign iot_207 = 0;
   assign iot_208 = 0;
   assign iot_211 = 0;
   assign iot_212 = 0;
   assign iot_219 = 0;
   assign iot_221 = 0;
   assign iot_222 = 0;
   assign iot_223 = 0;
   assign iot_225 = 0;

endmodule
