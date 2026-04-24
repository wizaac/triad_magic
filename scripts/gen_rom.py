#!/usr/bin/env python3
# scripts/gen_rom.py
# Generates rom_init.hex for the triad_magic display driver
#
# ROM layout (2268 bytes total):
#   0x000 – 0x707 : 12 note bitmaps,    150 bytes each (25 cols x 6 pages)
#   0x708 – 0x8DB :  6 quality bitmaps,  78 bytes each (39 cols x 2 pages)
#
# Screen layout (64x48 physical, SSD1306 cols 32-95):
#   NOTE    : controller cols 32-56  (25 wide), pages 0-5  (48 tall)
#   ADC     : controller cols 57-95  (39 wide), pages 0-3  (32 tall) — runtime only
#   QUALITY : controller cols 57-95  (39 wide), pages 4-5  (16 tall)
#
# SSD1306 page format: each byte is 8 vertical pixels, LSB = top pixel
# Data order: col0_page0, col1_page0 ... colN_page0,
#             col0_page1, col1_page1 ... colN_page1, ...
#
# Typewriter aesthetic:
#   - each glyph gets a small random per-character y offset (±2px)
#   - optional x jitter (±1px)
#   - sharp symbol overlaid top-right, slightly smaller, no letter shift
#   - seed is fixed so output is deterministic across runs
#
# Usage:
#   python3 scripts/gen_rom.py [--font path/to/Courier.ttf] [--out rom_init.hex] [--preview]

import argparse
import os
import sys
import random
from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser(description='Generate rom_init.hex for triad_magic')
parser.add_argument('--font', default='fonts/CourierPrime-Regular.ttf',
                    help='Path to TTF font for note and quality glyphs')
parser.add_argument('--out', default='rom_init.hex',
                    help='Output hex file path')
parser.add_argument('--preview', action='store_true',
                    help='Print ASCII art preview of all glyphs')
parser.add_argument('--seed', type=int, default=42,
                    help='RNG seed for typewriter wobble (default 42, deterministic)')
parser.add_argument('--wobble-y', type=int, default=2,
                    help='Max vertical wobble in pixels (default 2)')
parser.add_argument('--wobble-x', type=int, default=1,
                    help='Max horizontal wobble in pixels (default 1)')
args = parser.parse_args()

rng = random.Random(args.seed)

# ── Region dimensions ─────────────────────────────────────────────────────────
NOTE_W      = 25
NOTE_H      = 48    # 6 pages × 8px
NOTE_PAGES  = 6
NOTE_BYTES  = NOTE_W * NOTE_PAGES   # 150

QUAL_W      = 39
QUAL_H      = 32    # 2 pages × 8px
QUAL_PAGES  = 4
QUAL_BYTES  = QUAL_W * QUAL_PAGES   # 78

# ── Image to SSD1306 page-format bytes ───────────────────────────────────────
def image_to_pages(img, width, pages):
    """
    Convert a 1-bit PIL image to SSD1306 horizontal addressing bytes.
    Returns width * pages bytes.
    Order: col0_page0 ... colN_page0, col0_page1 ... colN_page1, ...
    Each byte: bit0 = top pixel of that 8-row page, bit7 = bottom.
    """
    data = []
    for page in range(pages):
        for col in range(width):
            byte = 0
            for bit in range(8):
                row = page * 8 + bit
                if row < img.height and col < img.width:
                    if img.getpixel((col, row)):
                        byte |= (1 << bit)
            data.append(byte)
    return data

