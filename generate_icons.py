#!/usr/bin/env python3
"""Generate app icons for Android (adaptive), iOS, and macOS from SVG.
Uses Apple's official squircle mask for iOS/macOS icons.
"""

import subprocess
import tempfile
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent
SVG_PATH = ROOT / "assets" / "sharks.svg"
MASK_SVG = ROOT / "assets" / "apple_icon_mask.svg"
FLUTTER_APP = ROOT / "apps" / "flutter_app"

SAKURA_PINK = (251, 207, 232)
DARK_BG = (30, 30, 40)
ICON_PINK = (248, 180, 210)


def svg_to_png(svg_path: Path, output_path: Path, size: int):
    subprocess.run([
        "rsvg-convert", "-w", str(size), "-h", str(size),
        str(svg_path), "-o", str(output_path),
    ], check=True)


def create_pink_svg(original: Path, output: Path):
    content = original.read_text()
    content = content.replace(
        'fill="#153655"',
        f'fill="#{ICON_PINK[0]:02X}{ICON_PINK[1]:02X}{ICON_PINK[2]:02X}"'
    )
    output.write_text(content)


def create_icon_simple(fg_path: Path, output_path: Path, size: int,
                       bg_color=SAKURA_PINK, padding_ratio=0.20):
    """Square icon with solid bg, no mask (for Android legacy / fallback)."""
    bg = Image.new("RGBA", (size, size), (*bg_color, 255))
    fg = Image.open(fg_path).convert("RGBA")
    inner = int(size * (1 - padding_ratio * 2))
    fg = fg.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    bg.paste(fg, (offset, offset), fg)
    bg.save(str(output_path), "PNG")


def create_adaptive_foreground(fg_path: Path, output_path: Path, size: int):
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fg = Image.open(fg_path).convert("RGBA")
    inner = int(size * 0.66)
    fg = fg.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    canvas.paste(fg, (offset, offset), fg)
    canvas.save(str(output_path), "PNG")


def create_solid_png(output_path: Path, size: int, color=SAKURA_PINK):
    Image.new("RGBA", (size, size), (*color, 255)).save(str(output_path), "PNG")


def create_apple_icon(fg_path: Path, mask_path: Path, output_path: Path,
                      size: int, bg_color=DARK_BG, padding_ratio=0.10,
                      icon_scale=0.80):
    """Create Apple-style icon using official squircle mask.
    Dark background + pink shark, masked to Apple's continuous corner shape.
    """
    squircle_size = int(size * icon_scale)

    mask_full = Image.open(mask_path).convert("RGBA")
    mask = mask_full.resize((squircle_size, squircle_size), Image.LANCZOS).split()[3]

    squircle = Image.new("RGBA", (squircle_size, squircle_size), (0, 0, 0, 0))
    bg = Image.new("RGBA", (squircle_size, squircle_size), (*bg_color, 255))
    squircle.paste(bg, (0, 0), mask)

    fg = Image.open(fg_path).convert("RGBA")
    inner = int(squircle_size * (1 - padding_ratio * 2))
    fg = fg.resize((inner, inner), Image.LANCZOS)
    fg_offset = (squircle_size - inner) // 2

    fg_layer = Image.new("RGBA", (squircle_size, squircle_size), (0, 0, 0, 0))
    fg_layer.paste(fg, (fg_offset, fg_offset), fg)
    fg_masked = Image.new("RGBA", (squircle_size, squircle_size), (0, 0, 0, 0))
    fg_masked.paste(fg_layer, (0, 0), mask)

    squircle = Image.alpha_composite(squircle, fg_masked)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    paste_offset = (size - squircle_size) // 2
    canvas.paste(squircle, (paste_offset, paste_offset), squircle)
    canvas.save(str(output_path), "PNG")


def create_ios_icon(fg_path: Path, output_path: Path,
                    size: int, bg_color=DARK_BG, padding_ratio=0.10):
    """iOS icons should be square with NO mask - iOS applies its own mask.
    Dark bg + pink shark, full square.
    """
    bg = Image.new("RGBA", (size, size), (*bg_color, 255))
    fg = Image.open(fg_path).convert("RGBA")
    inner = int(size * (1 - padding_ratio * 2))
    fg = fg.resize((inner, inner), Image.LANCZOS)
    offset = (size - inner) // 2
    bg.paste(fg, (offset, offset), fg)
    bg.save(str(output_path), "PNG")


def generate_android():
    print("Generating Android icons (dark bg + pink shark)...")
    res = FLUTTER_APP / "android" / "app" / "src" / "main" / "res"

    densities = {
        "mipmap-mdpi": 48, "mipmap-hdpi": 72, "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144, "mipmap-xxxhdpi": 192,
    }
    adaptive = {
        "mipmap-mdpi": 108, "mipmap-hdpi": 162, "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324, "mipmap-xxxhdpi": 432,
    }

    pink_svg = ROOT / "assets" / "sharks_pink.svg"
    create_pink_svg(SVG_PATH, pink_svg)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        raw = Path(tmp.name)
    svg_to_png(pink_svg, raw, 1024)

    for density, size in densities.items():
        d = res / density
        d.mkdir(parents=True, exist_ok=True)
        create_icon_simple(raw, d / "ic_launcher.png", size, bg_color=DARK_BG, padding_ratio=0.10)

    for density, size in adaptive.items():
        d = res / density
        d.mkdir(parents=True, exist_ok=True)
        create_adaptive_foreground(raw, d / "ic_launcher_foreground.png", size)
        create_solid_png(d / "ic_launcher_background.png", size, color=DARK_BG)

    raw.unlink(missing_ok=True)
    pink_svg.unlink(missing_ok=True)

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n'
    )

    vals = res / "values"
    vals.mkdir(parents=True, exist_ok=True)
    (vals / "ic_launcher_colors.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        f'    <color name="ic_launcher_background">#{DARK_BG[0]:02X}{DARK_BG[1]:02X}{DARK_BG[2]:02X}</color>\n'
        '</resources>\n'
    )
    print("  Android done.")


