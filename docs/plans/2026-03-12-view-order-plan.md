# View Order (Click-to-Front) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** When a creature/NPC is clicked in the editor list, move it to the front of the list and scroll to the top — persisted via a separate `view_order.json` file.

**Architecture:** A new `data/characters/view_order.json` file stores an ordered array of creature IDs. Two new backend endpoints manage reading and reordering. The frontend fetches the order on mount, sorts its list by it, and updates the order + scrolls to top on selection.

**Tech Stack:** Python/FastAPI (backend), React/TypeScript (frontend), JSON file storage

---

### Task 1: Add view order methods to DataService

**Files:**
- Modify: `web/backend/services/data_service.py:19-56`

**Step 1: Add the three new methods to DataService**

Add these methods after the existing creature methods (after line 56):

```python
# --- View Order ---

def _view_order_path(self) -> Path:
    return self.data_path / "characters" / "view_order.json"

def get_view_order(self) -> list[str]:
    """Return the view order list, auto-generating from characters.json keys if missing."""
    path = self._view_order_path()
    if path.exists():
        order = json.loads(path.read_text())
        # Sync: add any missing creature IDs at the end
        all_ids = set(self.get_all_creatures().keys())
        ordered_set = set(order)
        # Remove IDs that no longer exist
        order = [cid for cid in order if cid in all_ids]
        # Append any new IDs not yet in the order
        for cid in all_ids - ordered_set:
            order.append(cid)
        return order
    # No file yet — generate from characters.json key order
    return list(self.get_all_creatures().keys())

def select_view_order(self, creature_id: str) -> list[str]:
    """Move creature_id to position 0 in the view order and persist."""
    order = self.get_view_order()
    if creature_id in order:
        order.remove(creature_id)
    order.insert(0, creature_id)
    self._view_order_path().write_text(json.dumps(order, indent=2) + "\n")
    return order

def add_to_view_order(self, creature_id: str) -> None:
    """Prepend a new creature ID to the view order."""
    order = self.get_view_order()
    if creature_id not in order:
        order.insert(0, creature_id)
        self._view_order_path().write_text(json.dumps(order, indent=2) + "\n")

def remove_from_view_order(self, creature_id: str) -> None:
    """Remove a creature ID from the view order."""
    path = self._view_order_path()
    if path.exists():
        order = json.loads(path.read_text())
        if creature_id in order:
            order.remove(creature_id)
            path.write_text(json.dumps(order, indent=2) + "\n")
```

**Step 2: Commit**

```bash
git add web/backend/services/data_service.py
git commit -m "feat: add view order methods to DataService"
```

---

### Task 2: Add view order endpoints to creatures router

**Files:**
- Modify: `web/backend/routers/creatures.py`

**Step 1: Add the two new endpoints**

Add after the existing `list_creatures` endpoint (after line 25):

```python
@router.get("/view-order")
def get_view_order():
    return data_svc.get_view_order()


@router.put("/view-order/{creature_id}")
def select_view_order(creature_id: str):
    if not data_svc.get_creature(creature_id):
        raise HTTPException(404, f"Creature '{creature_id}' not found")
    order = data_svc.select_view_order(creature_id)
    return order
```

**Important:** These endpoints MUST be placed **before** the `/{creature_id}` route (line 28), otherwise FastAPI will match `view-order` as a `creature_id` parameter.

**Step 2: Update create endpoint to add to view order**

In `create_creature` (line 44), after `data_svc.create_creature(creature_id, creature_data)` add:

```python
    data_svc.add_to_view_order(creature_id)
```

**Step 3: Update delete endpoint to remove from view order**

In `delete_creature` (line 72), after the successful delete check, add:

```python
    data_svc.remove_from_view_order(creature_id)
```

**Step 4: Commit**

```bash
git add web/backend/routers/creatures.py
git commit -m "feat: add view order endpoints and sync on create/delete"
```

---

### Task 3: Add view order API methods to frontend client

**Files:**
- Modify: `web/frontend/src/api/creatures.ts:64-70`

**Step 1: Add two new methods to creaturesApi**

Add these to the `creaturesApi` object:

```typescript
export const creaturesApi = {
  list: () => get<Record<string, Creature>>('/creatures/'),
  getOne: (id: string) => get<Creature>(`/creatures/${id}`),
  update: (id: string, data: Creature) => put<Creature>(`/creatures/${id}`, data),
  create: (category?: string) => post<{ status: string; creature_id: string }>(`/creatures/${category ? `?category=${category}` : ''}`),
  delete: (id: string) => httpDelete<{ status: string }>(`/creatures/${id}`),
  getViewOrder: () => get<string[]>('/creatures/view-order'),
  selectViewOrder: (id: string) => put<string[]>(`/creatures/view-order/${id}`, {}),
}
```

