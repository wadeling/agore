#!/usr/bin/env python3
"""Build AppIcon.appiconset from the pixel-art source PNG."""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Resources" / "branding" / "agore-icon-source.png"
OUT = ROOT / "Apps" / "Agore" / "Assets.xcassets" / "AppIcon.appiconset"

SIZES = [16, 32, 64, 128, 256, 512, 1024]


def main() -> None:
    src = Image.open(SOURCE).convert("RGBA")
    OUT.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        image = src.resize((size, size), Image.Resampling.NEAREST)
        image.save(OUT / f"icon_{size}.png", format="PNG")
    (OUT / "Contents.json").write_text(
        """{
  "images" : [
    { "idiom" : "mac", "size" : "16x16", "scale" : "1x", "filename" : "icon_16.png" },
    { "idiom" : "mac", "size" : "16x16", "scale" : "2x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "1x", "filename" : "icon_32.png" },
    { "idiom" : "mac", "size" : "32x32", "scale" : "2x", "filename" : "icon_64.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "1x", "filename" : "icon_128.png" },
    { "idiom" : "mac", "size" : "128x128", "scale" : "2x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "1x", "filename" : "icon_256.png" },
    { "idiom" : "mac", "size" : "256x256", "scale" : "2x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "1x", "filename" : "icon_512.png" },
    { "idiom" : "mac", "size" : "512x512", "scale" : "2x", "filename" : "icon_1024.png" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    )
    catalog = ROOT / "Apps" / "Agore" / "Assets.xcassets" / "Contents.json"
    catalog.write_text(
        """{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    )
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
