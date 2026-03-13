# NPC Hostile Flag & Roster Editor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add hostile flag and creature roster (lead + party + reserves) to NPC data and make them editable in the web app.

**Architecture:** Add optional fields to the existing Creature schema/type (backend + frontend), then add a "Battle Configuration" card to CreatureForm visible only for NPCs. Follows existing patterns (learnset editor for lists, recruitment checkbox for toggles).

**Tech Stack:** Pydantic (backend schema), TypeScript interfaces (frontend types), React (form UI with existing shadcn components)

**Design doc:** `docs/plans/2026-03-12-npc-roster-design.md`

---

### Task 1: Add roster fields to backend Pydantic schema

**Files:**
- Modify: `web/backend/models/schemas.py`

**Step 1: Add RosterEntry model and new fields to Creature**

Add a `RosterEntry` model after the `Evolution` class (around line 16), and add four optional fields to the `Creature` model:

```python
class RosterEntry(BaseModel):
    creature_id: str
    level: int
```

Add these fields to `Creature` (after `dialogues`, around line 49):

```python
    is_hostile: bool = False
    lead_creature: RosterEntry | None = None
    roster: list[RosterEntry] = []
    reserves: list[RosterEntry] = []
```

**Step 2: Verify the backend still starts**

Run: `cd web && source .venv/bin/activate && python -c "from backend.models.schemas import Creature; print('OK')"`

Expected: `OK`

**Step 3: Commit**

```bash
git add web/backend/models/schemas.py
git commit -m "feat: add is_hostile, lead_creature, roster, reserves to Creature schema"
```

---

### Task 2: Add roster fields to frontend TypeScript types

**Files:**
- Modify: `web/frontend/src/api/creatures.ts`

**Step 1: Add RosterEntry interface and fields to Creature**

Add before the `Creature` interface (around line 23):

```typescript
export interface RosterEntry {
  creature_id: string
  level: number
}
```

Add to the `Creature` interface (after `dialogues`):

```typescript
  is_hostile?: boolean
  lead_creature?: RosterEntry | null
  roster?: RosterEntry[]
  reserves?: RosterEntry[]
```

**Step 2: Commit**

```bash
git add web/frontend/src/api/creatures.ts
git commit -m "feat: add roster types to Creature interface"
```

---

### Task 3: Add Battle Configuration section to CreatureForm

**Files:**
- Modify: `web/frontend/src/pages/DataEditor/CreatureForm.tsx`

This is the main UI task. Add a "Battle Configuration" card visible only when `form.category === 'npc'`, placed between the Recruitment card and the Dialogues card (between the closing `</Card>` at line 439 and the `{/* Dialogues */}` comment at line 440).

**Step 1: Load creatures list for dropdown**

The form already loads `moves` via `movesApi.list()`. Add a similar pattern for creatures.

Add import at top (creatures API is already partially imported — add `creaturesApi`):

```typescript
import { type Creature, type DialogueEntry, type SoundEntry, type RosterEntry, spritePath, creaturesApi } from '@/api/creatures'
```

Add state alongside existing `moves` state (around line 28):

```typescript
const [allCreatures, setAllCreatures] = useState<Record<string, Creature>>({})
```

Add to the existing useEffect that loads moves (around line 34), or add a parallel one:

```typescript
useEffect(() => {
  movesApi.list().then(setMoves)
  creaturesApi.list().then(setAllCreatures)
}, [])
```

Derive a filtered list of non-NPC creatures for the dropdowns:

```typescript
const creatureOptions = Object.entries(allCreatures)
  .filter(([, c]) => c.category !== 'npc')
  .sort(([, a], [, b]) => a.name.localeCompare(b.name))
```

**Step 2: Add the Battle Configuration card**

Insert this JSX after the Recruitment `</Card>` (line 439) and before the Dialogues section (line 440):

