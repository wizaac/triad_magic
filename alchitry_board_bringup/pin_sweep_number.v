// hdl/pin_sweep_number.v
// Alchitry Cu V2 + Bromine V2  --  SWEEP 2 OF 2: NUMBER SWEEP
//
// Drives all ICE40 output pins LOW in groups by their ball number.
// Cycles automatically: 1->2->3->4->5->6->7->8->9->10->11->12->14->(idle)->(repeat)
// NOTE: Number 13 does not exist in the ICE40 HX8K CB132 ball grid.
//       Group index 12 = ball number 14 (not 13).
//       Group index 13 = idle (no pins driven low).
//
// 13 active groups + 3 idle slots, ~2.68s each, full cycle ~42.9s then repeats.
//
// LEDs show current ball number in binary (active-low):
//   During idle (groups 13-15): LEDs show 1101, 1110, 1111 -- no pins low.
//
// Group index -> ball number:
//   0->1   1->2   2->3   3->4   4->5   5->6
//   6->7   7->8   8->9   9->10  10->11 11->12
//   12->14  (skips 13!)
//   13,14,15 -> idle
//
// JOURNAL REFERENCE:
//   LEDs binary 0001 (only led0 off): probing number 1 pins
//   LEDs binary 0010 (only led1 off): probing number 2 pins
//   LEDs binary 1110 (led3,2,1 off, led0 on): probing number 14 pins
//   LEDs binary 1101 or higher: idle, no pins low
//
// Build:  python build.py -t pin_sweep_number -all
//         python build.py -t pin_sweep_number -prog

module pin_sweep_number (
    input  wire       clk,
    input  wire       rst_n,

    // On-board LEDs (active-low) -- show current ball number in binary
    output wire [7:0] led,

    // ---- Bank A (48 pins) ----
    output wire pin_a03, output wire pin_a04, output wire pin_a05,
    output wire pin_a06, output wire pin_a09, output wire pin_a10,
    output wire pin_a11, output wire pin_a12, output wire pin_a15,
    output wire pin_a16, output wire pin_a17, output wire pin_a18,
    output wire pin_a21, output wire pin_a22, output wire pin_a23,
    output wire pin_a24, output wire pin_a27, output wire pin_a28,
    output wire pin_a29, output wire pin_a30, output wire pin_a33,
    output wire pin_a34, output wire pin_a35, output wire pin_a36,
    output wire pin_a39, output wire pin_a40, output wire pin_a41,
    output wire pin_a42, output wire pin_a45, output wire pin_a46,
    output wire pin_a47, output wire pin_a48, output wire pin_a51,
    output wire pin_a52, output wire pin_a53, output wire pin_a54,
    output wire pin_a57, output wire pin_a58, output wire pin_a59,
    output wire pin_a60, output wire pin_a63, output wire pin_a64,
    output wire pin_a65, output wire pin_a66, output wire pin_a69,
    output wire pin_a70, output wire pin_a71, output wire pin_a72,
    output wire pin_a75, output wire pin_a76, output wire pin_a77,
    output wire pin_a78,

    // ---- Bank B (27 pins) ----
    output wire pin_b03, output wire pin_b04, output wire pin_b05,
    output wire pin_b06, output wire pin_b09, output wire pin_b10,
    output wire pin_b11, output wire pin_b12, output wire pin_b15,
    output wire pin_b16, output wire pin_b17, output wire pin_b18,
    output wire pin_b21, output wire pin_b22, output wire pin_b23,
    output wire pin_b24, output wire pin_b27, output wire pin_b28,
    output wire pin_b29, output wire pin_b30, output wire pin_b33,
    output wire pin_b34, output wire pin_b35, output wire pin_b36,
    output wire pin_b39, output wire pin_b41, output wire pin_b42
);

// ---------------------------------------------------------------------------
// Counter: 32-bit free-running.
//   cnt[31:28] = 4-bit group index (0-15), increments every 2^28 = 2.68s
// ---------------------------------------------------------------------------
reg [31:0] cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 32'd0;
    else        cnt <= cnt + 32'd1;
end

wire [3:0] grp = cnt[31:28];

