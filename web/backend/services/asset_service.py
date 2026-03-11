from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

from backend.config import settings


@dataclass
class AssetInfo:
    path: str
    filename: str
    category: str
    size_bytes: int
    width: int | None = None
    height: int | None = None
    status: str = "active"
    notes: str = ""


class AssetService:
    GAME_SPRITE_SIZE = 128

    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self.assets_path = self.repo_path / settings.assets_dir

    def _get_metadata(self) -> dict:
        meta_path = self.repo_path / settings.metadata_file
        if meta_path.exists():
            return json.loads(meta_path.read_text())
        return {}

    def _save_metadata(self, metadata: dict) -> None:
        meta_path = self.repo_path / settings.metadata_file
        meta_path.parent.mkdir(parents=True, exist_ok=True)
        meta_path.write_text(json.dumps(metadata, indent=2) + "\n")

    def get_asset_status(self, rel_path: str) -> dict:
        metadata = self._get_metadata()
        return metadata.get(rel_path, {"status": "active", "notes": ""})

    def set_asset_status(self, rel_path: str, status: str, notes: str = "") -> None:
        metadata = self._get_metadata()
        metadata[rel_path] = {"status": status, "notes": notes}
        self._save_metadata(metadata)

    def list_assets(self, category: str | None = None) -> list[AssetInfo]:
        assets = []
        sprite_dirs = {
            "creatures": self.assets_path / "sprites" / "creatures",
            "npcs": self.assets_path / "sprites" / "npcs",
            "tilesets": self.assets_path / "sprites" / "tilesets",
        }
        audio_dir = self.assets_path / "audio"

        metadata = self._get_metadata()

        dirs_to_scan = {}
        if category:
            if category == "audio":
                dirs_to_scan["audio"] = audio_dir
            elif category in sprite_dirs:
                dirs_to_scan[category] = sprite_dirs[category]
        else:
            dirs_to_scan = {**sprite_dirs, "audio": audio_dir}

        for cat, dir_path in dirs_to_scan.items():
            if not dir_path.exists():
                continue
            for f in sorted(dir_path.rglob("*")):
                if f.is_dir() or f.suffix == ".import":
                    continue
                if "/original/" in str(f):
                    continue
                rel = str(f.relative_to(self.repo_path))
                meta = metadata.get(rel, {})
                info = AssetInfo(
                    path=rel,
                    filename=f.name,
                    category=cat,
                    size_bytes=f.stat().st_size,
                    status=meta.get("status", "active"),
                    notes=meta.get("notes", ""),
                )
                if f.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp"):
                    try:
                        with Image.open(f) as img:
                            info.width, info.height = img.size
                    except Exception:
                        pass
                assets.append(info)
        return assets

    def get_thumbnail(self, rel_path: str, max_size: int = 128) -> bytes | None:
        full_path = self.repo_path / rel_path
        if not full_path.exists():
            return None
        try:
            with Image.open(full_path) as img:
                img.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
                from io import BytesIO
                buf = BytesIO()
                img.save(buf, format="PNG")
                return buf.getvalue()
        except Exception:
            return None

    def save_uploaded_file(self, rel_path: str, content: bytes) -> None:
        full_path = self.repo_path / rel_path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        full_path.write_bytes(content)

    def process_sprite(self, rel_path: str, content: bytes) -> None:
        """Save original to original/ subdir, write resized game-ready PNG to rel_path."""
        from io import BytesIO

        full_path = self.repo_path / rel_path
        full_path.parent.mkdir(parents=True, exist_ok=True)

        # Save original
        original_dir = full_path.parent / "original"
        original_dir.mkdir(parents=True, exist_ok=True)
        original_path = original_dir / full_path.name
        original_path.write_bytes(content)

        # Open, convert to RGBA PNG, resize if needed
        with Image.open(BytesIO(content)) as img:
            img = img.convert("RGBA")
            img.thumbnail((self.GAME_SPRITE_SIZE, self.GAME_SPRITE_SIZE), Image.Resampling.LANCZOS)
            buf = BytesIO()
            img.save(buf, format="PNG")
            full_path.write_bytes(buf.getvalue())

    def reprocess_all_sprites(self) -> int:
        """Reprocess all creature sprites: save originals, generate game-ready versions."""
        creatures_dir = self.repo_path / "assets" / "sprites" / "creatures"
        if not creatures_dir.exists():
            return 0
        count = 0
        for f in sorted(creatures_dir.glob("*.png")):
            if f.is_dir():
                continue
            content = f.read_bytes()
            rel_path = str(f.relative_to(self.repo_path))
            self.process_sprite(rel_path, content)
            count += 1
        for ext in ("*.jpg", "*.jpeg", "*.gif"):
            for f in sorted(creatures_dir.glob(ext)):
                if f.is_dir():
                    continue
                content = f.read_bytes()
                png_name = f.stem + ".png"
                rel_path = str((f.parent / png_name).relative_to(self.repo_path))
                self.process_sprite(rel_path, content)
                f.unlink()
                count += 1
        return count

    def delete_asset(self, rel_path: str) -> bool:
        full_path = self.repo_path / rel_path
        if full_path.exists():
            full_path.unlink()
            metadata = self._get_metadata()
            metadata.pop(rel_path, None)
            self._save_metadata(metadata)
            return True
        return False

    def rename_asset(self, old_rel_path: str, new_rel_path: str) -> bool:
        old_path = self.repo_path / old_rel_path
        new_path = self.repo_path / new_rel_path
        if not old_path.exists() or new_path.exists():
            return False
        new_path.parent.mkdir(parents=True, exist_ok=True)
        old_path.rename(new_path)
        metadata = self._get_metadata()
        if old_rel_path in metadata:
            metadata[new_rel_path] = metadata.pop(old_rel_path)
            self._save_metadata(metadata)
        return True

    def get_status_summary(self) -> dict[str, int]:
        metadata = self._get_metadata()
        summary = {"active": 0, "in_development": 0, "deprecated": 0, "unused": 0, "missing_sprites": 0}
        assets = self.list_assets("creatures")
        for a in assets:
            status = metadata.get(a.path, {}).get("status", "active")
            if status in summary:
                summary[status] += 1
        return summary