# ── Note glyph renderer ───────────────────────────────────────────────────────
def render_note(letter, sharp, font_note, font_sharp):
    """
    Render a note name into a NOTE_W × NOTE_H 1-bit image.

    Typewriter aesthetic:
    - Letter is centered with a small random y offset (wobble)
    - Sharp symbol is overlaid at top-right, slightly smaller font,
      allowed to bleed into the letter — no x shift on the main letter
    - Each call consumes from rng so glyph ordering is deterministic
    """
    img  = Image.new('1', (NOTE_W, NOTE_H), 0)
    draw = ImageDraw.Draw(img)

    wobble_y = rng.randint(-args.wobble_y, args.wobble_y)
    wobble_x = rng.randint(-args.wobble_x, args.wobble_x)

    # Measure letter bounding box
    lb = font_note.getbbox(letter)
    lw = lb[2] - lb[0]
    lh = lb[3] - lb[1]

    # Center letter in NOTE_W × NOTE_H, apply wobble
    x = max(0, (NOTE_W - lw) // 2) - lb[0] + wobble_x
    y = max(0, (NOTE_H - lh) // 2) - lb[1] + wobble_y
    draw.text((x, y), letter, font=font_note, fill=1)
    print(f"{letter}{'#' if sharp else ' '}: bbox={font_note.getbbox(letter)}, "
      f"canvas={NOTE_W}x{NOTE_H}")
    if sharp:
        # Overlay sharp at top-right, let it bleed into the letter
        sb   = font_sharp.getbbox('#')
        sx   = NOTE_W - (sb[2] - sb[0]) - 1 - sb[0]
        sy   = 1 - sb[1]
        draw.text((sx, sy), '#', font=font_sharp, fill=1)

    return img

# ── Quality glyph renderer ────────────────────────────────────────────────────
def render_quality(label, font_qual):
    """
    Render a quality abbreviation into QUAL_W × QUAL_H 1-bit image.
    Text is centered, typewriter wobble applied.
    At 8px minimum font the full label should fit in 39px width.
    """
    img  = Image.new('1', (QUAL_W, QUAL_H), 0)
    draw = ImageDraw.Draw(img)

    wobble_y = rng.randint(-1, 1)   # smaller wobble for small text
    wobble_x = rng.randint(-1, 1)

    # Measure total label width character by character
    char_data = []
    total_w   = 0
    for i, ch in enumerate(label):
        if ch == ' ':
            char_data.append((ch, 3, 0, 0))
            total_w += 3
        else:
            bbox = font_qual.getbbox(ch)
            cw   = bbox[2] - bbox[0]
            char_data.append((ch, cw, bbox[0], bbox[1]))
            total_w += cw + (1 if i < len(label) - 1 else 0)

    start_x = max(0, (QUAL_W - total_w) // 2) + wobble_x
    # Vertically center the 8px cap height in 16px region
    start_y = max(0, (QUAL_H - 8) // 2) + wobble_y

    x = start_x
    for ch, cw, bx0, by0 in char_data:
        if ch == ' ':
            x += cw
            continue
        draw.text((x - bx0, start_y - by0), ch, font=font_qual, fill=1)
        x += cw + 1

    return img

# ── ASCII art preview ─────────────────────────────────────────────────────────
def ascii_preview(img, label):
    print(f'=== {label} ({img.width}×{img.height}) ===')
    any_content = False
    for row in range(img.height):
        line = ''.join('#' if img.getpixel((col, row)) else '.'
                       for col in range(img.width))
        if '#' in line:
            print(line)
            any_content = True
    if not any_content:
        print('(empty — check font path and size)')
    print()

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    if not os.path.exists(args.font):
        print(f'ERROR: font not found at {args.font}')
        print('Pass a path with --font, e.g.:')
        print('  python3 scripts/gen_rom.py --font fonts/CourierPrime-Regular.ttf')
        sys.exit(1)

    print(f'Loading font: {args.font}')

    # Note font: fill as much of 25×48 as possible while keeping readable
    # At Courier 28px the cap height is ~20px, fits with wobble room in 48px
    font_note  = ImageFont.truetype(args.font, 44)
    # Sharp overlay: smaller, sits top-right, allowed to bleed
    font_sharp = ImageFont.truetype(args.font, 20)
    # Quality font: minimum readable — 8px Courier cap height ~6px, fits in 16px
    font_qual  = ImageFont.truetype(args.font, 18)

    rom = []

    # ── Note bitmaps (12 × 150 = 1800 bytes) ─────────────────────────────────
    notes = [
        ('C', False), ('C', True),
        ('D', False), ('D', True),
        ('E', False),
        ('F', False), ('F', True),
        ('G', False), ('G', True),
        ('A', False), ('A', True),
        ('B', False),
    ]

    print(f'\nRendering note bitmaps  ({NOTE_W}×{NOTE_H}, {NOTE_BYTES} bytes each)...')
    for letter, sharp in notes:
        name = letter + ('#' if sharp else ' ')
        img  = render_note(letter, sharp, font_note, font_sharp)
        data = image_to_pages(img, NOTE_W, NOTE_PAGES)
        assert len(data) == NOTE_BYTES, \
            f'Note {name}: expected {NOTE_BYTES} bytes, got {len(data)}'
        rom.extend(data)
        nz = sum(1 for b in data if b)
        if args.preview:
            ascii_preview(img, f'Note: {name}')
        else:
            bar = '█' * min(40, nz // 2)
            print(f'  {name}  {nz:3d} non-zero bytes  {bar}')

    assert len(rom) == 1800, f'Note section: expected 1800 bytes, got {len(rom)}'
    print(f'  → 0x000–0x707  ({len(rom)} bytes)')

    # ── Quality bitmaps (6 × 78 = 468 bytes) ─────────────────────────────────
    # Encoding: 0=maj 1=min 2=dim 3=aug 4=M7 5=m7
    qualities = ['maj', 'min', 'dim', 'aug', 'sus2', 'sus4','POW']

    print(f'\nRendering quality bitmaps  ({QUAL_W}×{QUAL_H}, {QUAL_BYTES} bytes each)...')
    for q in qualities:
        img  = render_quality(q, font_qual)
        data = image_to_pages(img, QUAL_W, QUAL_PAGES)
        assert len(data) == QUAL_BYTES, \
            f'Quality {q}: expected {QUAL_BYTES} bytes, got {len(data)}'
        rom.extend(data)
        nz = sum(1 for b in data if b)
        if args.preview:
            ascii_preview(img, f'Quality: {q}')
        else:
            bar = '█' * min(40, nz * 2)
            print(f'  {q}  {nz:3d} non-zero bytes  {bar}')

    assert len(rom) == 2892, f'ROM total: expected 2892 bytes, got {len(rom)}'
    print(f'  → 0x708–0x8DB  ({len(rom) - 1800} bytes)')

    # ── Write hex file ────────────────────────────────────────────────────────
    with open(args.out, 'w') as f:
        for byte in rom:
            f.write(f'{byte:02X}\n')

    print(f'\n✓ wrote {len(rom)} bytes → {args.out}')
    print(f'  non-zero: {sum(1 for b in rom if b)} / {len(rom)}')
    print(f'  note region:    0x000–0x707  (1800 bytes, 12 glyphs)')
    print(f'  quality region: 0x708–0x8DB  ( 468 bytes,  6 glyphs)')
    print(f'  ADC region:     runtime only (no ROM entry)')

if __name__ == '__main__':
    main()
