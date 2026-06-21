#!/usr/bin/env python3
"""Resize and frame WCS App Store distribution screenshots for iPhone and iPad."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = Path(__file__).resolve().parents[1]
PROMO = REPO_ROOT / "production" / "apple" / "promotional"
RAW = PROMO / "raw-captures"

BRAND = (18, 56, 107)  # DesignTokens.brand
BRAND_ACCENT = (158, 31, 51)
BG = (242, 244, 248)
WHITE = (255, 255, 255)

IPHONE_SIZE = (1290, 2796)
IPAD_PORTRAIT = (2048, 2732)
IPAD_LANDSCAPE = (2732, 2048)

CAPTIONS = {
    "discover": ("Discover programs", "Structured learning paths with clear progress."),
    "programs": ("Browse programs", "Modules, lessons, quizzes, and assignments in one place."),
    "discussion": ("Learn together", "Course discussions and peer collaboration."),
    "profile": ("Your learning hub", "Access, progress, and account settings."),
}


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def fit_cover(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / img.width, target_h / img.height)
    resized = img.resize((int(img.width * scale), int(img.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def framed_device_shot(
    raw: Image.Image,
    canvas_size: tuple[int, int],
    title: str,
    subtitle: str,
    device_inset: float = 0.08,
) -> Image.Image:
    canvas = Image.new("RGB", canvas_size, BG)
    draw = ImageDraw.Draw(canvas)

    title_font = load_font(72 if canvas_size[0] > 1500 else 58, bold=True)
    sub_font = load_font(40 if canvas_size[0] > 1500 else 34)
    brand_font = load_font(34, bold=True)

    margin = int(canvas_size[0] * 0.07)
    header_h = int(canvas_size[1] * 0.16)
    draw.rectangle((0, 0, canvas_size[0], header_h), fill=BRAND)
    draw.text((margin, int(header_h * 0.22)), "WCS Platform", font=brand_font, fill=WHITE)
    draw.text((margin, int(header_h * 0.52)), title, font=title_font, fill=WHITE)
    draw.text((margin, header_h + 28), subtitle, font=sub_font, fill=(70, 78, 92))

    usable_top = header_h + int(canvas_size[1] * 0.08)
    usable_bottom = int(canvas_size[1] * 0.94)
    usable_h = usable_bottom - usable_top
    usable_w = int(canvas_size[0] * (1 - 2 * device_inset))
    usable_left = (canvas_size[0] - usable_w) // 2

    shot_ratio = raw.width / raw.height
    frame_ratio = usable_w / usable_h
    if shot_ratio > frame_ratio:
        frame_h = usable_h
        frame_w = int(frame_h * shot_ratio)
    else:
        frame_w = usable_w
        frame_h = int(frame_w / shot_ratio)

    fitted = fit_cover(raw, (frame_w, frame_h))
    if frame_w > usable_w:
        left = (frame_w - usable_w) // 2
        fitted = fitted.crop((left, 0, left + usable_w, frame_h))
        frame_w = usable_w
    if frame_h > usable_h:
        top = (frame_h - usable_h) // 2
        fitted = fitted.crop((0, top, frame_w, top + usable_h))
        frame_h = usable_h

    x = usable_left + (usable_w - frame_w) // 2
    y = usable_top + (usable_h - frame_h) // 2

    shadow = Image.new("RGBA", (frame_w + 40, frame_h + 40), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((20, 20, frame_w + 20, frame_h + 20), radius=42, fill=(0, 0, 0, 55))
    canvas.paste(shadow, (x - 20, y - 10), shadow)

    mask = Image.new("L", (frame_w, frame_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, frame_w, frame_h), radius=36, fill=255)
    canvas.paste(fitted, (x, y), mask)

    accent_w = int(canvas_size[0] * 0.18)
    draw.rounded_rectangle(
        (margin, canvas_size[1] - 26, margin + accent_w, canvas_size[1] - 14),
        radius=6,
        fill=BRAND_ACCENT,
    )
    return canvas


def branded_marketing_canvas(size: tuple[int, int], title: str, subtitle: str, bullets: list[str]) -> Image.Image:
    img = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(img)
    title_font = load_font(88 if size[0] > 1500 else 72, bold=True)
    sub_font = load_font(44 if size[0] > 1500 else 38)
    bullet_font = load_font(36 if size[0] > 1500 else 32)

    margin = int(size[0] * 0.08)
    draw.rectangle((0, 0, size[0], int(size[1] * 0.42)), fill=BRAND)
    draw.text((margin, int(size[1] * 0.08)), "WCS Platform", font=load_font(40, bold=True), fill=WHITE)
    draw.text((margin, int(size[1] * 0.14)), title, font=title_font, fill=WHITE)
    draw.text((margin, int(size[1] * 0.24)), subtitle, font=sub_font, fill=(220, 228, 240))

    y = int(size[1] * 0.48)
    for bullet in bullets:
        draw.ellipse((margin, y + 10, margin + 16, y + 26), fill=BRAND_ACCENT)
        draw.text((margin + 32, y), bullet, font=bullet_font, fill=(35, 45, 62))
        y += 72

    card = Image.new("RGB", (size[0] - 2 * margin, int(size[1] * 0.22)), WHITE)
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle((0, 0, card.width, card.height), radius=28, outline=(220, 225, 235), width=2)
    card_draw.text((32, 32), "Trusted progress • Guided video • Quizzes & assignments", font=bullet_font, fill=(60, 70, 88))
    img.paste(card, (margin, size[1] - card.height - margin))
    return img


def resolve_raw(prefix: str, slug: str) -> Path | None:
    direct = RAW / f"{prefix}-{slug}-raw.png"
    if direct.exists():
        return direct
    discover = RAW / f"{prefix}-discover-raw.png"
    if discover.exists():
        return discover
    if prefix == "ipad":
        phone = RAW / f"iphone-{slug}-raw.png"
        if phone.exists():
            return phone
    return None


def process_device(prefix: str, out_dir: Path, canvas_size: tuple[int, int]) -> list[str]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for idx, (slug, (title, subtitle)) in enumerate(CAPTIONS.items(), start=1):
        raw_path = resolve_raw(prefix, slug)
        if raw_path is not None:
            raw = Image.open(raw_path).convert("RGB")
            frame = framed_device_shot(raw, canvas_size, title, subtitle)
        else:
            frame = branded_marketing_canvas(
                canvas_size,
                title,
                subtitle,
                [
                    "Curated programs and sequenced modules",
                    "Lesson video with companion resources",
                    "Access-aware enrollment and progress",
                ],
            )
        device_label = "iPhone" if prefix == "iphone" else "iPad"
        name = f"{device_label}-{canvas_size[0]}x{canvas_size[1]}-{idx}.png"
        path = out_dir / name
        frame.save(path, format="PNG", optimize=True)
        written.append(str(path.relative_to(REPO_ROOT)))
    return written


def write_manifest(iphone_files: list[str], ipad_files: list[str], ipad_landscape: str) -> None:
    manifest = {
        "iphone_6_7_portrait": {
            "size": "1290x2796",
            "files": iphone_files,
            "app_store_connect": "iPhone 6.7\" Display",
        },
        "ipad_12_9_portrait": {
            "size": "2048x2732",
            "files": ipad_files,
            "app_store_connect": "iPad Pro (12.9-inch) (3rd generation)",
        },
        "ipad_12_9_landscape_hero": {
            "size": "2732x2048",
            "file": ipad_landscape,
            "app_store_connect": "iPad Pro (12.9-inch) (2nd generation) — optional landscape",
        },
    }
    path = PROMO / "distribution-manifest.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-hero", action="store_true")
    args = parser.parse_args()

    iphone_dir = PROMO / "distribution" / "iphone-6.7"
    ipad_dir = PROMO / "distribution" / "ipad-12.9"

    iphone_files = process_device("iphone", iphone_dir, IPHONE_SIZE)
    ipad_files = process_device("ipad", ipad_dir, IPAD_PORTRAIT)

    hero_path = ""
    if not args.skip_hero:
        hero_src = PROMO / "AppStore-Hero-2732x2048.png"
        hero_out = PROMO / "distribution" / "ipad-12.9-landscape" / "iPad-2732x2048-hero.png"
        hero_out.parent.mkdir(parents=True, exist_ok=True)
        if hero_src.exists():
            hero = Image.open(hero_src).convert("RGB")
            if hero.size != IPAD_LANDSCAPE:
                hero = fit_cover(hero, IPAD_LANDSCAPE)
            hero.save(hero_out, format="PNG", optimize=True)
        else:
            hero = branded_marketing_canvas(
                IPAD_LANDSCAPE,
                "Structured learning for teams",
                "Programs, video lessons, assessments, and discussion—built for serious learners.",
                ["iPhone and iPad", "Offline-tolerant networking", "Privacy-first design"],
            )
            hero.save(hero_out, format="PNG", optimize=True)
        hero_path = str(hero_out.relative_to(REPO_ROOT))

    write_manifest(iphone_files, ipad_files, hero_path)
    print("Wrote distribution assets:")
    for group in (iphone_files, ipad_files):
        for entry in group:
            print(f"  - {entry}")
    if hero_path:
        print(f"  - {hero_path}")
    print(f"  - production/apple/promotional/distribution-manifest.json")


if __name__ == "__main__":
    main()
