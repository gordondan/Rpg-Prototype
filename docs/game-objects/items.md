# Items

## Overview

Items are consumable objects the player carries in their inventory and uses on party creatures. There are currently 5 items, all focused on healing or revival. Items are purchased from shops using gold and consumed on use.

| Item ID | Name | Effect | Price |
|---------|------|--------|-------|
| `minor_healing_potion` | Minor Potion | Heals 25 HP | 15g |
| `healing_potion` | Healing Potion | Heals 50 HP | 30g |
| `mega_potion` | Mega Potion | Heals 150 HP | 75g |
| `elixir` | Elixir | Full HP restore | 200g |
| `revive` | Revive Scroll | Revives fainted creature at 50% HP | 150g |

## Data Schema

Items are stored in `data/items/items.json` as a flat dictionary keyed by item ID.

```
{
  "<item_id>": {
    "name": string,          -- Display name
    "description": string,   -- Tooltip/UI description
    "price": int,            -- Cost in gold
    "effect": {
      "type": string,        -- "heal_hp" | "full_heal" | "revive"
      "amount": int           -- HP amount (only for "heal_hp"; omitted for others)
    }
  }
}
```

**Effect types:**

- `heal_hp` -- Restores `amount` HP, capped at max HP. Cannot target fainted creatures.
- `full_heal` -- Sets HP to max. Cannot target fainted creatures.
- `revive` -- Revives a fainted creature at `max_hp / 2`. Only targets fainted creatures.

## Code Paths

### Godot (game engine)

| File | Role |
|------|------|
| `scripts/autoload/data_loader.gd` | Loads `items.json` at startup via `_load_json_into()`. Provides `get_item_data(item_id) -> Dictionary`. |
| `scripts/autoload/game_manager.gd` | Owns `inventory: Dictionary` (`{item_id: quantity}`). Methods: `add_item()`, `remove_item()`, `has_item()`, `use_item()`. Inventory is included in save/load. |
| `scripts/ui/inventory.gd` | Inventory screen (CanvasLayer). Lists owned items with quantities, "Use" button per item, creature selector overlay for targeting. |
| `scripts/ui/shop.gd` | Shop UI reads item data to display prices and descriptions. Buying calls `GameManager.add_item()`. |

### Web (asset browser)

| File | Role |
|------|------|
| `web/backend/routers/items.py` | REST API: `GET /api/items/` (list all), `PUT /api/items/{item_id}` (update). |
| `web/backend/services/data_service.py` | `get_all_items()`, `update_item()` -- reads/writes `items.json`. |
| `web/frontend/src/components/items/` | `ItemsList.tsx` (browse), `ItemForm.tsx` (edit). |

## How to Add/Modify

**Add a new item:**

1. Add a new entry to `data/items/items.json` with a unique snake_case key.
2. Set `name`, `description`, `price`, and `effect` fields.
3. If the effect type is `heal_hp`, include `amount`. For `full_heal` and `revive`, no amount is needed.
4. To make the item purchasable, add its ID to a shop's `items` array in `data/shops/shops.json`.

**Add a new effect type:**

1. Add a new branch to the `match effect.get("type", "")` block in `GameManager.use_item()`.
2. Add corresponding targeting logic (valid/invalid) to the `match effect_type` block in `inventory.gd` `_show_creature_selector()`.

**Modify via web browser:**

Use the asset browser (`PUT /api/items/{item_id}`) or the ItemForm UI to edit fields. Changes write directly to `items.json`.

## Runtime Behavior

1. **Startup:** `DataLoader._ready()` loads `items.json` into `_items` dictionary.
2. **Shopping:** Player interacts with a merchant NPC. Shop UI reads item data via `DataLoader.get_item_data()`, displays price. On buy, `GameManager.gold` is decremented and `GameManager.add_item()` adds 1 to inventory.
3. **Using items:** Player opens inventory (sets `GameState.MENU`). Selecting "Use" shows a creature selector filtered by effect type (heal/revive targeting rules). On creature selection, `GameManager.use_item()` applies the effect, calls `remove_item()` to decrement quantity (erasing the key if quantity reaches 0), and the UI rebuilds.
4. **Quest rewards:** `GameManager` can grant items via `add_item(item_reward["item_id"], quantity)` when completing quests.
5. **Save/Load:** The `inventory` dictionary is serialized into save data and restored on load.
