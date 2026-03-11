import json
from pathlib import Path

from backend.config import settings
from backend.models.schemas import Creature, Move, Item, GameMap, Shop


class DataService:
    def __init__(self, repo_path: Path | None = None):
        self.repo_path = repo_path or settings.repo_path
        self.data_path = self.repo_path / settings.data_dir

    def _read_json(self, path: Path) -> dict:
        return json.loads(path.read_text())

    def _write_json(self, path: Path, data: dict) -> None:
        path.write_text(json.dumps(data, indent=2) + "\n")

    # --- Creatures ---

    def get_all_creatures(self) -> dict[str, dict]:
        creatures = {}
        starters_path = self.data_path / "creatures" / "starters.json"
        wild_path = self.data_path / "creatures" / "wild.json"
        if starters_path.exists():
            creatures.update(self._read_json(starters_path))
        if wild_path.exists():
            creatures.update(self._read_json(wild_path))
        return creatures

    def get_creature(self, creature_id: str) -> dict | None:
        all_creatures = self.get_all_creatures()
        return all_creatures.get(creature_id)

    def _find_creature_file(self, creature_id: str) -> Path | None:
        # Check wild.json first since get_all_creatures gives it priority
        for filename in ["wild.json", "starters.json"]:
            path = self.data_path / "creatures" / filename
            if path.exists():
                data = self._read_json(path)
                if creature_id in data:
                    return path
        return None

    def update_creature(self, creature_id: str, creature_data: dict) -> bool:
        path = self._find_creature_file(creature_id)
        if not path:
            return False
        data = self._read_json(path)
        data[creature_id] = creature_data
        self._write_json(path, data)
        return True

    # --- Moves ---

    def get_all_moves(self) -> dict[str, dict]:
        path = self.data_path / "moves" / "moves.json"
        return self._read_json(path) if path.exists() else {}

    def get_move(self, move_id: str) -> dict | None:
        return self.get_all_moves().get(move_id)

    def update_move(self, move_id: str, move_data: dict) -> bool:
        path = self.data_path / "moves" / "moves.json"
        data = self._read_json(path)
        data[move_id] = move_data
        self._write_json(path, data)
        return True

    # --- Items ---

    def get_all_items(self) -> dict[str, dict]:
        path = self.data_path / "items" / "items.json"
        return self._read_json(path) if path.exists() else {}

    def update_item(self, item_id: str, item_data: dict) -> bool:
        path = self.data_path / "items" / "items.json"
        data = self._read_json(path)
        data[item_id] = item_data
        self._write_json(path, data)
        return True

    # --- Maps ---

    def get_all_maps(self) -> dict[str, dict]:
        maps = {}
        maps_dir = self.data_path / "maps"
        if maps_dir.exists():
            for f in maps_dir.glob("*.json"):
                maps[f.stem] = self._read_json(f)
        return maps

    def update_map(self, map_id: str, map_data: dict) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if not path.exists():
            return False
        self._write_json(path, map_data)
        return True

    # --- Shops ---

    def get_all_shops(self) -> dict[str, dict]:
        path = self.data_path / "shops" / "shops.json"
        return self._read_json(path) if path.exists() else {}

    def update_shop(self, shop_id: str, shop_data: dict) -> bool:
        path = self.data_path / "shops" / "shops.json"
        data = self._read_json(path)
        data[shop_id] = shop_data
        self._write_json(path, data)
        return True

    def get_changed_files(self) -> list[str]:
        changed = []
        for pattern in ["creatures/*.json", "moves/*.json", "items/*.json", "maps/*.json", "shops/*.json"]:
            for f in (self.data_path).glob(pattern):
                changed.append(str(f.relative_to(self.repo_path)))
        return changed

    # --- Map Create & Delete ---

    def create_map(self, map_id: str, map_data: dict) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if path.exists():
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        self._write_json(path, map_data)
        return True

    def delete_map(self, map_id: str) -> bool:
        path = self.data_path / "maps" / f"{map_id}.json"
        if not path.exists():
            return False
        path.unlink()
        return True

    # --- Quests ---

    def get_all_quests(self) -> dict[str, dict]:
        quests = {}
        quests_dir = self.data_path / "quests"
        if quests_dir.exists():
            for f in quests_dir.glob("*.json"):
                quests[f.stem] = self._read_json(f)
        return quests

    def get_quest(self, quest_id: str) -> dict | None:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if path.exists():
            return self._read_json(path)
        return None

    def create_quest(self, quest_id: str, quest_data: dict) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if path.exists():
            return False
        path.parent.mkdir(parents=True, exist_ok=True)
        self._write_json(path, quest_data)
        return True

    def update_quest(self, quest_id: str, quest_data: dict) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if not path.exists():
            return False
        self._write_json(path, quest_data)
        return True

    def delete_quest(self, quest_id: str) -> bool:
        path = self.data_path / "quests" / f"{quest_id}.json"
        if not path.exists():
            return False
        path.unlink()
        return True
