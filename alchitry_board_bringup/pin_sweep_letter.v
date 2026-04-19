// hdl/pin_sweep_letter.v
// Alchitry Cu V2 + Bromine V2  --  SWEEP 1 OF 2: LETTER SWEEP
//
// Drives all ICE40 output pins LOW in groups by their ball letter.
// Cycles automatically: A -> B -> C -> D -> E -> F -> G -> H ->
//                        J -> K -> L -> M -> N -> P -> (repeat)
// 14 groups, ~2.68s each, full cycle ~37.6s then repeats.
//
// LEDs show current group index in binary (active-low):
//   led[3:0] = ~group[3:0]
//   led[7:4] = 4'hf (off)
//
// Group index -> letter:
//   0=A  1=B  2=C  3=D  4=E  5=F  6=G  7=H
//   8=J  9=K  10=L 11=M 12=N 13=P
//
// JOURNAL REFERENCE:
//   When LEDs show binary 0000 (all lit): probing letter A pins
//   When LEDs show binary 0001 (led0 off): probing letter B pins
//   ... etc.
//   Groups 14 and 15 (binary 1110, 1111) are idle -- no pins driven low.
//
// Build:  python build.py -t pin_sweep_letter -all
//         python build.py -t pin_sweep_letter -prog

module pin_sweep_letter (
    input  wire       clk,
    input  wire       rst_n,

    // On-board LEDs (active-low) -- show current group index
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
//   Groups 0-13 are valid letters; 14-15 are idle padding.
// ---------------------------------------------------------------------------
reg [31:0] cnt;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cnt <= 32'd0;
    else        cnt <= cnt + 32'd1;
end

wire [3:0] grp = cnt[31:28];  // current letter group

// ---------------------------------------------------------------------------
// LED display: show group index in binary (active-low)
// ---------------------------------------------------------------------------
assign led[3:0] = ~grp;
assign led[7:4] = 4'hf;

// ---------------------------------------------------------------------------
// Letter encoding (matches ICE40 CB132 ball row letters):
//   A=0  B=1  C=2  D=3  E=4  F=5  G=6  H=7
//   J=8  K=9  L=10 M=11 N=12 P=13
// ---------------------------------------------------------------------------
localparam [3:0]
    LA = 4'd0,  LB = 4'd1,  LC = 4'd2,  LD = 4'd3,
    LE = 4'd4,  LF = 4'd5,  LG = 4'd6,  LH = 4'd7,
    LJ = 4'd8,  LK = 4'd9,  LL = 4'd10, LM = 4'd11,
    LN = 4'd12, LP = 4'd13;

// Each output: drive LOW when grp matches this pin's letter, else HIGH.
// Format: ICE40 pin = LETTER + NUMBER
//         grp == L<letter>  ->  0,  else  1

// ---- Bank A ----
// A3:  ICE40 C1  -> letter C
assign pin_a03 = (grp == LC)  ? 1'b0 : 1'b1;
// A4:  ICE40 H3  -> letter H
assign pin_a04 = (grp == LH)  ? 1'b0 : 1'b1;
// A5:  ICE40 D3  -> letter D
assign pin_a05 = (grp == LD)  ? 1'b0 : 1'b1;
// A6:  ICE40 J1  -> letter J
assign pin_a06 = (grp == LJ)  ? 1'b0 : 1'b1;
// A9:  ICE40 B1  -> letter B
assign pin_a09 = (grp == LB)  ? 1'b0 : 1'b1;
// A10: ICE40 G3  -> letter G
assign pin_a10 = (grp == LG)  ? 1'b0 : 1'b1;
// A11: ICE40 A1  -> letter A
assign pin_a11 = (grp == LA)  ? 1'b0 : 1'b1;
// A12: ICE40 F3  -> letter F
assign pin_a12 = (grp == LF)  ? 1'b0 : 1'b1;
// A15: ICE40 D4  -> letter D
assign pin_a15 = (grp == LD)  ? 1'b0 : 1'b1;
// A16: ICE40 F4  -> letter F
assign pin_a16 = (grp == LF)  ? 1'b0 : 1'b1;
// A17: ICE40 A2  -> letter A
assign pin_a17 = (grp == LA)  ? 1'b0 : 1'b1;
// A18: ICE40 E1  -> letter E
assign pin_a18 = (grp == LE)  ? 1'b0 : 1'b1;
// A21: ICE40 C3  -> letter C
assign pin_a21 = (grp == LC)  ? 1'b0 : 1'b1;
// A22: ICE40 E4  -> letter E
assign pin_a22 = (grp == LE)  ? 1'b0 : 1'b1;
// A23: ICE40 A3  -> letter A
assign pin_a23 = (grp == LA)  ? 1'b0 : 1'b1;
// A24: ICE40 D1  -> letter D
assign pin_a24 = (grp == LD)  ? 1'b0 : 1'b1;
// A27: ICE40 C4  -> letter C
assign pin_a27 = (grp == LC)  ? 1'b0 : 1'b1;
// A28: ICE40 H4  -> letter H
assign pin_a28 = (grp == LH)  ? 1'b0 : 1'b1;
// A29: ICE40 A4  -> letter A
assign pin_a29 = (grp == LA)  ? 1'b0 : 1'b1;
// A30: ICE40 G4  -> letter G
assign pin_a30 = (grp == LG)  ? 1'b0 : 1'b1;
// A33: ICE40 C5  -> letter C
assign pin_a33 = (grp == LC)  ? 1'b0 : 1'b1;
// A34: ICE40 D5  -> letter D
assign pin_a34 = (grp == LD)  ? 1'b0 : 1'b1;
// A35: ICE40 A5  -> letter A
assign pin_a35 = (grp == LA)  ? 1'b0 : 1'b1;
// A36: ICE40 D6  -> letter D
assign pin_a36 = (grp == LD)  ? 1'b0 : 1'b1;
// A39: ICE40 C6  -> letter C
assign pin_a39 = (grp == LC)  ? 1'b0 : 1'b1;
// A40: ICE40 D7  -> letter D
assign pin_a40 = (grp == LD)  ? 1'b0 : 1'b1;
// A41: ICE40 A6  -> letter A  [GBIN]
assign pin_a41 = (grp == LA)  ? 1'b0 : 1'b1;
// A42: ICE40 H1  -> letter H  [GBIN]
assign pin_a42 = (grp == LH)  ? 1'b0 : 1'b1;
// A45: ICE40 C7  -> letter C
assign pin_a45 = (grp == LC)  ? 1'b0 : 1'b1;
// A46: ICE40 D9  -> letter D
assign pin_a46 = (grp == LD)  ? 1'b0 : 1'b1;
// A47: ICE40 A7  -> letter A  [GBIN]
assign pin_a47 = (grp == LA)  ? 1'b0 : 1'b1;
// A48: ICE40 G1  -> letter G  [GBIN]
assign pin_a48 = (grp == LG)  ? 1'b0 : 1'b1;
// A51: ICE40 A10 -> letter A
assign pin_a51 = (grp == LA)  ? 1'b0 : 1'b1;
// A52: ICE40 D10 -> letter D
assign pin_a52 = (grp == LD)  ? 1'b0 : 1'b1;
// A53: ICE40 C9  -> letter C
assign pin_a53 = (grp == LC)  ? 1'b0 : 1'b1;
// A54: ICE40 D11 -> letter D
assign pin_a54 = (grp == LD)  ? 1'b0 : 1'b1;
// A57: ICE40 A11 -> letter A
assign pin_a57 = (grp == LA)  ? 1'b0 : 1'b1;
// A58: ICE40 E11 -> letter E
assign pin_a58 = (grp == LE)  ? 1'b0 : 1'b1;
// A59: ICE40 C10 -> letter C
assign pin_a59 = (grp == LC)  ? 1'b0 : 1'b1;
// A60: ICE40 F11 -> letter F
assign pin_a60 = (grp == LF)  ? 1'b0 : 1'b1;
// A63: ICE40 A12 -> letter A
assign pin_a63 = (grp == LA)  ? 1'b0 : 1'b1;
// A64: ICE40 G11 -> letter G
assign pin_a64 = (grp == LG)  ? 1'b0 : 1'b1;
// A65: ICE40 C11 -> letter C
assign pin_a65 = (grp == LC)  ? 1'b0 : 1'b1;
// A66: ICE40 H11 -> letter H
assign pin_a66 = (grp == LH)  ? 1'b0 : 1'b1;
// A69: ICE40 C12 -> letter C
assign pin_a69 = (grp == LC)  ? 1'b0 : 1'b1;
// A70: ICE40 E12 -> letter E
assign pin_a70 = (grp == LE)  ? 1'b0 : 1'b1;
// A71: ICE40 B14 -> letter B
assign pin_a71 = (grp == LB)  ? 1'b0 : 1'b1;
// A72: ICE40 D14 -> letter D
assign pin_a72 = (grp == LD)  ? 1'b0 : 1'b1;
// A75: ICE40 D12 -> letter D
assign pin_a75 = (grp == LD)  ? 1'b0 : 1'b1;
// A76: ICE40 F12 -> letter F
assign pin_a76 = (grp == LF)  ? 1'b0 : 1'b1;
// A77: ICE40 C14 -> letter C
assign pin_a77 = (grp == LC)  ? 1'b0 : 1'b1;
// A78: ICE40 E14 -> letter E
assign pin_a78 = (grp == LE)  ? 1'b0 : 1'b1;

// ---- Bank B ----
// B3:  ICE40 L1  -> letter L
assign pin_b03 = (grp == LL)  ? 1'b0 : 1'b1;
// B4:  ICE40 P2  -> letter P
assign pin_b04 = (grp == LP)  ? 1'b0 : 1'b1;
// B5:  ICE40 J3  -> letter J
assign pin_b05 = (grp == LJ)  ? 1'b0 : 1'b1;
// B6:  ICE40 L4  -> letter L
assign pin_b06 = (grp == LL)  ? 1'b0 : 1'b1;
// B9:  ICE40 M1  -> letter M
assign pin_b09 = (grp == LM)  ? 1'b0 : 1'b1;
// B10: ICE40 P3  -> letter P
assign pin_b10 = (grp == LP)  ? 1'b0 : 1'b1;
// B11: ICE40 K3  -> letter K
assign pin_b11 = (grp == LK)  ? 1'b0 : 1'b1;
// B12: ICE40 M4  -> letter M
assign pin_b12 = (grp == LM)  ? 1'b0 : 1'b1;
// B15: ICE40 N1  -> letter N
assign pin_b15 = (grp == LN)  ? 1'b0 : 1'b1;
// B16: ICE40 P4  -> letter P
assign pin_b16 = (grp == LP)  ? 1'b0 : 1'b1;
// B17: ICE40 P1  -> letter P
assign pin_b17 = (grp == LP)  ? 1'b0 : 1'b1;
// B18: ICE40 M6  -> letter M
assign pin_b18 = (grp == LM)  ? 1'b0 : 1'b1;
// B21: ICE40 M3  -> letter M
assign pin_b21 = (grp == LM)  ? 1'b0 : 1'b1;
// B22: ICE40 P5  -> letter P
assign pin_b22 = (grp == LP)  ? 1'b0 : 1'b1;
// B23: ICE40 K4  -> letter K
assign pin_b23 = (grp == LK)  ? 1'b0 : 1'b1;
// B24: ICE40 M7  -> letter M
assign pin_b24 = (grp == LM)  ? 1'b0 : 1'b1;
// B27: ICE40 L5  -> letter L
assign pin_b27 = (grp == LL)  ? 1'b0 : 1'b1;
// B28: ICE40 P9  -> letter P
assign pin_b28 = (grp == LP)  ? 1'b0 : 1'b1;
// B29: ICE40 L6  -> letter L
assign pin_b29 = (grp == LL)  ? 1'b0 : 1'b1;
// B30: ICE40 M12 -> letter M
assign pin_b30 = (grp == LM)  ? 1'b0 : 1'b1;
// B33: ICE40 N14 -> letter N
assign pin_b33 = (grp == LN)  ? 1'b0 : 1'b1;
// B34: ICE40 L9  -> letter L
assign pin_b34 = (grp == LL)  ? 1'b0 : 1'b1;
// B35: ICE40 L12 -> letter L
assign pin_b35 = (grp == LL)  ? 1'b0 : 1'b1;
// B36: ICE40 P10 -> letter P
assign pin_b36 = (grp == LP)  ? 1'b0 : 1'b1;
// B39: ICE40 L8  -> letter L
assign pin_b39 = (grp == LL)  ? 1'b0 : 1'b1;
// B41: ICE40 G14 -> letter G  [GBIN]
assign pin_b41 = (grp == LG)  ? 1'b0 : 1'b1;
// B42: ICE40 F14 -> letter F  [GBIN]
assign pin_b42 = (grp == LF)  ? 1'b0 : 1'b1;

endmodule
