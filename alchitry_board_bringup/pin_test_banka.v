// hdl/pin_test_banka.v
// Drives every Bank A (IOL) iCE40 pin LOW
// Probe the physical Bank B connector on the Br
// 0V = confirmed mapping between Br position and iCE40 pin

module pin_test_banka (
   input  wire clk,
   input  wire rst_n,

   output wire iol_2a,   // B1
   output wire iol_2b,   // C1
   output wire iol_4a,   // C3
   output wire iol_4b,   // D3
   output wire iol_5a,   // D1
   output wire iol_5b,   // E1
   output wire iol_8a,   // D4
   output wire iol_8b,   // E4
   output wire iol_9a,   // F4
   output wire iol_9b,   // F3
   output wire iol_10a,  // H4
   output wire iol_10b,  // G4
   output wire iol_12a,  // J3
   output wire iol_12b,  // J1
   output wire iol_13a,  // G3
   output wire iol_13b,  // G1
   output wire iol_14a,  // H1
   output wire iol_14b,  // H3
   output wire iol_18a,  // K3
   output wire iol_18b,  // K4
   output wire iol_23a,  // L1
   output wire iol_23b,  // M1
   output wire iol_25a,  // N1
   output wire iol_25b,  // P1

   output wire [7:0] led
);

   reg [26:0] alive_cnt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) alive_cnt <= 0;
      else        alive_cnt <= alive_cnt + 1;
   end
   assign led[1:0] = alive_cnt[26:25];
   assign led[7:2] = 6'b0;

   assign iol_2a  = 0;
   assign iol_2b  = 0;
   assign iol_4a  = 0;
   assign iol_4b  = 0;
   assign iol_5a  = 0;
   assign iol_5b  = 0;
   assign iol_8a  = 0;
   assign iol_8b  = 0;
   assign iol_9a  = 0;
   assign iol_9b  = 0;
   assign iol_10a = 0;
   assign iol_10b = 0;
   assign iol_12a = 0;
   assign iol_12b = 0;
   assign iol_13a = 0;
   assign iol_13b = 0;
   assign iol_14a = 0;
   assign iol_14b = 0;
   assign iol_18a = 0;
   assign iol_18b = 0;
   assign iol_23a = 0;
   assign iol_23b = 0;
   assign iol_25a = 0;
   assign iol_25b = 0;

endmodule
