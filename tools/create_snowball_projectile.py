from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


def create_snowball(path: Path) -> None:
    size = 64
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((17, 37, 51, 52), fill=(60, 95, 125, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(3.0))
    image.alpha_composite(shadow)

    body = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)
    draw.ellipse((12, 10, 52, 50), fill=(238, 248, 255, 255), outline=(154, 201, 226, 255), width=2)
    draw.ellipse((17, 13, 45, 35), fill=(255, 255, 255, 135))
    draw.arc((12, 10, 52, 50), 210, 40, fill=(124, 181, 214, 175), width=2)

    # Small packed-snow facets keep it readable at 16-24 px in game.
    draw.arc((20, 23, 40, 41), 185, 315, fill=(162, 207, 231, 185), width=2)
    draw.arc((29, 15, 46, 31), 30, 165, fill=(192, 225, 241, 180), width=2)
    draw.line((21, 38, 27, 36), fill=(176, 216, 236, 170), width=2)
    draw.line((40, 39, 45, 35), fill=(176, 216, 236, 150), width=2)

    image.alpha_composite(body)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


if __name__ == "__main__":
    create_snowball(Path("src/assets/export/projectiles/snowball.png"))
