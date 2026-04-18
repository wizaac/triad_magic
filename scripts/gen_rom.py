# generates placeholder ROM content as hex file for $readmemh
# note bitmaps: alternating AA/55 stripes
# quality bitmaps: different fill densities

lines = []

# note placeholders - 12 notes * 192 bytes = 2304 bytes
for i in range(2304):
    lines.append("AA" if i % 2 == 0 else "55")

# quality placeholders - 6 qualities * 96 bytes = 576 bytes
fills = [0x11, 0x33, 0x55, 0x77, 0xBB, 0xFF]
for fill in fills:
    for _ in range(96):
        lines.append(f"{fill:02X}")

with open("rom_init.hex", "w") as f:
    for line in lines:
        f.write(line + "\n")

print(f"Generated {len(lines)} bytes")
