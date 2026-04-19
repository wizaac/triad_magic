// hdl/led_test3.v
// Tests IOR pins not currently in our LED PCF
// Looking for physical LEDs 2, 3, 5

module pin_test_all(

   input  wire       clk,
   input  wire       rst_n,
   output wire [7:0] led,
   output wire p_b14,
   output wire p_d12,
   output wire p_c14,
   output wire p_d14,
   output wire p_e14,
   output wire p_e12,
   output wire p_e11,
   output wire p_f11
);

   reg [28:0] cnt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) cnt <= 0;
      else        cnt <= cnt + 1;
   end

   // 2^26 = ~0.67s per step, 8 steps = ~5.4s total
   wire [2:0] sel = cnt[28:26];

   // show sel on bottom 3 LEDs so we can track position
   assign led[2:0] = ~sel;   // active low
   assign led[7:3] = 5'h1f;  // off

   assign p_b14 = (sel == 3'd0) ? 1'b0 : 1'b1;
   assign p_d12 = (sel == 3'd1) ? 1'b0 : 1'b1;
   assign p_c14 = (sel == 3'd2) ? 1'b0 : 1'b1;
   assign p_d14 = (sel == 3'd3) ? 1'b0 : 1'b1;
   assign p_e14 = (sel == 3'd4) ? 1'b0 : 1'b1;
   assign p_e12 = (sel == 3'd5) ? 1'b0 : 1'b1;
   assign p_e11 = (sel == 3'd6) ? 1'b0 : 1'b1;
   assign p_f11 = (sel == 3'd7) ? 1'b0 : 1'b1;
endmodule
