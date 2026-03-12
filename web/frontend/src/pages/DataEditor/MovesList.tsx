import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search, Plus, ChevronDown, ChevronRight, X } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import { type Move, movesApi } from '@/api/moves'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

interface Filters {
  types: string[]
  category: 'all' | 'physical' | 'special' | 'status'
  hasPower: 'all' | 'yes' | 'no'
}

const DEFAULT_FILTERS: Filters = {
  types: [],
  category: 'all',
  hasPower: 'all',
}

function isFiltersActive(filters: Filters): boolean {
  return (
    filters.types.length > 0 ||
    filters.category !== 'all' ||
    filters.hasPower !== 'all'
  )
}

interface Props {
  moves: Record<string, Move>
  selectedId: string | null
  onSelect: (id: string) => void
  onRefresh?: () => void
}

export default function MovesList({ moves, selectedId, onSelect, onRefresh }: Props) {
  const [search, setSearch] = useState('')
  const [filtersOpen, setFiltersOpen] = useState(false)
  const [filters, setFilters] = useState<Filters>(DEFAULT_FILTERS)

  const active = isFiltersActive(filters)

  const allTypes = useMemo(() => {
    const types = new Set<string>()
    for (const m of Object.values(moves)) {
      if (m.type) types.add(m.type)
    }
    return [...types].sort()
  }, [moves])

  const filtered = useMemo(() => {
    let entries = Object.entries(moves)

    if (search) {
      const q = search.toLowerCase()
      entries = entries.filter(
        ([id, m]) =>
          m.name.toLowerCase().includes(q) ||
          id.toLowerCase().includes(q) ||
          m.type.toLowerCase().includes(q) ||
          m.category.toLowerCase().includes(q)
      )
    }

    if (filters.types.length > 0) {
      entries = entries.filter(([, m]) => filters.types.includes(m.type))
    }

    if (filters.category !== 'all') {
      entries = entries.filter(([, m]) => m.category === filters.category)
    }

    if (filters.hasPower === 'yes') {
      entries = entries.filter(([, m]) => m.power > 0)
    } else if (filters.hasPower === 'no') {
      entries = entries.filter(([, m]) => m.power === 0)
    }

    return entries
  }, [moves, search, filters])

  const toggleType = (t: string) => {
    setFilters((f) => ({
      ...f,
      types: f.types.includes(t) ? f.types.filter((x) => x !== t) : [...f.types, t],
    }))
  }

  const handleCreate = async () => {
    try {
      const result = await movesApi.create()
      toast.success('Move created')
      await onRefresh?.()
      onSelect(result.move_id)
    } catch (err) {
      toast.error(`Failed to create move: ${err instanceof Error ? err.message : 'Unknown error'}`)
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
          New Move
        </Button>
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search moves..."
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

              {/* Category toggle */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Category</p>
                <div className="flex gap-1">
                  {(['all', 'physical', 'special', 'status'] as const).map((opt) => (
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

              {/* Has Power toggle */}
              <div>
                <p className="text-[10px] font-medium text-parchment/50 uppercase tracking-wide mb-1">Has Power</p>
                <div className="flex gap-1">
                  {(['all', 'yes', 'no'] as const).map((opt) => (
                    <button
                      key={opt}
                      onClick={() => setFilters((f) => ({ ...f, hasPower: opt }))}
                      className={cn(
                        'text-[10px] px-2 py-0.5 rounded-full border transition-colors capitalize',
                        filters.hasPower === opt
                          ? 'bg-gold/20 text-gold border-transparent'
                          : 'border-stone-light/30 text-parchment/40 hover:text-parchment/60'
                      )}
                    >
                      {opt}
                    </button>
                  ))}
                </div>
              </div>

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
          {filtered.length} of {Object.keys(moves).length} moves
        </p>
      </div>
      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, move]) => (
            <button
              key={id}
              onClick={() => onSelect(id)}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-left transition-colors',
                selectedId === id
                  ? 'bg-gold/15 text-gold'
                  : 'text-parchment/80 hover:bg-stone-light/20'
              )}
            >
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{move.name}</p>
                <div className="flex items-center gap-1.5 mt-0.5">
                  <Badge
                    className="text-[10px] px-1.5 py-0 h-4 border-0"
                    style={{
                      backgroundColor: `${TYPE_COLORS[move.type] ?? '#666'}22`,
                      color: TYPE_COLORS[move.type] ?? '#999',
                    }}
                  >
                    {move.type}
                  </Badge>
                  <span className="text-xs text-parchment/40 capitalize">{move.category}</span>
                </div>
              </div>
              <span className="text-xs text-parchment/40 font-mono">{move.power > 0 ? move.power : '—'}</span>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
