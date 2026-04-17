// src/blinky.v
module blinky (
   input  clk,
   input  rst_n,
   output [7:0] led
);

   reg [26:0] counter;

   always @(posedge clk or negedge rst_n) begin
      if (!rst_n)
         counter <= 27'd0;
      else
         counter <= counter + 1;
   end

   assign led = counter[26:19];

endmodule
