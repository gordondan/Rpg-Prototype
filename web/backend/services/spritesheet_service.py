from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path

from backend.config import settings


@dataclass
class SpriteSheetMeta:
    frame_width: int = 64
    frame_height: int = 64
    columns: int = 1
    rows: int = 1
    frame_count: int = 1
    fps: float = 8.0
    loop: bool = True
    animation_type: str = "sprite2d"  # "sprite2d" or "player"


class SpriteSheetService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path

    def generate_resources(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate Godot .tres resource file for a sprite sheet animation.

        Returns the relative path to the generated .tres file.
        """
        anim_dir = (
            self.repo_path
            / "assets"
            / "sprites"
            / "creatures"
            / creature_id
            / animation_name
        )
        anim_dir.mkdir(parents=True, exist_ok=True)

        # Save metadata
        meta_path = anim_dir / "metadata.json"
        meta_path.write_text(json.dumps(asdict(meta), indent=2) + "\n")

        # Generate .tres
        tres_path = anim_dir / f"{animation_name}.tres"
        if meta.animation_type == "sprite2d":
            content = self._generate_sprite_frames(creature_id, animation_name, meta)
        else:
            content = self._generate_animation(creature_id, animation_name, meta)
        tres_path.write_text(content)

        return str(tres_path.relative_to(self.repo_path))

    def _generate_sprite_frames(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate a SpriteFrames .tres with AtlasTexture regions."""
        sheet_path = f"res://assets/sprites/creatures/{creature_id}/{animation_name}/spritesheet.png"

        lines = []

        sub_resource_count = meta.frame_count
        lines.append(
            f'[gd_resource type="SpriteFrames" load_steps={2 + sub_resource_count} format=3]'
        )
        lines.append("")

        # ExtResource: the sprite sheet texture
        lines.append(f'[ext_resource type="Texture2D" path="{sheet_path}" id="1"]')
        lines.append("")

        # SubResources: one AtlasTexture per frame
        for i in range(meta.frame_count):
            col = i % meta.columns
            row = i // meta.columns
            x = col * meta.frame_width
            y = row * meta.frame_height
            lines.append(
                f'[sub_resource type="AtlasTexture" id="{i + 1}"]'
            )
            lines.append('atlas = ExtResource("1")')
            lines.append(
                f"region = Rect2({x}, {y}, {meta.frame_width}, {meta.frame_height})"
            )
            lines.append("")

        # Main resource: SpriteFrames
        lines.append("[resource]")

        frame_entries = []
        for i in range(meta.frame_count):
            frame_entries.append(
                '{ "texture": SubResource("'
                + str(i + 1)
                + '"), "duration": 1.0 }'
            )
        frames_str = "[" + ", ".join(frame_entries) + "]"

        loop_str = "true" if meta.loop else "false"
        lines.append(
            f'animations = [{{ "name": &"{animation_name}", "speed": {meta.fps:.1f}, "loop": {loop_str}, "frames": {frames_str} }}]'
        )

        return "\n".join(lines) + "\n"

    def _generate_animation(
        self,
        creature_id: str,
        animation_name: str,
        meta: SpriteSheetMeta,
    ) -> str:
        """Generate an Animation .tres with keyframed region_rect tracks."""
        sheet_path = f"res://assets/sprites/creatures/{creature_id}/{animation_name}/spritesheet.png"

        duration = meta.frame_count / meta.fps
        loop_mode = 1 if meta.loop else 0

        lines = []
        lines.append(
            f'[gd_resource type="Animation" load_steps=2 format=3]'
        )
        lines.append("")

        lines.append(f'[ext_resource type="Texture2D" path="{sheet_path}" id="1"]')
        lines.append("")

        lines.append("[resource]")
        lines.append(f'resource_name = "{animation_name}"')
        lines.append(f"length = {duration:.4f}")
        lines.append(f"loop_mode = {loop_mode}")

        lines.append("tracks/0/type = \"value\"")
        lines.append("tracks/0/imported = false")
        lines.append("tracks/0/enabled = true")
        lines.append('tracks/0/path = NodePath("Sprite2D:texture")')
        lines.append("tracks/0/interp = 1")
        lines.append("tracks/0/update_mode = 1")
        lines.append("tracks/0/keys = {")
        lines.append('"times": PackedFloat32Array(0),')
        lines.append('"transitions": PackedFloat32Array(1),')
        lines.append('"values": [ExtResource("1")]')
        lines.append("}")

        times = []
        rects = []
        for i in range(meta.frame_count):
            col = i % meta.columns
            row = i // meta.columns
            x = col * meta.frame_width
            y = row * meta.frame_height
            t = i / meta.fps
            times.append(f"{t:.4f}")
            rects.append(
                f"Rect2({x}, {y}, {meta.frame_width}, {meta.frame_height})"
            )

        lines.append("tracks/1/type = \"value\"")
        lines.append("tracks/1/imported = false")
        lines.append("tracks/1/enabled = true")
        lines.append('tracks/1/path = NodePath("Sprite2D:region_rect")')
        lines.append("tracks/1/interp = 1")
        lines.append("tracks/1/update_mode = 1")
        lines.append("tracks/1/keys = {")
        times_str = ", ".join(times)
        lines.append(f'"times": PackedFloat32Array({times_str}),')
        transitions_str = ", ".join(["1"] * meta.frame_count)
        lines.append(f'"transitions": PackedFloat32Array({transitions_str}),')
        values_str = ", ".join(rects)
        lines.append(f'"values": [{values_str}]')
        lines.append("}")

        return "\n".join(lines) + "\n"

    def list_animations(self, creature_id: str) -> list[dict]:
        """List all animations for a creature by scanning its folder."""
        creature_dir = (
            self.repo_path / "assets" / "sprites" / "creatures" / creature_id
        )
        if not creature_dir.is_dir():
            return []

        animations = []
        for sub in sorted(creature_dir.iterdir()):
            if not sub.is_dir():
                continue
            meta_path = sub / "metadata.json"
            if not meta_path.exists():
                continue
            meta = json.loads(meta_path.read_text())
            animations.append(
                {
                    "name": sub.name,
                    "meta": meta,
                    "has_tres": (sub / f"{sub.name}.tres").exists(),
                    "has_spritesheet": (sub / "spritesheet.png").exists(),
                }
            )
        return animations
