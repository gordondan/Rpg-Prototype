# Shops

## Overview

Shops are merchant inventories that define which items an NPC sells. Each shop is linked to a specific NPC on the overworld map. There is currently 1 shop: `village_merchant`, which sells 4 of the 5 available items (all except the elixir).

| Shop ID | Name | Items Sold |
|---------|------|------------|
| `village_merchant` | Village Merchant | minor_healing_potion, healing_potion, mega_potion, revive |

## Data Schema

Shops are stored in `data/shops/shops.json` as a flat dictionary keyed by shop ID.

```
{
  "<shop_id>": {
    "name": string,       -- Display name shown in the shop UI title
    "greeting": string,   -- Text displayed when the shop opens
    "items": [string]     -- Array of item IDs (must exist in items.json)
  }
}
```

The `items` array controls which items appear in the shop UI and in what order. Item prices and descriptions are read from `items.json` at display time -- they are not duplicated in the shop definition.

## Code Paths

### Godot (game engine)

| File | Role |
|------|------|
| `scripts/autoload/data_loader.gd` | Loads `shops.json` at startup via `_load_json_into()`. Provides `get_shop_data(shop_id) -> Dictionary`. |
| `scripts/overworld/npc.gd` | NPCs with `is_merchant = true` and a `shop_id` property open the shop UI on interaction instead of dialogue. The `_open_shop()` method loads `shop.gd`, creates a CanvasLayer node, sets its `shop_id`, and adds it to the scene. |
| `scripts/overworld/map_builder.gd` | Creates merchant NPCs with `_create_npc()`, passing `{"is_merchant": true, "shop_id": "village_merchant"}` in the config dictionary. |
| `scripts/ui/shop.gd` | Shop UI (CanvasLayer). Reads shop data to get the item list, then reads each item's data for name/description/price. Handles buy transactions: validates gold, decrements `GameManager.gold`, calls `GameManager.add_item()`. Emits `shop_closed` signal on close. |

### Web (asset browser)

| File | Role |
|------|------|
| `web/backend/routers/shops.py` | REST API: `GET /api/shops/` (list all), `PUT /api/shops/{shop_id}` (update). |
| `web/backend/services/data_service.py` | `get_all_shops()`, `update_shop()` -- reads/writes `shops.json`. |
| `web/frontend/src/components/shops/` | `ShopsList.tsx` (browse), `ShopForm.tsx` (edit). |

## How to Add/Modify

**Add a new shop:**

1. Add a new entry to `data/shops/shops.json` with a unique snake_case key.
2. Set `name`, `greeting`, and `items` (array of item IDs that exist in `items.json`).
3. Create a merchant NPC on the map in `map_builder.gd` using `_create_npc()` with `{"is_merchant": true, "shop_id": "<shop_id>"}`.

**Change what a shop sells:**

Edit the `items` array in the shop's entry in `shops.json`. Add or remove item ID strings. The order of the array determines display order in the UI.

**Modify via web browser:**

Use the asset browser (`PUT /api/shops/{shop_id}`) or the ShopForm UI to edit fields. Changes write directly to `shops.json`.

## Runtime Behavior

1. **Startup:** `DataLoader._ready()` loads `shops.json` into `_shops` dictionary.
2. **NPC interaction:** When the player interacts with an NPC that has `is_merchant = true` and a non-empty `shop_id`, the NPC calls `_open_shop()` instead of starting dialogue. This dynamically loads `shop.gd`, creates a CanvasLayer, sets the `shop_id` property, and adds it to the current scene.
3. **Shop display:** `shop.gd._build_ui()` calls `DataLoader.get_shop_data(shop_id)` to get the shop definition, then iterates the `items` array, calling `DataLoader.get_item_data()` for each to build item rows with name, description, price, and a "Buy" button. The player's current gold is shown in the header.
4. **Buying:** On pressing "Buy", the shop checks `GameManager.gold >= price`. If sufficient, it decrements gold, calls `GameManager.add_item(item_id)`, updates the gold display, and shows a success message. If insufficient, it shows "Not enough gold!" in red.
5. **Closing:** Pressing "Close" or Escape calls `_close()`, which restores `GameState.OVERWORLD`, emits `shop_closed`, and frees the shop node.
