// hdl/pin_test_low.v
// Drives all Br Bank B accessible pins LOW
// Use continuity/voltage to identify which pins the FPGA controls
// Any pin reading 0V = FPGA is driving it
// Any pin floating = wrong iCE40 mapping or bad connection

module pin_test_low (
   input  wire clk,
   input  wire rst_n,

   // all 10 accessible Bank B pins
   output wire pin_b27,
   output wire pin_b29,
   output wire pin_b33,
   output wire pin_b35,
   output wire pin_b39,
   output wire pin_b41,
   output wire pin_b45,
   output wire pin_b47,
   output wire pin_b51,
   output wire pin_b53,

   output wire [7:0] led
);

   reg [26:0] alive_cnt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) alive_cnt <= 0;
      else        alive_cnt <= alive_cnt + 1;
   end

   assign led[1:0] = alive_cnt[26:25];
   assign led[7:2] = 6'b0;

   assign pin_b27 = 1'b0;
   assign pin_b29 = 1'b0;
   assign pin_b33 = 1'b0;
   assign pin_b35 = 1'b0;
   assign pin_b39 = 1'b0;
   assign pin_b41 = 1'b0;
   assign pin_b45 = 1'b0;
   assign pin_b47 = 1'b0;
   assign pin_b51 = 1'b0;
   assign pin_b53 = 1'b0;

endmodule
