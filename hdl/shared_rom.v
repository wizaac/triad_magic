// hdl/shared_rom.v
// Shared note and quality bitmap ROM
// note bitmaps:    addresses 0    to 2303  (12 * 192 bytes)
// quality bitmaps: addresses 2304 to 2879  (6  * 96  bytes)
// Writable via wishbone for runtime font loading
// Read port for display drivers

module shared_rom (
   input  wire        clk,

   // wishbone write port (font loading)
   input  wire        wb_cyc,
   input  wire        wb_stb,
   input  wire        wb_we,
   input  wire [11:0] wb_addr,
   input  wire [7:0]  wb_wdat,
   output reg  [7:0]  wb_rdat,
   output reg         wb_ack,

   // read port (display drivers)
   input  wire [11:0] rd_addr,
   input  wire        rd_en,
   output reg  [7:0]  rd_data
);

   reg [7:0] mem [0:2879];

   // initialise with placeholder patterns
   // note bitmaps: alternating stripes so you can see something
   // quality bitmaps: solid fill so regions are distinguishable
	initial begin
	   $readmemh("rom_init.hex", mem);
    $display("shared_rom: mem[0]=%02X mem[1]=%02X mem[2304]=%02X", 
             mem[0], mem[1], mem[2304]);
	end

   // wishbone port
   always @(posedge clk) begin
      wb_ack <= 0;
      if (wb_cyc && wb_stb && !wb_ack) begin
         wb_ack <= 1;
         if (wb_we)
            mem[wb_addr] <= wb_wdat;
         else
            wb_rdat <= mem[wb_addr];
      end
   end

   // read port
   always @(posedge clk) begin
      if (rd_en)
         rd_data <= mem[rd_addr];
   end

endmodule