// ---------------------------------------------------------------------------
// Convert group index to the actual ball number being swept.
// Groups 0-11: ball numbers 1-12.
// Group 12:    ball number 14 (13 is skipped -- doesn't exist in CB132).
// Groups 13-15: idle.
// ---------------------------------------------------------------------------
reg [4:0] ball_num;  // 5 bits to hold values up to 14
always @(*) begin
    case (grp)
        4'd0:  ball_num = 5'd1;
        4'd1:  ball_num = 5'd2;
        4'd2:  ball_num = 5'd3;
        4'd3:  ball_num = 5'd4;
        4'd4:  ball_num = 5'd5;
        4'd5:  ball_num = 5'd6;
        4'd6:  ball_num = 5'd7;
        4'd7:  ball_num = 5'd8;
        4'd8:  ball_num = 5'd9;
        4'd9:  ball_num = 5'd10;
        4'd10: ball_num = 5'd11;
        4'd11: ball_num = 5'd12;
        4'd12: ball_num = 5'd14;  // <-- skip 13, jump to 14
        default: ball_num = 5'd0; // idle -- no match for any pin
    endcase
end

// ---------------------------------------------------------------------------
// LED display: show ball number in binary (active-low).
// During idle ball_num=0 so LEDs show 0000 (all lit) -- harmless.
// ---------------------------------------------------------------------------
assign led[3:0] = ~ball_num[3:0];
assign led[7:4] = 4'hf;

// ---------------------------------------------------------------------------
// Each output: drive LOW when ball_num matches this pin's number, else HIGH.
// ICE40 pin = LETTER + NUMBER; we only care about NUMBER here.
// ---------------------------------------------------------------------------

