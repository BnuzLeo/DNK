from __future__ import annotations

import math
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

from PIL import Image


@dataclass
class Transform:
    x: float = 0.0
    y: float = 0.0
    angle: float = 0.0
    scale_x: float = 1.0
    scale_y: float = 1.0


def _float(node: ET.Element, name: str, default: float) -> float:
    value = node.attrib.get(name)
    return default if value is None else float(value)


def _int(node: ET.Element, name: str, default: int = 0) -> int:
    value = node.attrib.get(name)
    return default if value is None else int(value)


def _compose(parent: Transform, child: Transform) -> Transform:
    angle = math.radians(parent.angle)
    lx = child.x * parent.scale_x
    ly = child.y * parent.scale_y
    ca = math.cos(angle)
    sa = math.sin(angle)
    return Transform(
        parent.x + lx * ca - ly * sa,
        parent.y + lx * sa + ly * ca,
        parent.angle + child.angle,
        parent.scale_x * child.scale_x,
        parent.scale_y * child.scale_y,
    )


def _object_transform(node: ET.Element) -> Transform:
    return Transform(
        _float(node, "x", 0.0),
        _float(node, "y", 0.0),
        _float(node, "angle", 0.0),
        _float(node, "scale_x", 1.0),
        _float(node, "scale_y", 1.0),
    )


def _load_scml(scml_path: Path) -> tuple[dict, dict]:
    root = ET.parse(scml_path).getroot()
    files: dict[tuple[int, int], dict] = {}
    for folder in root.findall("folder"):
        folder_id = _int(folder, "id")
        for file_node in folder.findall("file"):
            file_id = _int(file_node, "id")
            files[(folder_id, file_id)] = {
                "name": file_node.attrib["name"],
                "width": _int(file_node, "width"),
                "height": _int(file_node, "height"),
                "pivot_x": _float(file_node, "pivot_x", 0.0),
                "pivot_y": _float(file_node, "pivot_y", 1.0),
            }

    entity = root.find("entity")
    if entity is None:
        raise RuntimeError("SCML has no entity")

    animations = {}
    for animation in entity.findall("animation"):
        name = animation.attrib["name"].lower()
        timelines = {}
        for timeline in animation.findall("timeline"):
            timeline_id = _int(timeline, "id")
            keys = []
            by_id = {}
            for key in timeline.findall("key"):
                key_id = _int(key, "id")
                child = key.find("bone")
                if child is None:
                    child = key.find("object")
                if child is None:
                    continue
                entry = {
                    "id": key_id,
                    "time": _int(key, "time", 0),
                    "spin": _int(key, "spin", 1),
                    "node": child,
                }
                keys.append(entry)
                by_id[key_id] = entry
            keys.sort(key=lambda item: item["time"])
            timelines[timeline_id] = {"keys": keys, "by_id": by_id}

        mainline_keys = []
        mainline = animation.find("mainline")
        if mainline is None:
            continue
        for key in mainline.findall("key"):
            bone_refs = [_ref_to_dict(ref) for ref in key.findall("bone_ref")]
            object_refs = [_ref_to_dict(ref) for ref in key.findall("object_ref")]
            mainline_keys.append(
                {
                    "id": _int(key, "id"),
                    "time": _int(key, "time", 0),
                    "bones": bone_refs,
                    "objects": object_refs,
                }
            )
        animations[name] = {
            "length": _int(animation, "length", 1000),
            "timelines": timelines,
            "mainline_keys": mainline_keys,
        }
    return files, animations


def _mainline_key_at(animation: dict, sample_time: int) -> dict:
    current = animation["mainline_keys"][0]
    for key in animation["mainline_keys"]:
        if key["time"] <= sample_time:
            current = key
        else:
            break
    return current


def _angle_lerp(a: float, b: float, ratio: float, spin: int) -> float:
    delta = b - a
    if spin > 0 and delta < 0.0:
        delta += 360.0
    elif spin < 0 and delta > 0.0:
        delta -= 360.0
    elif spin == 0:
        delta = 0.0
    return a + delta * ratio


def _timeline_node_at(timeline: dict, sample_time: int, length: int) -> ET.Element:
    keys = timeline["keys"]
    if not keys:
        raise RuntimeError("empty timeline")
    current = keys[0]
    next_key = None
    for index, key in enumerate(keys):
        if key["time"] <= sample_time:
            current = key
            next_key = keys[index + 1] if index + 1 < len(keys) else None
        else:
            next_key = key
            break
    if next_key is None:
        if len(keys) <= 1:
            return current["node"]
        next_key = keys[0]
        next_time = length
    else:
        next_time = next_key["time"]

    current_time = current["time"]
    span = max(1, next_time - current_time)
    ratio = clamp((sample_time - current_time) / span, 0.0, 1.0)
    a = current["node"]
    b = next_key["node"]
    sampled = ET.Element(a.tag, a.attrib)
    sampled.set("x", str(lerp(_float(a, "x", 0.0), _float(b, "x", 0.0), ratio)))
    sampled.set("y", str(lerp(_float(a, "y", 0.0), _float(b, "y", 0.0), ratio)))
    sampled.set("angle", str(_angle_lerp(_float(a, "angle", 0.0), _float(b, "angle", 0.0), ratio, current["spin"])))
    sampled.set("scale_x", str(lerp(_float(a, "scale_x", 1.0), _float(b, "scale_x", 1.0), ratio)))
    sampled.set("scale_y", str(lerp(_float(a, "scale_y", 1.0), _float(b, "scale_y", 1.0), ratio)))
    if a.tag == "object":
        sampled.set("folder", a.attrib.get("folder", "0"))
        sampled.set("file", a.attrib.get("file", "0"))
    return sampled


