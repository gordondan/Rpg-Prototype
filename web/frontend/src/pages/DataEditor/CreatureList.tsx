import { useState, useMemo, useEffect, useRef } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search, Plus, ChevronDown, ChevronRight, X, RefreshCw } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import { type Creature, spritePath, creaturesApi } from '@/api/creatures'
import { BASE } from '@/api/client'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

interface Filters {
  types: string[]
  classes: string[]
  category: 'all' | 'starter' | 'wild' | 'npc'
  missingOverworld: boolean
  missingBattle: boolean
  hasEvolution: 'all' | 'yes' | 'no'
  recruitable: 'all' | 'yes' | 'no'
}

const DEFAULT_FILTERS: Filters = {
  types: [],
  classes: [],
  category: 'all',
  missingOverworld: false,
  missingBattle: false,
  hasEvolution: 'all',
  recruitable: 'all',
}

function isFiltersActive(filters: Filters): boolean {
  return (
    filters.types.length > 0 ||
    filters.classes.length > 0 ||
    filters.category !== 'all' ||
    filters.missingOverworld ||
    filters.missingBattle ||
    filters.hasEvolution !== 'all' ||
    filters.recruitable !== 'all'
  )
}

interface Props {
  creatures: Record<string, Creature>
  selectedId: string | null
  onSelect: (id: string) => void
  onRefresh?: () => void
  mode?: 'creatures' | 'npcs'
}