def generate_ios():
    print("Generating iOS icons (dark bg + pink shark, square - iOS applies mask)...")
    icon_dir = FLUTTER_APP / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

    sizes = [
        ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60), ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120), ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180), ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152), ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]

    pink_svg = ROOT / "assets" / "sharks_pink.svg"
    create_pink_svg(SVG_PATH, pink_svg)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        raw = Path(tmp.name)
    svg_to_png(pink_svg, raw, 1024)

    for name, size in sizes:
        create_ios_icon(raw, icon_dir / name, size)

    raw.unlink(missing_ok=True)
    pink_svg.unlink(missing_ok=True)
    print("  iOS done.")


def _fill_icon_corners(src: Image.Image) -> Image.Image:
    """Extend each row's edge color into transparent corners. No redraw."""
    src = src.convert("RGBA")
    width, height = src.size
    pixels = src.load()
    filled = Image.new("RGB", (width, height))
    out = filled.load()
    row_colors = []
    for y in range(height):
        opaque = [pixels[x, y][:3] for x in range(width) if pixels[x, y][3] > 16]
        row_colors.append((opaque[0], opaque[-1]) if opaque else None)
    for y in range(height):
        if row_colors[y] is not None:
            continue
        for delta in range(1, height):
            if y - delta >= 0 and row_colors[y - delta] is not None:
                row_colors[y] = row_colors[y - delta]
                break
            if y + delta < height and row_colors[y + delta] is not None:
                row_colors[y] = row_colors[y + delta]
                break
    mid = width // 2
    for y in range(height):
        left, right = row_colors[y]
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            edge = left if x < mid else right
            if alpha >= 255:
                out[x, y] = (red, green, blue)
            elif alpha <= 0:
                out[x, y] = edge
            else:
                t = alpha / 255.0
                out[x, y] = (
                    int(red * t + edge[0] * (1 - t)),
                    int(green * t + edge[1] * (1 - t)),
                    int(blue * t + edge[2] * (1 - t)),
                )
    return filled


def generate_ohos_and_store():
    """Square 1024 listing/package icon: expand the original gamepad, do not redraw."""
    print("Expanding branding/app_icon_ohos.png to a 1024 square...")
    src = FLUTTER_APP / "assets" / "branding" / "app_icon_ohos.png"
    if not src.exists():
        raise SystemExit(f"missing {src}")

    filled = _fill_icon_corners(Image.open(src))
    store_png = ROOT / "doc" / "store" / "app_icon_1024.png"
    store_png.parent.mkdir(parents=True, exist_ok=True)
    filled.resize((1024, 1024), Image.LANCZOS).save(store_png, "PNG")

    branding_png = FLUTTER_APP / "assets" / "branding" / "app_icon.png"
    filled.resize((512, 512), Image.LANCZOS).save(branding_png, "PNG")

    for dest in (
        FLUTTER_APP / "ohos" / "AppScope" / "resources" / "base" / "media" / "app_icon.png",
        FLUTTER_APP / "ohos" / "entry" / "src" / "main" / "resources" / "base" / "media" / "icon.png",
        FLUTTER_APP / "ohos" / "entry" / "src" / "ohosTest" / "resources" / "base" / "media" / "icon.png",
    ):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(store_png.read_bytes())

    print(f"  wrote {store_png} and {branding_png} (OHOS source left untouched).")


def generate_macos():
    print("Generating macOS icons (dark bg + pink shark, Apple squircle mask)...")
    icon_dir = FLUTTER_APP / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

    sizes = [
        ("app_icon_16.png", 16), ("app_icon_32.png", 32),
        ("app_icon_64.png", 64), ("app_icon_128.png", 128),
        ("app_icon_256.png", 256), ("app_icon_512.png", 512),
        ("app_icon_1024.png", 1024),
    ]

    pink_svg = ROOT / "assets" / "sharks_pink.svg"
    create_pink_svg(SVG_PATH, pink_svg)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        raw_fg = Path(tmp.name)
    svg_to_png(pink_svg, raw_fg, 1024)

    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        mask_png = Path(tmp.name)
    svg_to_png(MASK_SVG, mask_png, 1024)

    for name, size in sizes:
        create_apple_icon(raw_fg, mask_png, icon_dir / name, size)

    raw_fg.unlink(missing_ok=True)
    mask_png.unlink(missing_ok=True)
    pink_svg.unlink(missing_ok=True)
    print("  macOS done.")


if __name__ == "__main__":
    generate_android()
    generate_ios()
    generate_macos()
    generate_ohos_and_store()
    print("\nAll icons generated!")
