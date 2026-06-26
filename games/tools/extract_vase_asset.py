#!/usr/bin/env python3
"""Extract the prototype vase/jar sprite from the original UI sheet."""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


SRC = Path("games/grove/assets/_originals/ui/vault_asset.png")
OUT = Path("games/grove/assets/ui/vase/vase_front.png")
CROP = (625, 610, 1068, 1068)
TOLERANCE = 110
PADDING = 8


def _dist2(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
	return sum((int(a[i]) - int(b[i])) ** 2 for i in range(3))


def _background_mask(rgb: Image.Image) -> Image.Image:
	w, h = rgb.size
	pixels = rgb.load()
	bg = pixels[0, 0]
	limit = TOLERANCE * TOLERANCE
	mask = Image.new("L", (w, h), 0)
	seen = bytearray(w * h)
	q: deque[tuple[int, int]] = deque()

	def enqueue(x: int, y: int) -> None:
		if 0 <= x < w and 0 <= y < h:
			idx = y * w + x
			if seen[idx] == 0:
				seen[idx] = 1
				q.append((x, y))

	for x in range(w):
		enqueue(x, 0)
		enqueue(x, h - 1)
	for y in range(h):
		enqueue(0, y)
		enqueue(w - 1, y)

	mp = mask.load()
	while q:
		x, y = q.popleft()
		if _dist2(pixels[x, y], bg) > limit:
			continue
		mp[x, y] = 255
		enqueue(x + 1, y)
		enqueue(x - 1, y)
		enqueue(x, y + 1)
		enqueue(x, y - 1)
	return mask


def main() -> None:
	src = Image.open(SRC).convert("RGB").crop(CROP)
	bg_mask = _background_mask(src)
	alpha = Image.new("L", src.size, 255)
	alpha.paste(0, mask=bg_mask)
	ap = alpha.load()
	rgb = src.load()
	for y in range(int(src.height * 0.88), src.height):
		for x in range(src.width):
			r, g, b = rgb[x, y]
			if r < 80 and g > 80 and b > 100:
				ap[x, y] = 0
	alpha = alpha.filter(ImageFilter.GaussianBlur(0.7))
	out = src.convert("RGBA")
	out.putalpha(alpha)

	bbox = alpha.getbbox()
	if bbox is None:
		raise RuntimeError("extracted vase alpha is empty")
	x0 = max(0, bbox[0] - PADDING)
	y0 = max(0, bbox[1] - PADDING)
	x1 = min(out.width, bbox[2] + PADDING)
	y1 = min(out.height, bbox[3] + PADDING)
	out = out.crop((x0, y0, x1, y1))

	OUT.parent.mkdir(parents=True, exist_ok=True)
	out.save(OUT)
	print(f"saved={OUT} size={out.width}x{out.height}")


if __name__ == "__main__":
	main()
