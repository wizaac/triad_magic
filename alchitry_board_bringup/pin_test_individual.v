// hdl/pin_test_individual.v
// Cycles through all IOL pins one at a time
// Each pin is driven low for ~1 second while all others are high
// Watch which Br position goes low to identify the mapping

module pin_test_individual (
   input  wire clk,
   input  wire rst_n,

   output wire iol_2a,
   output wire iol_2b,
   output wire iol_4a,
   output wire iol_4b,
   output wire iol_5a,
   output wire iol_5b,
   output wire iol_8a,
   output wire iol_8b,
   output wire iol_9a,
   output wire iol_9b,
   output wire iol_10a,
   output wire iol_10b,
   output wire iol_12a,
   output wire iol_12b,
   output wire iol_13a,
   output wire iol_13b,
   output wire iol_14a,
   output wire iol_14b,
   output wire iol_18a,
   output wire iol_18b,
   output wire iol_23a,
   output wire iol_23b,
   output wire iol_25a,
   output wire iol_25b,

   output wire [7:0] led
);

   // counter — top 5 bits select which pin is active (0-23)
   // each pin held low for 2^25 cycles = ~335ms at 100MHz
   reg [29:0] cnt;
   always @(posedge clk or negedge rst_n) begin
      if (!rst_n) cnt <= 0;
      else        cnt <= cnt + 1;
   end

   wire [4:0] pin_sel = cnt[29:25];  // 0-23 cycles through all pins

   // aliveness on leds — show current pin number
   assign led = {3'b0, pin_sel};

   // each pin driven low only when selected, high otherwise
   assign iol_2a  = (pin_sel == 5'd0)  ? 1'b0 : 1'b1;
   assign iol_2b  = (pin_sel == 5'd1)  ? 1'b0 : 1'b1;
   assign iol_4a  = (pin_sel == 5'd2)  ? 1'b0 : 1'b1;
   assign iol_4b  = (pin_sel == 5'd3)  ? 1'b0 : 1'b1;
   assign iol_5a  = (pin_sel == 5'd4)  ? 1'b0 : 1'b1;
   assign iol_5b  = (pin_sel == 5'd5)  ? 1'b0 : 1'b1;
   assign iol_8a  = (pin_sel == 5'd6)  ? 1'b0 : 1'b1;
   assign iol_8b  = (pin_sel == 5'd7)  ? 1'b0 : 1'b1;
   assign iol_9a  = (pin_sel == 5'd8)  ? 1'b0 : 1'b1;
   assign iol_9b  = (pin_sel == 5'd9)  ? 1'b0 : 1'b1;
   assign iol_10a = (pin_sel == 5'd10) ? 1'b0 : 1'b1;
   assign iol_10b = (pin_sel == 5'd11) ? 1'b0 : 1'b1;
   assign iol_12a = (pin_sel == 5'd12) ? 1'b0 : 1'b1;
   assign iol_12b = (pin_sel == 5'd13) ? 1'b0 : 1'b1;
   assign iol_13a = (pin_sel == 5'd14) ? 1'b0 : 1'b1;
   assign iol_13b = (pin_sel == 5'd15) ? 1'b0 : 1'b1;
   assign iol_14a = (pin_sel == 5'd16) ? 1'b0 : 1'b1;
   assign iol_14b = (pin_sel == 5'd17) ? 1'b0 : 1'b1;
   assign iol_18a = (pin_sel == 5'd18) ? 1'b0 : 1'b1;
   assign iol_18b = (pin_sel == 5'd19) ? 1'b0 : 1'b1;
   assign iol_23a = (pin_sel == 5'd20) ? 1'b0 : 1'b1;
   assign iol_23b = (pin_sel == 5'd21) ? 1'b0 : 1'b1;
   assign iol_25a = (pin_sel == 5'd22) ? 1'b0 : 1'b1;
   assign iol_25b = (pin_sel == 5'd23) ? 1'b0 : 1'b1;

endmodule
