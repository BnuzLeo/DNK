from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageSequence

FRAME_SIZE = (120, 120)
TARGET_VISUAL_HEIGHT = 108
BASELINE_Y = 116


def _normalize_frame(frame: Image.Image) -> Image.Image:
    frame = frame.convert("RGBA")
    bbox = frame.getbbox()
    if bbox is None:
        return Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))

    cropped = frame.crop(bbox)
    scale = TARGET_VISUAL_HEIGHT / float(cropped.height)
    new_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    if new_size[0] > FRAME_SIZE[0] - 4:
        width_scale = (FRAME_SIZE[0] - 4) / float(new_size[0])
        new_size = (
            max(1, round(new_size[0] * width_scale)),
            max(1, round(new_size[1] * width_scale)),
        )

    resized = cropped.resize(new_size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
    x = (FRAME_SIZE[0] - new_size[0]) // 2
    y = min(BASELINE_Y - new_size[1], FRAME_SIZE[1] - new_size[1])
    result.alpha_composite(resized, (x, max(0, y)))
    return result


def _save_gif_strip(source: Path, target: Path, target_frames: int = 0) -> int:
	image = Image.open(source)
	frames = [_normalize_frame(frame) for frame in ImageSequence.Iterator(image)]
	if not frames:
		raise RuntimeError(f"{source} has no frames")
	output_count = target_frames if target_frames > 0 else len(frames)
	strip = Image.new("RGBA", (FRAME_SIZE[0] * output_count, FRAME_SIZE[1]), (0, 0, 0, 0))
	for index in range(output_count):
		frame = frames[index % len(frames)]
		strip.alpha_composite(frame, (index * FRAME_SIZE[0], 0))
	strip.save(target)
	return output_count


def _save_image_strip(source: Path, target: Path) -> int:
	image = _normalize_frame(Image.open(source))
	image.save(target)
	return 1


def convert(asset_dir: Path) -> None:
	mapping = [
		("雪猿投手待机.gif", "enemy_shooter_snow_ape_idle_strip8.png", _save_gif_strip, 8),
		("雪猿投手行走.gif", "enemy_shooter_snow_ape_walk_strip8.png", _save_gif_strip, 8),
		("雪猿投手攻击.gif", "enemy_shooter_snow_ape_shoot_strip8.png", _save_gif_strip, 8),
		("雪猿投手死亡.jpg", "enemy_shooter_snow_ape_death_strip1.png", _save_image_strip, 0),
	]
	for source_name, target_name, converter, target_frames in mapping:
		source = asset_dir / source_name
		target = asset_dir / target_name
		frame_count = converter(source, target, target_frames) if target_frames > 0 else converter(source, target)
		print(f"wrote {target} ({frame_count} frames)")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: convert_shooter_assets.py <asset_dir>")
        return 2
    convert(Path(sys.argv[1]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
