from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp" / "imagegen" / "characters_enemies"


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    return alpha.point(lambda value: 255 if value > threshold else 0).getbbox()


def fit_to_frame(source: Image.Image, size: int, max_ratio: float = 0.9) -> Image.Image:
    image = source.convert("RGBA")
    bbox = alpha_bbox(image)
    if bbox is None:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))

    subject = image.crop(bbox)
    max_w = max(1, int(size * max_ratio))
    max_h = max(1, int(size * max_ratio))
    scale = min(max_w / subject.width, max_h / subject.height)
    new_size = (max(1, int(subject.width * scale)), max(1, int(subject.height * scale)))
    subject = subject.resize(new_size, Image.Resampling.LANCZOS)

    frame = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    frame.alpha_composite(subject, ((size - subject.width) // 2, (size - subject.height) // 2))
    return frame


def crop_panel(sheet: Image.Image, index: int, count: int) -> Image.Image:
    width, height = sheet.size
    left = round(width * index / count)
    right = round(width * (index + 1) / count)
    return sheet.crop((left, 0, right, height))


def transform_frame(
    frame: Image.Image,
    scale_x: float = 1.0,
    scale_y: float = 1.0,
    dx: int = 0,
    dy: int = 0,
    rotation: float = 0.0,
    alpha: float = 1.0,
    brightness: float = 1.0,
) -> Image.Image:
    size = frame.width
    scaled_size = (max(1, int(size * scale_x)), max(1, int(size * scale_y)))
    work = frame.resize(scaled_size, Image.Resampling.LANCZOS)
    if rotation:
        work = work.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)
    if brightness != 1.0:
        rgb = ImageEnhance.Brightness(work.convert("RGB")).enhance(brightness)
        work = Image.merge("RGBA", (*rgb.split(), work.getchannel("A")))
    if alpha != 1.0:
        a = work.getchannel("A").point(lambda value: int(value * alpha))
        work.putalpha(a)

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(work, ((size - work.width) // 2 + dx, (size - work.height) // 2 + dy))
    return out


def make_strip(base: Image.Image, pattern: list[dict[str, float | int]]) -> Image.Image:
    frames = [transform_frame(base, **item) for item in pattern]
    out = Image.new("RGBA", (base.width * len(frames), base.height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        out.alpha_composite(frame, (index * base.width, 0))
    return out


def save_png(image: Image.Image, relative_path: str) -> None:
    for prefix in ("assets/export", "src/assets/export"):
        path = ROOT / prefix / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        image.save(path)
        print(path.relative_to(ROOT))


PATTERNS = {
    "idle4": [
        {"scale_x": 1.0, "scale_y": 1.0, "dy": 0},
        {"scale_x": 0.985, "scale_y": 1.02, "dy": -1},
        {"scale_x": 1.0, "scale_y": 1.0, "dy": 0},
        {"scale_x": 1.015, "scale_y": 0.985, "dy": 1},
    ],
    "idle6": [
        {"scale_x": 1.0, "scale_y": 1.0, "dy": 0},
        {"scale_x": 0.99, "scale_y": 1.015, "dy": -1},
        {"scale_x": 0.98, "scale_y": 1.03, "dy": -1},
        {"scale_x": 1.0, "scale_y": 1.0, "dy": 0},
        {"scale_x": 1.015, "scale_y": 0.99, "dy": 1},
        {"scale_x": 1.005, "scale_y": 0.995, "dy": 1},
    ],
    "move6": [
        {"dx": -2, "dy": 1, "rotation": -3},
        {"dx": 0, "dy": -1, "rotation": 2},
        {"dx": 2, "dy": 0, "rotation": -2},
        {"dx": 1, "dy": 1, "rotation": 3},
        {"dx": -1, "dy": -1, "rotation": 0},
        {"dx": 0, "dy": 0, "rotation": -1},
    ],
    "hit2": [
        {"dx": 3, "brightness": 1.25},
        {"dx": -2, "brightness": 1.05},
    ],
    "tell4": [
        {"scale_x": 1.0, "scale_y": 1.0, "brightness": 1.0},
        {"scale_x": 1.03, "scale_y": 1.03, "brightness": 1.15},
        {"scale_x": 1.06, "scale_y": 1.06, "brightness": 1.3},
        {"scale_x": 1.02, "scale_y": 1.02, "brightness": 1.1},
    ],
    "dash6": [
        {"scale_x": 1.06, "scale_y": 0.96, "dx": -2},
        {"scale_x": 1.12, "scale_y": 0.92, "dx": 1},
        {"scale_x": 1.18, "scale_y": 0.9, "dx": 3},
        {"scale_x": 1.12, "scale_y": 0.92, "dx": 1},
        {"scale_x": 1.08, "scale_y": 0.95, "dx": -1},
        {"scale_x": 1.02, "scale_y": 0.98, "dx": 0},
    ],
    "dead4": [
        {"alpha": 1.0},
        {"alpha": 0.85, "dy": 1},
        {"alpha": 0.7, "dy": 2},
        {"alpha": 0.55, "dy": 3},
    ],
    "dead8": [
        {"alpha": 1.0},
        {"alpha": 0.92, "dy": 0},
        {"alpha": 0.84, "dy": 1},
        {"alpha": 0.76, "dy": 1},
        {"alpha": 0.68, "dy": 2},
        {"alpha": 0.6, "dy": 2},
        {"alpha": 0.5, "dy": 3},
        {"alpha": 0.42, "dy": 3},
    ],
}


CONFIGS = [
    {
        "base": "enemies/chaser/enemy_chaser_body",
        "idle": ROOT / "src/assets/export/enemies/chaser/enemy_chaser_body_idle_64.png",
        "actions": TMP / "enemy_chaser_body_actions_keyed.png",
        "columns": 3,
        "size": 64,
        "outputs": [
            ("idle_strip4.png", "idle", None, "idle4"),
            ("move_strip6.png", "move", 0, "move6"),
            ("hit_strip2.png", "hit", 1, "hit2"),
            ("dead_strip4.png", "dead", 2, "dead4"),
        ],
    },
    {
        "base": "enemies/shooter/enemy_shooter_body",
        "idle": ROOT / "src/assets/export/enemies/shooter/enemy_shooter_body_idle_64.png",
        "actions": TMP / "enemy_shooter_body_actions_keyed.png",
        "columns": 3,
        "size": 64,
        "outputs": [
            ("idle_strip4.png", "idle", None, "idle4"),
            ("move_strip6.png", "move", 0, "move6"),
            ("tell_strip4.png", "tell", 1, "tell4"),
            ("dead_strip4.png", "dead", 2, "dead4"),
        ],
    },
    {
        "base": "enemies/tank/enemy_tank_body",
        "idle": ROOT / "src/assets/export/enemies/tank/enemy_tank_body_idle_64.png",
        "actions": TMP / "enemy_tank_body_actions_keyed.png",
        "columns": 3,
        "size": 64,
        "outputs": [
            ("idle_strip4.png", "idle", None, "idle4"),
            ("move_strip6.png", "move", 0, "move6"),
            ("hit_strip2.png", "hit", 1, "hit2"),
            ("dead_strip4.png", "dead", 2, "dead4"),
        ],
    },
    {
        "base": "enemies/swarm/enemy_swarm_body",
        "idle": ROOT / "src/assets/export/enemies/swarm/enemy_swarm_body_idle_48.png",
        "actions": TMP / "enemy_swarm_body_actions_keyed.png",
        "columns": 2,
        "size": 48,
        "outputs": [
            ("idle_strip4.png", "idle", None, "idle4"),
            ("move_strip6.png", "move", 0, "move6"),
            ("dead_strip4.png", "dead", 1, "dead4"),
        ],
    },
    {
        "base": "bosses/main/boss_main_body",
        "idle": ROOT / "src/assets/export/bosses/main/boss_main_body_idle_128.png",
        "actions": TMP / "boss_main_body_actions_keyed.png",
        "columns": 3,
        "size": 128,
        "outputs": [
            ("idle_strip6.png", "idle", None, "idle6"),
            ("tell_strip4.png", "tell", 0, "tell4"),
            ("dash_strip6.png", "dash", 1, "dash6"),
            ("dead_strip8.png", "dead", 2, "dead8"),
        ],
    },
]


def build() -> None:
    for config in CONFIGS:
        idle = fit_to_frame(Image.open(config["idle"]), config["size"], 0.92)
        actions = Image.open(config["actions"]).convert("RGBA")
        for suffix, _animation, panel_index, pattern_name in config["outputs"]:
            source = idle
            if panel_index is not None:
                panel = crop_panel(actions, int(panel_index), int(config["columns"]))
                ratio = 0.92 if "dead" not in suffix else 0.95
                source = fit_to_frame(panel, int(config["size"]), ratio)
            strip = make_strip(source, PATTERNS[pattern_name])
            save_png(strip, f"{config['base']}_{suffix}")


if __name__ == "__main__":
    build()
