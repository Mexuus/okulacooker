"""Rebuild the recipe hero photos from Wikimedia Commons.

Reads every ``tool/sources/recipe_photos_*.json`` file. Each has the shape::

    {
      "photos": {
        "<dish_key>": {
          "file": "<output file name, e.g. w_beef_tacos.webp>",
          "credit": "<author, plain text>",
          "license": "<LicenseShortName, e.g. CC BY-SA 4.0>",
          "source": "https://commons.wikimedia.org/wiki/File:..."
        }
      },
      "recipes": {"<exact recipe title>": "<dish_key>"}
    }

For every photo the script resolves the ``source`` File: page through the
MediaWiki API (imageinfo), re-checks that the license is still free
(CC0 / public domain / CC BY / CC BY-SA), downloads a 1280 px rendition (or
the original when that would be too small), center-crops it to 4:3, resizes
it to 800x600 with LANCZOS resampling and writes
``assets/photos/<file>`` as WebP (quality 72).

Usage (from the repo root):
    pip install Pillow
    python tool/build_photos.py                 # (re)build every photo
    python tool/build_photos.py --only w_       # only files starting with w_
    python tool/build_photos.py --sheet         # also write build/photo_sheet.jpg
    python tool/build_photos.py --force         # re-encode even if output exists

Downloads are cached in build/photo_cache/. Requests are sequential, send a
descriptive User-Agent and pause briefly, per Wikimedia API etiquette.
"""

import argparse
import hashlib
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / 'tool' / 'sources'
OUT_DIR = ROOT / 'assets' / 'photos'
CACHE = ROOT / 'build' / 'photo_cache'
API = 'https://commons.wikimedia.org/w/api.php'
UA = 'TapCookPhotoBuilder/1.0 (https://github.com/Mexuus/tapcook; mitcho295@gmail.com)'
SIZE = (800, 600)
QUALITY = 72
FREE = re.compile(r'^(cc0|public domain|pd\b|pd-|cc[ -]by(-sa)?([ -]\d|$))', re.I)
NOT_FREE = re.compile(r'-nc|-nd|\bnc\b|\bnd\b|fair use', re.I)


def http(url: str) -> bytes:
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={'User-Agent': UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                data = r.read()
            time.sleep(0.3)
            return data
        except Exception as e:  # noqa: BLE001 - retry any transient failure
            if attempt == 3:
                raise
            print(f'  retry ({e})', file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(url)


def image_info(source: str) -> dict:
    title = urllib.parse.unquote(source.rsplit('/wiki/', 1)[1]).replace('_', ' ')
    params = {
        'action': 'query', 'format': 'json', 'formatversion': '2', 'titles': title,
        'prop': 'imageinfo', 'iiprop': 'url|size|extmetadata', 'iiurlwidth': '1280',
        'iiextmetadatafilter': 'LicenseShortName',
    }
    data = json.loads(http(API + '?' + urllib.parse.urlencode(params)))
    page = data['query']['pages'][0]
    if 'imageinfo' not in page:
        raise RuntimeError(f'missing on Commons: {title}')
    return page['imageinfo'][0]


def fetch_image(source: str) -> Image.Image:
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / (hashlib.md5(source.encode()).hexdigest() + '.img')
    if not cached.exists():
        ii = image_info(source)
        lic = ii.get('extmetadata', {}).get('LicenseShortName', {}).get('value', '')
        if NOT_FREE.search(lic) or not FREE.match(lic.strip()):
            raise RuntimeError(f'license no longer allowed ({lic}): {source}')
        url = ii.get('thumburl') or ii['url']
        if min(ii.get('thumbwidth', 0), ii.get('thumbheight', 0)) < SIZE[1]:
            url = ii['url']
        cached.write_bytes(http(url))
    return Image.open(io.BytesIO(cached.read_bytes())).convert('RGB')


def crop_4_3(im: Image.Image) -> Image.Image:
    w, h = im.size
    target = SIZE[0] / SIZE[1]
    if w / h > target:
        nw = round(h * target)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = round(w / target)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return im.resize(SIZE, Image.LANCZOS)


def load_photos() -> dict:
    photos = {}
    for path in sorted(SOURCES.glob('recipe_photos_*.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        for key, p in data.get('photos', {}).items():
            photos[p['file']] = dict(p, key=key, manifest=path.name)
    return photos


def contact_sheet(files: list, out: Path) -> None:
    cols, cw, ch = 6, 300, 245
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * cw, max(1, rows) * ch), (20, 20, 20))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('arialbd.ttf', 14)
    except OSError:
        font = ImageFont.load_default()
    for i, f in enumerate(files):
        x, y = (i % cols) * cw, (i // cols) * ch
        im = Image.open(OUT_DIR / f).convert('RGB').resize((cw - 6, (cw - 6) * 3 // 4))
        sheet.paste(im, (x + 3, y + 3))
        draw.text((x + 4, y + 228), f[:-5], fill=(255, 255, 0), font=font)
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=85)
    print(f'wrote {out}')


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--only', default='', help='only output files starting with this prefix')
    ap.add_argument('--force', action='store_true', help='re-encode existing outputs')
    ap.add_argument('--sheet', action='store_true', help='write build/photo_sheet.jpg')
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    photos = {f: p for f, p in load_photos().items() if f.startswith(args.only)}
    failed = []
    for f, p in sorted(photos.items()):
        out = OUT_DIR / f
        if out.exists() and not args.force:
            continue
        try:
            crop_4_3(fetch_image(p['source'])).save(out, 'WEBP', quality=QUALITY, method=6)
            print(f'{f}  {out.stat().st_size // 1024} KB')
        except Exception as e:  # noqa: BLE001 - report and continue
            failed.append(f)
            print(f'FAILED {f}: {e}', file=sys.stderr)
    total = sum((OUT_DIR / f).stat().st_size for f in photos if (OUT_DIR / f).exists())
    print(f'{len(photos)} photos, {total / 1e6:.2f} MB total, {len(failed)} failed')
    if args.sheet:
        prefix = args.only or 'all'
        contact_sheet(sorted(f for f in photos if (OUT_DIR / f).exists()),
                      ROOT / 'build' / f'photo_sheet_{prefix.rstrip("_")}.jpg')
    if failed:
        sys.exit(1)


if __name__ == '__main__':
    main()
