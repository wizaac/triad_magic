#!/usr/bin/env python3
# scripts/gen_rom.py
# Generates rom_init.hex for the triad_magic display driver
#
# ROM layout (2880 bytes total):
#   0    - 2303 : 12 note bitmaps,    192 bytes each (32 cols x 6 pages)
#   2304 - 2879 : 6  quality bitmaps,  96 bytes each (32 cols x 3 pages)
#
# SSD1306 page format: each byte is 8 vertical pixels, LSB = top pixel
# Data is written column by column, page by page (horizontal addressing mode)
# So byte order is: col0_page0, col1_page0, ... col31_page0,
#                   col0_page1, col1_page1, ... col31_page1, etc.
#
# Note region:    32 wide x 48 tall = 32 cols x 6 pages
# Quality region: 32 wide x 24 tall = 32 cols x 3 pages
#
# Usage: python3 scripts/gen_rom.py [--font path/to/font.ttf] [--out rom_init.hex]

import argparse
import os
import sys
from PIL import Image, ImageDraw, ImageFont

# ── Argument parsing ──────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description='Generate rom_init.hex for triad_magic')
parser.add_argument('--font', default='fonts/UnifrakturMaguntia-Regular.ttf',
                    help='Path to TTF font for note glyphs')
parser.add_argument('--out', default='rom_init.hex',
                    help='Output hex file path')
parser.add_argument('--preview', action='store_true',
                    help='Print ASCII art preview of all glyphs')
args = parser.parse_args()

# ── Region dimensions ─────────────────────────────────────────────────────────
NOTE_W      = 32
NOTE_H      = 48   # 6 pages x 8px
NOTE_PAGES  = 6
NOTE_BYTES  = NOTE_W * NOTE_PAGES   # 192

QUAL_W      = 32
QUAL_H      = 24   # 3 pages x 8px
QUAL_PAGES  = 3
QUAL_BYTES  = QUAL_W * QUAL_PAGES   # 96

