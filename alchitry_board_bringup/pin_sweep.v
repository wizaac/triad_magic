// hdl/pin_sweep.v
// Alchitry Cu V2 + Bromine V2 -- static pin sweep
// ICE40 HX8K CB132
//
// USAGE: change SWEEP_GROUP below, rebuild, flash, probe.
//
// LETTER SWEEP -- set MODE = 0, SWEEP_GROUP = letter code:
//   0=A  1=B  2=C  3=D  4=E  5=F  6=G  7=H
//   8=J  9=K  10=L 11=M 12=N 13=P
//
// NUMBER SWEEP -- set MODE = 1, SWEEP_GROUP = ball number (1-12, 14):
//   1 2 3 4 5 6 7 8 9 10 11 12 14   (13 does not exist in CB132)
//
// Pins in the active group are driven LOW.
// All other pins are driven HIGH.
// LEDs show SWEEP_GROUP in binary (active-low) as a sanity check.
//
// Build: python build.py -t pin_sweep --pcf pin_sweep.pcf -all
//        python build.py -t pin_sweep --pcf pin_sweep.pcf -prog

module pin_sweep (
   input  wire       clk,
   input  wire       rst_n,
   output wire [7:0] led,

   // Bank A
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

   // Bank B
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

// -----------------------------------------------------------------------
// >>>  EDIT THESE TWO LINES BETWEEN FLASHES  <
// -----------------------------------------------------------------------
localparam MODE        = 1;   // 0 = letter sweep,  1 = number sweep
localparam SWEEP_GROUP = 5;   // letter: 0-13       number: 1-12 or 14
// -----------------------------------------------------------------------

// Letter codes: A=0 B=1 C=2 D=3 E=4 F=5 G=6 H=7 J=8 K=9 L=10 M=11 N=12 P=13
// (I and O are not used in ICE40 CB132 ball designators)

// LED sanity indicator: show SWEEP_GROUP in binary, active-low
assign led = ~(8'd0 | SWEEP_GROUP[3:0]);

// Each pin is LOW when its letter (MODE=0) or number (MODE=1) matches.
// Comment shows: Br-pin -> ICE40-ball -> (letter-code, number)

// ---- Bank A ----
assign pin_a03 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // C1   C=2  1
assign pin_a04 = (MODE==0 ? SWEEP_GROUP==7  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // H3   H=7  3
assign pin_a05 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // D3   D=3  3
assign pin_a06 = (MODE==0 ? SWEEP_GROUP==8  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // J1   J=8  1
assign pin_a09 = (MODE==0 ? SWEEP_GROUP==1  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // B1   B=1  1
assign pin_a10 = (MODE==0 ? SWEEP_GROUP==6  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // G3   G=6  3
assign pin_a11 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // A1   A=0  1
assign pin_a12 = (MODE==0 ? SWEEP_GROUP==5  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // F3   F=5  3
assign pin_a15 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // D4   D=3  4
assign pin_a16 = (MODE==0 ? SWEEP_GROUP==5  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // F4   F=5  4
assign pin_a17 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==2)  ? 1'b0 : 1'b1; // A2   A=0  2
assign pin_a18 = (MODE==0 ? SWEEP_GROUP==4  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // E1   E=4  1
assign pin_a21 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // C3   C=2  3
assign pin_a22 = (MODE==0 ? SWEEP_GROUP==4  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // E4   E=4  4
assign pin_a23 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // A3   A=0  3
assign pin_a24 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // D1   D=3  1
assign pin_a27 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // C4   C=2  4
assign pin_a28 = (MODE==0 ? SWEEP_GROUP==7  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // H4   H=7  4
assign pin_a29 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // A4   A=0  4
assign pin_a30 = (MODE==0 ? SWEEP_GROUP==6  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // G4   G=6  4
assign pin_a33 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==5)  ? 1'b0 : 1'b1; // C5   C=2  5
assign pin_a34 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==5)  ? 1'b0 : 1'b1; // D5   D=3  5
assign pin_a35 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==5)  ? 1'b0 : 1'b1; // A5   A=0  5
assign pin_a36 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==6)  ? 1'b0 : 1'b1; // D6   D=3  6
assign pin_a39 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==6)  ? 1'b0 : 1'b1; // C6   C=2  6
assign pin_a40 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==7)  ? 1'b0 : 1'b1; // D7   D=3  7
assign pin_a41 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==6)  ? 1'b0 : 1'b1; // A6   A=0  6  [GBIN]
assign pin_a42 = (MODE==0 ? SWEEP_GROUP==7  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // H1   H=7  1  [GBIN]
assign pin_a45 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==7)  ? 1'b0 : 1'b1; // C7   C=2  7
assign pin_a46 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==9)  ? 1'b0 : 1'b1; // D9   D=3  9
assign pin_a47 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==7)  ? 1'b0 : 1'b1; // A7   A=0  7  [GBIN]
assign pin_a48 = (MODE==0 ? SWEEP_GROUP==6  : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // G1   G=6  1  [GBIN]
assign pin_a51 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==10) ? 1'b0 : 1'b1; // A10  A=0  10
assign pin_a52 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==10) ? 1'b0 : 1'b1; // D10  D=3  10
assign pin_a53 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==9)  ? 1'b0 : 1'b1; // C9   C=2  9
assign pin_a54 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // D11  D=3  11
assign pin_a57 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // A11  A=0  11
assign pin_a58 = (MODE==0 ? SWEEP_GROUP==4  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // E11  E=4  11
assign pin_a59 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==10) ? 1'b0 : 1'b1; // C10  C=2  10
assign pin_a60 = (MODE==0 ? SWEEP_GROUP==5  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // F11  F=5  11
assign pin_a63 = (MODE==0 ? SWEEP_GROUP==0  : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // A12  A=0  12
assign pin_a64 = (MODE==0 ? SWEEP_GROUP==6  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // G11  G=6  11
assign pin_a65 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // C11  C=2  11
assign pin_a66 = (MODE==0 ? SWEEP_GROUP==7  : SWEEP_GROUP==11) ? 1'b0 : 1'b1; // H11  H=7  11
assign pin_a69 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // C12  C=2  12
assign pin_a70 = (MODE==0 ? SWEEP_GROUP==4  : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // E12  E=4  12
assign pin_a71 = (MODE==0 ? SWEEP_GROUP==1  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // B14  B=1  14
assign pin_a72 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // D14  D=3  14
assign pin_a75 = (MODE==0 ? SWEEP_GROUP==3  : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // D12  D=3  12
assign pin_a76 = (MODE==0 ? SWEEP_GROUP==5  : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // F12  F=5  12
assign pin_a77 = (MODE==0 ? SWEEP_GROUP==2  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // C14  C=2  14
assign pin_a78 = (MODE==0 ? SWEEP_GROUP==4  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // E14  E=4  14

// ---- Bank B ----
assign pin_b03 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // L1   L=10 1
assign pin_b04 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==2)  ? 1'b0 : 1'b1; // P2   P=13 2
assign pin_b05 = (MODE==0 ? SWEEP_GROUP==8  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // J3   J=8  3
assign pin_b06 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // L4   L=10 4
assign pin_b09 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // M1   M=11 1
assign pin_b10 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // P3   P=13 3
assign pin_b11 = (MODE==0 ? SWEEP_GROUP==9  : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // K3   K=9  3
assign pin_b12 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // M4   M=11 4
assign pin_b15 = (MODE==0 ? SWEEP_GROUP==12 : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // N1   N=12 1
assign pin_b16 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // P4   P=13 4
assign pin_b17 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==1)  ? 1'b0 : 1'b1; // P1   P=13 1
assign pin_b18 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==6)  ? 1'b0 : 1'b1; // M6   M=11 6
assign pin_b21 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==3)  ? 1'b0 : 1'b1; // M3   M=11 3
assign pin_b22 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==5)  ? 1'b0 : 1'b1; // P5   P=13 5
assign pin_b23 = (MODE==0 ? SWEEP_GROUP==9  : SWEEP_GROUP==4)  ? 1'b0 : 1'b1; // K4   K=9  4
assign pin_b24 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==7)  ? 1'b0 : 1'b1; // M7   M=11 7
assign pin_b27 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==5)  ? 1'b0 : 1'b1; // L5   L=10 5
assign pin_b28 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==9)  ? 1'b0 : 1'b1; // P9   P=13 9
assign pin_b29 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==6)  ? 1'b0 : 1'b1; // L6   L=10 6
assign pin_b30 = (MODE==0 ? SWEEP_GROUP==11 : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // M12  M=11 12
assign pin_b33 = (MODE==0 ? SWEEP_GROUP==12 : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // N14  N=12 14
assign pin_b34 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==9)  ? 1'b0 : 1'b1; // L9   L=10 9
assign pin_b35 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==12) ? 1'b0 : 1'b1; // L12  L=10 12
assign pin_b36 = (MODE==0 ? SWEEP_GROUP==13 : SWEEP_GROUP==10) ? 1'b0 : 1'b1; // P10  P=13 10
assign pin_b39 = (MODE==0 ? SWEEP_GROUP==10 : SWEEP_GROUP==8)  ? 1'b0 : 1'b1; // L8   L=10 8
assign pin_b41 = (MODE==0 ? SWEEP_GROUP==6  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // G14  G=6  14 [GBIN]
assign pin_b42 = (MODE==0 ? SWEEP_GROUP==5  : SWEEP_GROUP==14) ? 1'b0 : 1'b1; // F14  F=5  14 [GBIN]

endmodule
