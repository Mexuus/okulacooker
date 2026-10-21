"""Rebuild the ingredient food icons from Microsoft Fluent Emoji (3D).

Reads ``tool/sources/ingredient_icons.json`` (canonical_id -> emoji_slug),
resolves each unique slug to its Fluent Emoji 3D PNG in
https://github.com/microsoft/fluentui-emoji (MIT license), downloads it,
resizes it to 128x128 with LANCZOS resampling (alpha preserved) and writes
``assets/icons/food/<emoji_slug>.webp`` (quality 85, with alpha).

A slug is the emoji's folder name lowercased with every run of
non-alphanumeric characters replaced by "_" (e.g. "Poultry leg" ->
"poultry_leg", "Jack-o-lantern" -> "jack_o_lantern").

Usage (from the repo root):
    pip install Pillow
    python tool/build_icons.py            # regenerate the WebP icons
    python tool/build_icons.py --sheet    # also write build/icon_sheet.png

Downloaded PNGs are cached in build/fluent_cache/.
"""

import argparse
import io
import json
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MAPPING = ROOT / "tool" / "sources" / "ingredient_icons.json"
OUT_DIR = ROOT / "assets" / "icons" / "food"
CACHE_DIR = ROOT / "build" / "fluent_cache"
SHEET = ROOT / "build" / "icon_sheet.png"

TREE_URL = "https://api.github.com/repos/microsoft/fluentui-emoji/git/trees/main?recursive=1"
RAW_URL = "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main/"
SIZE = 128
QUALITY = 85


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "tapcook-build-icons"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def emoji_paths() -> dict:
    """Map slug -> repo path of every 3D PNG (assets/<Name>/3D/<name>_3d.png)."""
    tree = json.loads(fetch(TREE_URL))["tree"]
    paths = {}
    for entry in tree:
        parts = entry["path"].split("/")
        if len(parts) == 4 and parts[0] == "assets" and parts[2] == "3D" and parts[3].endswith("_3d.png"):
            paths[slugify(parts[1])] = entry["path"]
    return paths


def build_icon(slug: str, repo_path: str) -> Path:
    cached = CACHE_DIR / f"{slug}.png"
    if not cached.exists():
        cached.write_bytes(fetch(RAW_URL + urllib.parse.quote(repo_path)))
    img = Image.open(io.BytesIO(cached.read_bytes())).convert("RGBA")
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    out = OUT_DIR / f"{slug}.webp"
    img.save(out, "WEBP", quality=QUALITY, method=6, exact=False)
    return out


def contact_sheet(slugs: list) -> None:
    cols, cell_w, cell_h = 8, 160, 165
    rows = (len(slugs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (235, 235, 235))
    draw = ImageDraw.Draw(sheet)
    for i, slug in enumerate(slugs):
        x, y = (i % cols) * cell_w, (i // cols) * cell_h
        icon = Image.open(OUT_DIR / f"{slug}.webp").convert("RGBA")
        sheet.paste(icon, (x + (cell_w - SIZE) // 2, y + 6), icon)
        draw.text((x + 6, y + SIZE + 14), slug, fill=(0, 0, 0))
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET)
    print(f"Wrote {SHEET}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--sheet", action="store_true", help="also write build/icon_sheet.png")
    args = parser.parse_args()

    mapping = json.loads(MAPPING.read_text(encoding="utf-8"))
    slugs = sorted(set(mapping.values()))
    paths = emoji_paths()
    unknown = [s for s in slugs if s not in paths]
    if unknown:
        print(f"Unknown Fluent emoji slugs: {unknown}", file=sys.stderr)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    for slug in slugs:
        build_icon(slug, paths[slug])
        print(f"  {slug}")
    print(f"Built {len(slugs)} icons for {len(mapping)} ingredients in {OUT_DIR}")

    if args.sheet:
        contact_sheet(slugs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