```tsx
{/* Battle Configuration — shown for NPCs */}
{form.category === 'npc' && (
  <Card className="bg-stone/30 border-stone-light/30">
    <CardHeader className="pb-2">
      <CardTitle className="text-gold font-heading text-base">Battle Configuration</CardTitle>
    </CardHeader>
    <CardContent>
      <div className="space-y-4">
        {/* Hostile toggle */}
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={form.is_hostile ?? false}
            onChange={(e) => update({ is_hostile: e.target.checked })}
            className="rounded border-stone-light/30"
          />
          <span className="text-sm text-parchment/80">Is Hostile?</span>
        </label>

        {form.is_hostile && (
          <>
            {/* Lead Creature */}
            <div>
              <Label className="text-parchment/60 text-xs">Lead Creature (recruitable by player after defeat)</Label>
              <div className="flex gap-2 mt-1">
                <select
                  value={form.lead_creature?.creature_id ?? ''}
                  onChange={(e) => {
                    if (e.target.value) {
                      update({ lead_creature: { creature_id: e.target.value, level: form.lead_creature?.level ?? 5 } })
                    } else {
                      update({ lead_creature: null as unknown as RosterEntry })
                    }
                  }}
                  className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                >
                  <option value="" className="bg-stone text-parchment">None</option>
                  {creatureOptions.map(([cId, c]) => (
                    <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                  ))}
                </select>
                {form.lead_creature && (
                  <Input
                    type="number"
                    value={form.lead_creature.level}
                    onChange={(e) => update({ lead_creature: { ...form.lead_creature!, level: Number(e.target.value) } })}
                    className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                    placeholder="Lvl"
                    min={1}
                  />
                )}
              </div>
            </div>

            {/* Party */}
            <div>
              <Label className="text-parchment/60 text-xs">Party</Label>
              <div className="space-y-2 mt-1">
                {(form.roster ?? []).map((entry, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <select
                      value={entry.creature_id}
                      onChange={(e) => {
                        const next = [...(form.roster ?? [])]
                        next[i] = { ...next[i], creature_id: e.target.value }
                        update({ roster: next })
                      }}
                      className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                    >
                      <option value="" className="bg-stone text-parchment">Select creature...</option>
                      {creatureOptions.map(([cId, c]) => (
                        <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                      ))}
                    </select>
                    <Input
                      type="number"
                      value={entry.level}
                      onChange={(e) => {
                        const next = [...(form.roster ?? [])]
                        next[i] = { ...next[i], level: Number(e.target.value) }
                        update({ roster: next })
                      }}
                      className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                      placeholder="Lvl"
                      min={1}
                    />
                    <Button
                      variant="ghost"
                      size="icon-xs"
                      onClick={() => update({ roster: (form.roster ?? []).filter((_, j) => j !== i) })}
                      className="text-parchment/40 hover:text-destructive"
                    >
                      <Trash2 className="size-3" />
                    </Button>
                  </div>
                ))}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => update({ roster: [...(form.roster ?? []), { creature_id: '', level: 5 }] })}
                  className="text-gold/70 hover:text-gold"
                >
                  <Plus className="size-3.5" />
                  Add Party Member
                </Button>
              </div>
            </div>

            {/* Reserves */}
            <div>
              <Label className="text-parchment/60 text-xs">Reserves (max 3)</Label>
              <div className="space-y-2 mt-1">
                {(form.reserves ?? []).map((entry, i) => (
                  <div key={i} className="flex items-center gap-2">
                    <select
                      value={entry.creature_id}
                      onChange={(e) => {
                        const next = [...(form.reserves ?? [])]
                        next[i] = { ...next[i], creature_id: e.target.value }
                        update({ reserves: next })
                      }}
                      className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                    >
                      <option value="" className="bg-stone text-parchment">Select creature...</option>
                      {creatureOptions.map(([cId, c]) => (
                        <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                      ))}
                    </select>
                    <Input
                      type="number"
                      value={entry.level}
                      onChange={(e) => {
                        const next = [...(form.reserves ?? [])]
                        next[i] = { ...next[i], level: Number(e.target.value) }
                        update({ reserves: next })
                      }}
                      className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                      placeholder="Lvl"
                      min={1}
                    />
                    <Button
                      variant="ghost"
                      size="icon-xs"
                      onClick={() => update({ reserves: (form.reserves ?? []).filter((_, j) => j !== i) })}
                      className="text-parchment/40 hover:text-destructive"
                    >
                      <Trash2 className="size-3" />
                    </Button>
                  </div>
                ))}
                {(form.reserves ?? []).length < 3 && (
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => update({ reserves: [...(form.reserves ?? []), { creature_id: '', level: 5 }] })}
                    className="text-gold/70 hover:text-gold"
                  >
                    <Plus className="size-3.5" />
                    Add Reserve
                  </Button>
                )}
              </div>
            </div>
          </>
        )}
      </div>
    </CardContent>
  </Card>
)}
```

Key UI patterns (matching existing codebase):
- Checkbox toggle like "Is Recruitable?" in Recruitment card
- Creature dropdown + level input rows like learnset move selector
- Add/remove buttons matching learnset pattern
- Reserves capped at 3 entries (Add button hidden when full)
- Battle config fields only shown when `is_hostile` is checked

**Step 3: Verify frontend builds**

Run: `cd web/frontend && npm run build`

Expected: Build succeeds with no type errors.

**Step 4: Commit**

```bash
git add web/frontend/src/pages/DataEditor/CreatureForm.tsx
git commit -m "feat: add Battle Configuration section to NPC editor"
```

---

### Task 4: Manual smoke test

**Files:** None (verification only)

**Step 1: Start the dev server**

Run: `./start-web.sh`

**Step 2: Verify on a hostile NPC**

Navigate to an NPC (e.g., Mog at `/editor/npcs/mog`):
- "Battle Configuration" card should appear
- Toggle "Is Hostile?" on
- Lead creature dropdown, party list, and reserves list should appear
- Add a lead creature, party member, and reserve
- Save — verify the data round-trips (reload the page, values persist)

**Step 3: Verify on a non-NPC**

Navigate to a creature (e.g., `/editor/creatures/flame_squire`):
- "Battle Configuration" card should NOT appear

**Step 4: Commit any fixes if needed**

---

## Summary of all modified files

| File | Action |
|------|--------|
| `web/backend/models/schemas.py` | Modify — add RosterEntry, is_hostile, lead_creature, roster, reserves |
| `web/frontend/src/api/creatures.ts` | Modify — add RosterEntry interface and Creature fields |
| `web/frontend/src/pages/DataEditor/CreatureForm.tsx` | Modify — add Battle Configuration card for NPCs |