**Step 2: Commit**

```bash
git add web/frontend/src/api/creatures.ts
git commit -m "feat: add view order API methods to creatures client"
```

---

### Task 4: Update CreatureList to use view order and scroll to top

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureList.tsx`

**Step 1: Add view order state and ref**

Update the imports (line 1):

```typescript
import { useState, useMemo, useEffect, useRef } from 'react'
```

Inside the component, add state for the view order and a ref for the scroll area:

```typescript
const [viewOrder, setViewOrder] = useState<string[]>([])
const scrollRef = useRef<HTMLDivElement>(null)
```

**Step 2: Fetch view order on mount**

Add a `useEffect` to load the view order:

```typescript
useEffect(() => {
  creaturesApi.getViewOrder().then(setViewOrder).catch(() => {})
}, [])
```

**Step 3: Sort filtered entries by view order**

In the `filtered` useMemo (line 73), after all filters have been applied, before the `return entries`, add sorting:

```typescript
    // Sort by view order
    if (viewOrder.length > 0) {
      const orderMap = new Map(viewOrder.map((id, i) => [id, i]))
      entries.sort((a, b) => (orderMap.get(a[0]) ?? Infinity) - (orderMap.get(b[0]) ?? Infinity))
    }

    return entries
```

Add `viewOrder` to the useMemo dependency array:

```typescript
  }, [creatures, search, filters, viewOrder])
```

**Step 4: Update onSelect to reorder and scroll**

Replace the `onClick` handler on the list button (line 381). Change:

```tsx
onClick={() => onSelect(id)}
```

To a new handler that also updates view order. Add this function inside the component:

```typescript
const handleSelect = async (id: string) => {
  onSelect(id)
  // Move to front of view order
  try {
    const newOrder = await creaturesApi.selectViewOrder(id)
    setViewOrder(newOrder)
  } catch {
    // Optimistic: move to front locally even if API fails
    setViewOrder(prev => [id, ...prev.filter(x => x !== id)])
  }
  // Scroll list to top
  scrollRef.current?.scrollTo({ top: 0 })
}
```

Then update the button onClick:

```tsx
onClick={() => handleSelect(id)}
```

**Step 5: Attach ref to ScrollArea's viewport**

The `ScrollArea` component wraps a `Viewport` internally. We need the ref on the container div inside ScrollArea. Change the ScrollArea (line 376) to:

```tsx
<ScrollArea className="flex-1">
  <div ref={scrollRef} className="flex flex-col gap-0.5 p-1.5">
```

Wait — the `scrollRef` needs to be on the scrollable viewport, not the inner div. Since the `ScrollArea` component uses `ScrollAreaPrimitive.Viewport` internally and that's the element that scrolls, we need a different approach. Instead, use a wrapper ref and query the viewport:

Replace the scrollRef approach with:

```typescript
const listRef = useRef<HTMLDivElement>(null)
```

And the scroll call:

```typescript
// Scroll list to top
const viewport = listRef.current?.querySelector('[data-slot="scroll-area-viewport"]')
viewport?.scrollTo({ top: 0 })
```

And wrap the ScrollArea:

```tsx
<div ref={listRef} className="flex-1">
  <ScrollArea className="h-full">
    <div className="flex flex-col gap-0.5 p-1.5">
```

Close the extra div after `</ScrollArea>`:

```tsx
    </ScrollArea>
  </div>
```

**Step 6: Update handleCreate to refresh view order**

In the existing `handleCreate` function, after `onRefresh?.()`, add:

```typescript
      creaturesApi.getViewOrder().then(setViewOrder).catch(() => {})
```

**Step 7: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureList.tsx
git commit -m "feat: sort creature list by view order and scroll to top on select"
```

---

### Task 5: Manual testing

**Step 1: Start the dev server**

```bash
cd web && source .venv/bin/activate && python -m uvicorn backend.main:app --reload &
cd web/frontend && npm run dev &
```

**Step 2: Test the flow**

1. Open the Creatures page in the browser
2. Scroll down and click a creature near the bottom
3. Verify: the creature moves to the top of the list, the list scrolls to the top, the detail editor shows on the right
4. Refresh the page — verify the reordered creature is still at the top
5. Switch to NPC tab and repeat
6. Create a new creature — verify it appears at the top
7. Delete a creature — verify it's removed from the list

**Step 3: Verify the data file**

```bash
cat data/characters/view_order.json
```

Expected: a JSON array of creature IDs with the most recently clicked at position 0.

**Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address manual testing feedback"
```