export default function CreatureList({ creatures, selectedId, onSelect, onRefresh, mode = 'creatures' }: Props) {
  const [search, setSearch] = useState('')
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)
  const [viewOrder, setViewOrder] = useState<string[]>([])
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    creaturesApi.getViewOrder().then(setViewOrder).catch(() => {})
  }, [])

  const active = isFiltersActive(filters)

  const { allTypes, allClasses } = useMemo(() => {
    const types = new Set<string>()
    const classes = new Set<string>()
    for (const c of Object.values(creatures)) {
      c.types.forEach((t) => types.add(t))
      if (c.class) classes.add(c.class)
    }
    return {
      allTypes: [...types].sort(),
      allClasses: [...classes].sort(),
    }
  }, [creatures])

  const filtered = useMemo(() => {
    let entries = Object.entries(creatures)

    // Text search
    if (search) {
      const q = search.toLowerCase()
      entries = entries.filter(
        ([id, c]) =>
          c.name.toLowerCase().includes(q) ||
          id.toLowerCase().includes(q) ||
          c.types.some((t) => t.toLowerCase().includes(q))
      )
    }

    // Type filter
    if (filters.types.length > 0) {
      entries = entries.filter(([, c]) =>
        filters.types.some((t) => c.types.includes(t))
      )
    }

    // Class filter
    if (filters.classes.length > 0) {
      entries = entries.filter(([, c]) => filters.classes.includes(c.class))
    }

    // Category filter
    if (mode === 'npcs') {
      entries = entries.filter(([, c]) => c.category === 'npc')
    } else if (filters.category !== 'all') {
      entries = entries.filter(([, c]) => c.category === filters.category)
    } else {
      entries = entries.filter(([, c]) => c.category !== 'npc')
    }

    // Missing sprites
    if (filters.missingOverworld) {
      entries = entries.filter(([, c]) => c.has_overworld_sprite === false)
    }
    if (filters.missingBattle) {
      entries = entries.filter(([, c]) => c.has_battle_sprite === false)
    }

    // Has evolution
    if (filters.hasEvolution === 'yes') {
      entries = entries.filter(([, c]) => c.evolution != null)
    } else if (filters.hasEvolution === 'no') {
      entries = entries.filter(([, c]) => c.evolution == null)
    }

    // Recruitable
    if (filters.recruitable === 'yes') {
      entries = entries.filter(([, c]) => c.recruit_method != null)
    } else if (filters.recruitable === 'no') {
      entries = entries.filter(([, c]) => c.recruit_method == null)
    }

    // Sort by view order
    if (viewOrder.length > 0) {
      const orderMap = new Map(viewOrder.map((id, i) => [id, i]))
      entries.sort((a, b) => (orderMap.get(a[0]) ?? Infinity) - (orderMap.get(b[0]) ?? Infinity))
    }

    return entries
  }, [creatures, search, filters, viewOrder])

  const toggleType = (t: string) => {
    setFilters((f) => ({
      ...f,
      types: f.types.includes(t) ? f.types.filter((x) => x !== t) : [...f.types, t],
    }))
  }

  const toggleClass = (c: string) => {
    setFilters((f) => ({
      ...f,
      classes: f.classes.includes(c) ? f.classes.filter((x) => x !== c) : [...f.classes, c],
    }))
  }

  const handleSelect = async (id: string) => {
    onSelect(id)
    try {
      const newOrder = await creaturesApi.selectViewOrder(id)
      setViewOrder(newOrder)
    } catch {
      setViewOrder(prev => [id, ...prev.filter(x => x !== id)])
    }
    const viewport = listRef.current?.querySelector('[data-slot="scroll-area-viewport"]')
    viewport?.scrollTo({ top: 0 })
  }

  const handleCreate = async () => {
    try {
      const result = await creaturesApi.create(mode === 'npcs' ? 'npc' : undefined)
      toast.success(mode === 'npcs' ? 'NPC created' : 'Creature created')
      await onRefresh?.()
      creaturesApi.getViewOrder().then(setViewOrder).catch(() => {})
      onSelect(result.creature_id)
    } catch (err) {
      toast.error(`Failed to create: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  const handleReprocess = async () => {
    try {
      const res = await fetch(`${BASE}/assets/reprocess-sprites`, { method: 'POST' })
      if (!res.ok) throw new Error(`Reprocess failed: ${res.status}`)
      const data = await res.json()
      toast.success(`Reprocessed ${data.count} sprites`)
      onRefresh?.()
    } catch (err) {
      toast.error(`Failed to reprocess: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30">
        <Button
          variant="ghost"
          size="sm"
          onClick={handleCreate}
          className="w-full text-gold/70 hover:text-gold justify-start"
        >
          <Plus className="size-3.5" />
          {mode === 'npcs' ? 'New NPC' : 'New Creature'}
        </Button>
        {mode === 'creatures' && (
          <Button
            variant="ghost"
            size="sm"
            onClick={handleReprocess}
            className="w-full text-parchment/50 hover:text-parchment/70 justify-start text-xs"
          >
            <RefreshCw className="size-3.5" />
            Reprocess Sprites
          </Button>
        )}
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder={mode === 'npcs' ? 'Search NPCs...' : 'Search creatures...'}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>

        {/* Collapsible filters */}
        <div>
          <button
            onClick={() => setFiltersOpen(!filtersOpen)}
            className="flex items-center gap-1 text-xs text-parchment/50 hover:text-parchment/70 transition-colors"
          >
            {filtersOpen ? <ChevronDown className="size-3" /> : <ChevronRight className="size-3" />}
            Filters
            {active && <span className="text-gold ml-1">(active)</span>}
          </button>

          {filtersOpen && (
            <div className="mt-2 space-y-3 p-2 rounded-md bg-stone/50 border border-stone-light/30">
              {/* Type chips */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Type</p>
                <div className="flex flex-wrap gap-1">
                  {allTypes.map((t) => (
                    <button
                      key={t}
                      onClick={() => toggleType(t)}
                      className={cn(
                        'text-[10px] px-1.5 py-0.5 rounded-full border transition-colors',
                        filters.types.includes(t)
                          ? 'border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                      style={
                        filters.types.includes(t)
                          ? { backgroundColor: `${TYPE_COLORS[t] ?? '#666'}33`, color: TYPE_COLORS[t] ?? '#999' }
                          : undefined
                      }
                    >
                      {t}
                    </button>
                  ))}
                </div>
              </div>

              {/* Class chips */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Class</p>
                <div className="flex flex-wrap gap-1">
                  {allClasses.map((c) => (
                    <button
                      key={c}
                      onClick={() => toggleClass(c)}
                      className={cn(
                        'text-[10px] px-1.5 py-0.5 rounded-full border transition-colors',
                        filters.classes.includes(c)
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {c}
                    </button>
                  ))}
                </div>
              </div>

              {/* Category toggle — creatures mode only */}
              {mode === 'creatures' && (
                <div>
                  <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Category</p>
                  <div className="flex gap-1">
                    {(['all', 'starter', 'wild'] as const).map((opt) => (
                      <button
                        key={opt}
                        onClick={() => setFilters((f) => ({ ...f, category: opt }))}
                        className={cn(
                          'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                          filters.category === opt
                            ? 'bg-gold/20 text-gold border-transparent'
                            : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                        )}
                      >
                        {opt}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Missing sprites checkboxes */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Missing Sprites</p>
                <div className="space-y-1">
                  <label className="flex items-center gap-1.5 text-[11px] text-parchment/60 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={filters.missingOverworld}
                      onChange={(e) => setFilters((f) => ({ ...f, missingOverworld: e.target.checked }))}
                      className="rounded border-stone-light/30"
                    />
                    Missing overworld
                  </label>
                  <label className="flex items-center gap-1.5 text-[11px] text-parchment/60 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={filters.missingBattle}
                      onChange={(e) => setFilters((f) => ({ ...f, missingBattle: e.target.checked }))}
                      className="rounded border-stone-light/30"
                    />
                    Missing battle
                  </label>
                </div>
              </div>

              {/* Has Evolution toggle — creatures mode only */}
              {mode === 'creatures' && (
                <div>
                  <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Has Evolution</p>
                  <div className="flex gap-1">
                    {(['all', 'yes', 'no'] as const).map((opt) => (
                      <button
                        key={opt}
                        onClick={() => setFilters((f) => ({ ...f, hasEvolution: opt }))}
                        className={cn(
                          'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                          filters.hasEvolution === opt
                            ? 'bg-gold/20 text-gold border-transparent'
                            : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                        )}
                      >
                        {opt}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Recruitable toggle — creatures mode only */}
              {mode === 'creatures' && (
                <div>
                  <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Recruitable</p>
                  <div className="flex gap-1">
                    {(['all', 'yes', 'no'] as const).map((opt) => (
                      <button
                        key={opt}
                        onClick={() => setFilters((f) => ({ ...f, recruitable: opt }))}
                        className={cn(
                          'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                          filters.recruitable === opt
                            ? 'bg-gold/20 text-gold border-transparent'
                            : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                        )}
                      >
                        {opt}
                      </button>
                    ))}
                  </div>
                </div>
              )}

              {/* Clear filters */}
              {active && (
                <button
                  onClick={() => setFilters(DEFAULT_FILTERS)}
                  className="flex items-center gap-1 text-[11px] text-gold/70 hover:text-gold transition-colors"
                >
                  <X className="size-3" />
                  Clear filters
                </button>
              )}
            </div>
          )}
        </div>

        <p className="mt-1.5 text-xs text-parchment/40">
          {filtered.length} {mode === 'npcs' ? 'NPCs' : 'creatures'}
        </p>
      </div>

      <div ref={listRef} className="flex-1">
        <ScrollArea className="h-full">
          <div className="flex flex-col gap-0.5 p-1.5">
            {filtered.map(([id, creature]) => (
              <button
                key={id}
                onClick={() => handleSelect(id)}
                className={cn(
                  'flex items-center gap-3 rounded-md px-3 py-2 text-left transition-colors',
                  selectedId === id
                    ? 'bg-gold/15 text-gold'
                    : 'text-parchment/80 hover:bg-stone-light/20'
                )}
              >
                <div className="flex size-10 items-center justify-center rounded-lg bg-stone-light/30 overflow-hidden shrink-0">
                  <img
                    src={`${BASE}/assets/thumbnail/${creature.npc_sprite ? creature.npc_sprite.replace('res://', '') : spritePath(id, 'battle')}?size=64`}
                    alt={creature.name}
                    className="size-8 object-contain"
                    onError={(e) => {
                      ;(e.target as HTMLImageElement).style.display = 'none'
                    }}
                  />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium truncate">{creature.name}</p>
                  <div className="flex gap-1 mt-0.5">
                    {creature.types.map((t) => (
                      <Badge
                        key={t}
                        className="text-[10px] px-1.5 py-0 h-4 border-0"
                        style={{
                          backgroundColor: `${TYPE_COLORS[t] ?? '#666'}22`,
                          color: TYPE_COLORS[t] ?? '#999',
                        }}
                      >
                        {t}
                      </Badge>
                    ))}
                  </div>
                </div>
              </button>
            ))}
          </div>
        </ScrollArea>
      </div>
    </div>
  )
}
