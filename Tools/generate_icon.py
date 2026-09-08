#!/usr/bin/env python3
"""Draw Pep's original smiling workout buddy as a flat iOS icon. Requires Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

ROOT = Path(__file__).resolve().parents[1]
assets = ROOT / "RepComet/Assets.xcassets"
icon_dir = assets / "AppIcon.appiconset"
icon_dir.mkdir(parents=True, exist_ok=True)
size = 2048
violet = "#6547D5"
butter = "#FFD85F"
ink = "#282239"
lavender = "#E5DEFC"
image = Image.new("RGB", (size, size), violet)

# An oversampled, slightly tilted soft square keeps the identity legible even
# at home-screen size. A workout sweatband adds character without decoration.
buddy = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(buddy)
draw.rounded_rectangle((405, 405, 1643, 1643), radius=335, fill=butter)
draw.rounded_rectangle((410, 626, 1638, 810), radius=86, fill=violet)
draw.rounded_rectangle((519, 685, 1529, 725), radius=20, fill=lavender)
draw.ellipse((719, 935, 842, 1111), fill=ink)
draw.ellipse((1206, 935, 1329, 1111), fill=ink)
draw.arc((858, 1058, 1190, 1387), start=18, end=162, fill=ink, width=62)
# Round off the smile's ends.
for x, y in [(1152, 1264), (896, 1264)]:
    draw.ellipse((x - 30, y - 30, x + 30, y + 30), fill=ink)
buddy = buddy.rotate(8, resample=Image.Resampling.BICUBIC)
image.paste(buddy, mask=buddy)
image.resize((1024, 1024), Image.Resampling.LANCZOS).save(icon_dir / "AppIcon.png")
info = {"author":"xcode", "version":1}
(assets / "Contents.json").write_text(json.dumps({"info":info}, indent=2)+"\n")
(icon_dir / "Contents.json").write_text(json.dumps({"images":[{"filename":"AppIcon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":info},indent=2)+"\n")
accent_dir = assets / "AccentColor.colorset"
accent_dir.mkdir(exist_ok=True)
(accent_dir / "Contents.json").write_text(json.dumps({"colors":[{"idiom":"universal","color":{"color-space":"srgb","components":{"alpha":"1.000","red":"0.396","green":"0.278","blue":"0.835"}}}],"info":info},indent=2)+"\n")
print(icon_dir / "AppIcon.png")