# ── Image to SSD1306 page-format bytes ───────────────────────────────────────
def image_to_pages(img, width, pages):
    """
    Convert a 1-bit PIL image to SSD1306 horizontal addressing mode bytes.
    Returns a list of (width * pages) bytes.
    Data order: col0_page0, col1_page0, ... colN_page0,
                col0_page1, col1_page1, ... colN_page1, ...
    Each byte: bit0 = top pixel of that 8-row page, bit7 = bottom pixel.
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
def render_note(letter, sharp, font_big, font_sharp):
    """
    Render a note name (e.g. 'C#') into a 32x48 1-bit image.
    Letter rendered large and centered; sharp symbol small at top-right.
    """
    img = Image.new('1', (NOTE_W, NOTE_H), 0)
    draw = ImageDraw.Draw(img)

    lb = font_big.getbbox(letter)
    lw = lb[2] - lb[0]
    lh = lb[3] - lb[1]

    if sharp:
        # Shift letter left to leave room for sharp symbol
        x = max(0, (NOTE_W - lw - 9) // 2)
        y = max(0, (NOTE_H - lh) // 2 - lb[1])
        draw.text((x - lb[0], y), letter, font=font_big, fill=1)
        sb = font_sharp.getbbox('#')
        draw.text((NOTE_W - sb[2] - 1, 1), '#', font=font_sharp, fill=1)
    else:
        x = max(0, (NOTE_W - lw) // 2)
        y = max(0, (NOTE_H - lh) // 2 - lb[1])
        draw.text((x - lb[0], y), letter, font=font_big, fill=1)

    return img

# ── Quality glyph renderer ────────────────────────────────────────────────────
def render_quality(label, font8):
    """
    Render a quality abbreviation into a 32x24 1-bit image.
    Uses 8px font, text centered horizontally, centered vertically.
    """
    img = Image.new('1', (QUAL_W, QUAL_H), 0)
    draw = ImageDraw.Draw(img)

    # Measure total width of label
    x = 0
    char_data = []
    for ch in label:
        if ch == ' ':
            char_data.append((ch, 3, 0, 0, 0))
            x += 3
        else:
            bbox = font8.getbbox(ch)
            w = bbox[2] - bbox[0]
            char_data.append((ch, w, bbox[0], bbox[1], bbox[3]-bbox[1]))
            x += w + 1
    total_w = x - 1

    # Center horizontally
    start_x = max(0, (QUAL_W - total_w) // 2)
    # Center vertically — font8 glyphs are ~7px tall, center in 24px
    start_y = max(0, (QUAL_H - 8) // 2)

    x = start_x
    for item in char_data:
        ch = item[0]
        if ch == ' ':
            x += 3
            continue
        w, bx0, by0, bh = item[1], item[2], item[3], item[4]
        draw.text((x - bx0, start_y - by0), ch, font=font8, fill=1)
        x += w + 1

    return img

# ── ASCII art preview ─────────────────────────────────────────────────────────
def ascii_preview(img, label):
    print(f'=== {label} ===')
    any_content = False
    for row in range(img.height):
        line = ''.join('#' if img.getpixel((col, row)) else '.' 
                       for col in range(img.width))
        if '#' in line:
            print(line)
            any_content = True
    if not any_content:
        print('(empty)')
    print()

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    # Load fonts
    if not os.path.exists(args.font):
        print(f'ERROR: Font not found at {args.font}')
        print('Usage: python3 scripts/gen_rom.py --font path/to/UnifrakturMaguntia-Regular.ttf')
        sys.exit(1)

    print(f'Loading font: {args.font}')
    font_big   = ImageFont.truetype(args.font, 36)
    font_sharp = ImageFont.truetype(args.font, 14)
    font8      = ImageFont.truetype(args.font, 8)

    rom = []

    # ── Note bitmaps (12 x 192 bytes = 2304 bytes) ────────────────────────────
    notes = [
        ('C', ''),  ('C', '#'),
        ('D', ''),  ('D', '#'),
        ('E', ''),
        ('F', ''),  ('F', '#'),
        ('G', ''),  ('G', '#'),
        ('A', ''),  ('A', '#'),
        ('B', ''),
    ]

    print('Rendering note bitmaps...')
    for letter, sharp in notes:
        name = letter + ('#' if sharp else '')
        img = render_note(letter, sharp, font_big, font_sharp)
        data = image_to_pages(img, NOTE_W, NOTE_PAGES)
        assert len(data) == NOTE_BYTES, f'Note {name}: expected {NOTE_BYTES} bytes, got {len(data)}'
        rom.extend(data)
        if args.preview:
            ascii_preview(img, f'Note: {name}')
        else:
            print(f'  {name}: {sum(1 for b in data if b)} non-zero bytes')

    assert len(rom) == 2304, f'Note section: expected 2304 bytes, got {len(rom)}'

    # ── Quality bitmaps (6 x 96 bytes = 576 bytes) ───────────────────────────
    # Quality encoding matches display_driver.v:
    #   0=maj, 1=min, 2=dim, 3=aug, 4=M7, 5=m7
    qualities = ['maj', 'min', 'dim', 'aug', 'M7', 'm7']

    print('Rendering quality bitmaps...')
    for q in qualities:
        img = render_quality(q, font8)
        data = image_to_pages(img, QUAL_W, QUAL_PAGES)
        assert len(data) == QUAL_BYTES, f'Quality {q}: expected {QUAL_BYTES} bytes, got {len(data)}'
        rom.extend(data)
        if args.preview:
            ascii_preview(img, f'Quality: {q}')
        else:
            print(f'  {q}: {sum(1 for b in data if b)} non-zero bytes')

    assert len(rom) == 2880, f'ROM total: expected 2880 bytes, got {len(rom)}'

    # ── Write hex file ────────────────────────────────────────────────────────
    with open(args.out, 'w') as f:
        for byte in rom:
            f.write(f'{byte:02X}\n')

    print(f'\nWrote {len(rom)} bytes to {args.out}')
    print(f'Non-zero bytes: {sum(1 for b in rom if b)} / {len(rom)}')

if __name__ == '__main__':
    main()
EOF