// ---- Bank A ----
// A3:  ICE40 C1  -> number 1
assign pin_a03 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A4:  ICE40 H3  -> number 3
assign pin_a04 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A5:  ICE40 D3  -> number 3
assign pin_a05 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A6:  ICE40 J1  -> number 1
assign pin_a06 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A9:  ICE40 B1  -> number 1
assign pin_a09 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A10: ICE40 G3  -> number 3
assign pin_a10 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A11: ICE40 A1  -> number 1
assign pin_a11 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A12: ICE40 F3  -> number 3
assign pin_a12 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A15: ICE40 D4  -> number 4
assign pin_a15 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A16: ICE40 F4  -> number 4
assign pin_a16 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A17: ICE40 A2  -> number 2
assign pin_a17 = (ball_num == 5'd2)  ? 1'b0 : 1'b1;
// A18: ICE40 E1  -> number 1
assign pin_a18 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A21: ICE40 C3  -> number 3
assign pin_a21 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A22: ICE40 E4  -> number 4
assign pin_a22 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A23: ICE40 A3  -> number 3
assign pin_a23 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// A24: ICE40 D1  -> number 1
assign pin_a24 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A27: ICE40 C4  -> number 4
assign pin_a27 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A28: ICE40 H4  -> number 4
assign pin_a28 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A29: ICE40 A4  -> number 4
assign pin_a29 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A30: ICE40 G4  -> number 4
assign pin_a30 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// A33: ICE40 C5  -> number 5
assign pin_a33 = (ball_num == 5'd5)  ? 1'b0 : 1'b1;
// A34: ICE40 D5  -> number 5
assign pin_a34 = (ball_num == 5'd5)  ? 1'b0 : 1'b1;
// A35: ICE40 A5  -> number 5
assign pin_a35 = (ball_num == 5'd5)  ? 1'b0 : 1'b1;
// A36: ICE40 D6  -> number 6
assign pin_a36 = (ball_num == 5'd6)  ? 1'b0 : 1'b1;
// A39: ICE40 C6  -> number 6
assign pin_a39 = (ball_num == 5'd6)  ? 1'b0 : 1'b1;
// A40: ICE40 D7  -> number 7
assign pin_a40 = (ball_num == 5'd7)  ? 1'b0 : 1'b1;
// A41: ICE40 A6  -> number 6  [GBIN]
assign pin_a41 = (ball_num == 5'd6)  ? 1'b0 : 1'b1;
// A42: ICE40 H1  -> number 1  [GBIN]
assign pin_a42 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A45: ICE40 C7  -> number 7
assign pin_a45 = (ball_num == 5'd7)  ? 1'b0 : 1'b1;
// A46: ICE40 D9  -> number 9
assign pin_a46 = (ball_num == 5'd9)  ? 1'b0 : 1'b1;
// A47: ICE40 A7  -> number 7  [GBIN]
assign pin_a47 = (ball_num == 5'd7)  ? 1'b0 : 1'b1;
// A48: ICE40 G1  -> number 1  [GBIN]
assign pin_a48 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// A51: ICE40 A10 -> number 10
assign pin_a51 = (ball_num == 5'd10) ? 1'b0 : 1'b1;
// A52: ICE40 D10 -> number 10
assign pin_a52 = (ball_num == 5'd10) ? 1'b0 : 1'b1;
// A53: ICE40 C9  -> number 9
assign pin_a53 = (ball_num == 5'd9)  ? 1'b0 : 1'b1;
// A54: ICE40 D11 -> number 11
assign pin_a54 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A57: ICE40 A11 -> number 11
assign pin_a57 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A58: ICE40 E11 -> number 11
assign pin_a58 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A59: ICE40 C10 -> number 10
assign pin_a59 = (ball_num == 5'd10) ? 1'b0 : 1'b1;
// A60: ICE40 F11 -> number 11
assign pin_a60 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A63: ICE40 A12 -> number 12
assign pin_a63 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// A64: ICE40 G11 -> number 11
assign pin_a64 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A65: ICE40 C11 -> number 11
assign pin_a65 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A66: ICE40 H11 -> number 11
assign pin_a66 = (ball_num == 5'd11) ? 1'b0 : 1'b1;
// A69: ICE40 C12 -> number 12
assign pin_a69 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// A70: ICE40 E12 -> number 12
assign pin_a70 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// A71: ICE40 B14 -> number 14
assign pin_a71 = (ball_num == 5'd14) ? 1'b0 : 1'b1;
// A72: ICE40 D14 -> number 14
assign pin_a72 = (ball_num == 5'd14) ? 1'b0 : 1'b1;
// A75: ICE40 D12 -> number 12
assign pin_a75 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// A76: ICE40 F12 -> number 12
assign pin_a76 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// A77: ICE40 C14 -> number 14
assign pin_a77 = (ball_num == 5'd14) ? 1'b0 : 1'b1;
// A78: ICE40 E14 -> number 14
assign pin_a78 = (ball_num == 5'd14) ? 1'b0 : 1'b1;

// ---- Bank B ----
// B3:  ICE40 L1  -> number 1
assign pin_b03 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// B4:  ICE40 P2  -> number 2
assign pin_b04 = (ball_num == 5'd2)  ? 1'b0 : 1'b1;
// B5:  ICE40 J3  -> number 3
assign pin_b05 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// B6:  ICE40 L4  -> number 4
assign pin_b06 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// B9:  ICE40 M1  -> number 1
assign pin_b09 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// B10: ICE40 P3  -> number 3
assign pin_b10 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// B11: ICE40 K3  -> number 3
assign pin_b11 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// B12: ICE40 M4  -> number 4
assign pin_b12 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// B15: ICE40 N1  -> number 1
assign pin_b15 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// B16: ICE40 P4  -> number 4
assign pin_b16 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// B17: ICE40 P1  -> number 1
assign pin_b17 = (ball_num == 5'd1)  ? 1'b0 : 1'b1;
// B18: ICE40 M6  -> number 6
assign pin_b18 = (ball_num == 5'd6)  ? 1'b0 : 1'b1;
// B21: ICE40 M3  -> number 3
assign pin_b21 = (ball_num == 5'd3)  ? 1'b0 : 1'b1;
// B22: ICE40 P5  -> number 5
assign pin_b22 = (ball_num == 5'd5)  ? 1'b0 : 1'b1;
// B23: ICE40 K4  -> number 4
assign pin_b23 = (ball_num == 5'd4)  ? 1'b0 : 1'b1;
// B24: ICE40 M7  -> number 7
assign pin_b24 = (ball_num == 5'd7)  ? 1'b0 : 1'b1;
// B27: ICE40 L5  -> number 5
assign pin_b27 = (ball_num == 5'd5)  ? 1'b0 : 1'b1;
// B28: ICE40 P9  -> number 9
assign pin_b28 = (ball_num == 5'd9)  ? 1'b0 : 1'b1;
// B29: ICE40 L6  -> number 6
assign pin_b29 = (ball_num == 5'd6)  ? 1'b0 : 1'b1;
// B30: ICE40 M12 -> number 12
assign pin_b30 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// B33: ICE40 N14 -> number 14
assign pin_b33 = (ball_num == 5'd14) ? 1'b0 : 1'b1;
// B34: ICE40 L9  -> number 9
assign pin_b34 = (ball_num == 5'd9)  ? 1'b0 : 1'b1;
// B35: ICE40 L12 -> number 12
assign pin_b35 = (ball_num == 5'd12) ? 1'b0 : 1'b1;
// B36: ICE40 P10 -> number 10
assign pin_b36 = (ball_num == 5'd10) ? 1'b0 : 1'b1;
// B39: ICE40 L8  -> number 8
assign pin_b39 = (ball_num == 5'd8)  ? 1'b0 : 1'b1;
// B41: ICE40 G14 -> number 14  [GBIN]
assign pin_b41 = (ball_num == 5'd14) ? 1'b0 : 1'b1;
// B42: ICE40 F14 -> number 14  [GBIN]
assign pin_b42 = (ball_num == 5'd14) ? 1'b0 : 1'b1;

endmodule
