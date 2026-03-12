# Creatures Page: Filters & Quick Create

## 1. Data Consolidation

Merge `data/creatures/starters.json` and `data/creatures/wild.json` into a single `data/creatures/creatures.json`. Add a `category` field to each creature (`"starter"`, `"wild"`). Remove the old files. Update the backend service to load from the single file and remove any logic that distinguishes by file source.

## 2. Backend Changes

- Update `data_service.py` to read/write `creatures.json` instead of merging two files.
- Add `POST /api/creatures/` endpoint that creates a new creature with placeholder defaults (auto-generated ID like `new_creature_1`, name "New Creature", category "wild", type "normal", zeroed stats) and returns the new creature.
- Add `DELETE /api/creatures/{creature_id}` endpoint.

## 3. Filter Widget (Frontend)

Below the search input, a collapsible "Filters" section with:
- **Type** — multi-select chips using existing type colors
- **Class** — multi-select chips
- **Category** — toggle: All / Starter / Wild
- **Missing sprites** — checkboxes: "Missing overworld" / "Missing battle"
- **Has evolution** — toggle: All / Yes / No
- **Recruitable** — toggle: All / Yes / No

A "Clear filters" link appears when any filter is active. The creature count updates to reflect filtered results.

## 4. Add Creature Button

A `+` button above the search box. On click: POST to create a new creature with defaults, select it in the list, open it in the detail panel for editing.

## 5. Scope Exclusions

- No drag-and-drop reordering
- No bulk operations
- No creature deletion from the UI (API endpoint only for now)