def lerp(a: float, b: float, ratio: float) -> float:
    return a + (b - a) * ratio


def clamp(value: float, min_value: float, max_value: float) -> float:
    return max(min_value, min(max_value, value))


def _ref_to_dict(ref: ET.Element) -> dict:
    data = {
        "id": _int(ref, "id"),
        "timeline": _int(ref, "timeline"),
        "key": _int(ref, "key"),
        "z_index": _int(ref, "z_index", 0),
    }
    if "parent" in ref.attrib:
        data["parent"] = _int(ref, "parent")
    return data


def _render_frame(
    base_dir: Path,
    files: dict,
    animation: dict,
    sample_time: int,
    frame_size: int,
    output_scale: float,
) -> Image.Image:
    mainline_key = _mainline_key_at(animation, sample_time)
    timelines = animation["timelines"]
    bone_refs = {ref["id"]: ref for ref in mainline_key["bones"]}
    bone_world: dict[int, Transform] = {}

    def bone_transform(ref_id: int) -> Transform:
        if ref_id in bone_world:
            return bone_world[ref_id]
        ref = bone_refs[ref_id]
        node = _timeline_node_at(timelines[ref["timeline"]], sample_time, animation["length"])
        local = _object_transform(node)
        if "parent" in ref:
            world = _compose(bone_transform(ref["parent"]), local)
        else:
            world = local
        bone_world[ref_id] = world
        return world

    for ref_id in bone_refs.keys():
        bone_transform(ref_id)

    canvas_size = 768
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    center = canvas_size // 2
    draw_items = sorted(mainline_key["objects"], key=lambda item: item.get("z_index", 0))
    for ref in draw_items:
        node = _timeline_node_at(timelines[ref["timeline"]], sample_time, animation["length"])
        folder_id = _int(node, "folder")
        file_id = _int(node, "file")
        file_info = files[(folder_id, file_id)]
        local = _object_transform(node)
        world = _compose(bone_transform(ref["parent"]), local) if "parent" in ref else local
        image = Image.open(base_dir / file_info["name"]).convert("RGBA")
        sx = abs(world.scale_x) * output_scale
        sy = abs(world.scale_y) * output_scale
        scaled_size = (max(1, round(image.width * sx)), max(1, round(image.height * sy)))
        image = image.resize(scaled_size, Image.Resampling.LANCZOS)

        pivot_x = file_info["pivot_x"] * scaled_size[0]
        pivot_y = (1.0 - file_info["pivot_y"]) * scaled_size[1]
        layer_size = max(scaled_size) * 4
        layer = Image.new("RGBA", (layer_size, layer_size), (0, 0, 0, 0))
        layer_center = layer_size / 2.0
        layer.alpha_composite(image, (round(layer_center - pivot_x), round(layer_center - pivot_y)))
        rotated = layer.rotate(-world.angle, resample=Image.Resampling.BICUBIC, center=(layer_center, layer_center))
        x = center + world.x * output_scale - layer_center
        y = center - world.y * output_scale - layer_center
        canvas.alpha_composite(rotated, (round(x), round(y)))

    bbox = canvas.getbbox()
    if bbox is None:
        return Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    cropped = canvas.crop(bbox)
    result = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
    result.alpha_composite(cropped, ((frame_size - cropped.width) // 2, (frame_size - cropped.height) // 2))
    return result


def bake(scml_path: Path, output_dir: Path) -> None:
    files, animations = _load_scml(scml_path)
    base_dir = scml_path.parent
    output_dir.mkdir(parents=True, exist_ok=True)
    mapping = {
        "idle": ("enemy_shooter_archer_idle_strip", 4),
        "walk": ("enemy_shooter_archer_walk_strip", 8),
        "shoot": ("enemy_shooter_archer_shoot_strip", 8),
        "death": ("enemy_shooter_archer_death_strip", 8),
    }
    frame_size = 128
    output_scale = 0.32
    for scml_name, info in mapping.items():
        output_name, frame_count = info
        animation = animations[scml_name]
        sample_times = [round(index * animation["length"] / frame_count) for index in range(frame_count)]
        frames = [
            _render_frame(base_dir, files, animation, sample_time, frame_size, output_scale)
            for sample_time in sample_times
        ]
        strip = Image.new("RGBA", (frame_size * len(frames), frame_size), (0, 0, 0, 0))
        for index, frame in enumerate(frames):
            strip.alpha_composite(frame, (index * frame_size, 0))
        strip.save(output_dir / f"{output_name}{len(frames)}.png")
        print(f"wrote {output_dir / f'{output_name}{len(frames)}.png'}")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bake_spriter_scml.py <input.scml> <output_dir>")
        return 2
    bake(Path(sys.argv[1]), Path(sys.argv[2]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
