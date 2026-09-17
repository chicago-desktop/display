#!/usr/bin/env python3
"""Draws the Display module's image pack: assets/images/.

- `16/picture.png` — a picture file: a white sheet with a folded corner
  and a small landscape on it (sky, sun, a green hill). The rows of the
  Wallpaper list on "Display Properties -> Background".
- `16/blank.png` — a fully transparent square: the "(None)" row of that
  list, which the original draws without a picture but with its caption
  where the other captions stand.

This module's own pixel art, set pixel by pixel below without
anti-aliasing, in the classic sixteen-colour palette. Nothing is traced or
copied from another product. Needs Pillow:

    python3 tools/display_images.py        # or `make icons`

The files are named `chicago.display:images/<file>`.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "assets" / "images"

PALETTE = {
    ".": (0, 0, 0, 0),
    "k": (0, 0, 0, 255),
    "w": (255, 255, 255, 255),
    "g": (128, 128, 128, 255),
    "b": (0, 255, 255, 255),
    "y": (255, 255, 0, 255),
    "G": (0, 128, 0, 255),
    "l": (0, 255, 0, 255),
}

# 16x16: the sheet's outline is black, the folded corner grey; the landscape
# sits in a black frame on the sheet.
PICTURE = [
    "..kkkkkkkk......",
    "..kwwwwwwkk.....",
    "..kwwwwwwkgk....",
    "..kwwwwwwkggk...",
    "..kwwwwwwkkkkk..",
    "..kwwwwwwwwwwk..",
    "..kwkkkkkkkkwk..",
    "..kwkbbbbyykwk..",
    "..kwkbbbbyykwk..",
    "..kwkbbbbbbkwk..",
    "..kwkbllbbbkwk..",
    "..kwklllllGkwk..",
    "..kwkGllGGGkwk..",
    "..kwkkkkkkkkwk..",
    "..kwwwwwwwwwwk..",
    "..kkkkkkkkkkkk..",
]


def draw(rows):
    image = Image.new("RGBA", (len(rows[0]), len(rows)), PALETTE["."])
    for y, row in enumerate(rows):
        assert len(row) == len(rows[0]), f"row {y} is {len(row)} wide"
        for x, key in enumerate(row):
            image.putpixel((x, y), PALETTE[key])
    return image


def main():
    folder = ROOT / "16"
    folder.mkdir(parents=True, exist_ok=True)
    draw(PICTURE).save(folder / "picture.png")
    draw(["." * 16] * 16).save(folder / "blank.png")


if __name__ == "__main__":
    main()
