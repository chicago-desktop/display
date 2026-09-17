# Where the pictures come from

Every file here is drawn by [tools/display_images.py](../../tools/display_images.py)
(`make icons`) and committed as it came out. It is this module's own pixel
art, set pixel by pixel in the classic sixteen-colour palette with Pillow,
without anti-aliasing. Nothing is traced, scanned or copied from another
product.

- `16/picture.png` — a white sheet with a folded corner and a framed
  landscape on it: sky, a yellow sun, a green hill. The picture of every
  wallpaper row on "Display Properties → Background"
  (`chicago.display:images/picture`).
- `16/blank.png` — a fully transparent square: the "(None)" row of that
  list, drawn without a picture but with its caption in line with the others
  (`chicago.display:images/blank`).
