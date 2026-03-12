import json
from pathlib import Path

from backend.models.schemas import Creature, Move, Item, GameMap, Shop

REPO = Path(__file__).parent.parent.parent  # monster-game root


def test_creature_schema():
    data = json.loads((REPO / "data/characters/characters.json").read_text())
    for cid, cdata in data.items():
        creature = Creature.model_validate(cdata)
        assert creature.name
        assert cdata["category"] in ("starter", "wild", "npc")


def test_move_schema():
    data = json.loads((REPO / "data/moves/moves.json").read_text())
    for mid, mdata in data.items():
        move = Move.model_validate(mdata)
        assert move.name


def test_item_schema():
    data = json.loads((REPO / "data/items/items.json").read_text())
    for iid, idata in data.items():
        item = Item.model_validate(idata)
        assert item.price >= 0


def test_map_schema():
    data = json.loads((REPO / "data/maps/route_1.json").read_text())
    game_map = GameMap.model_validate(data)
    assert len(game_map.encounters) > 0


def test_shop_schema():
    data = json.loads((REPO / "data/shops/shops.json").read_text())
    for sid, sdata in data.items():
        shop = Shop.model_validate(sdata)
        assert len(shop.items) > 0
