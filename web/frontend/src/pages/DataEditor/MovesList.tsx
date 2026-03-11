import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import type { Move } from '@/api/moves'
import { cn } from '@/lib/utils'

interface Props {
  moves: Record<string, Move>
  selectedId: string | null
  onSelect: (id: string) => void
}

export default function MovesList({ moves, selectedId, onSelect }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const entries = Object.entries(moves)
    if (!search) return entries
    const q = search.toLowerCase()
    return entries.filter(
      ([id, m]) =>
        m.name.toLowerCase().includes(q) ||
        id.toLowerCase().includes(q) ||
        m.type.toLowerCase().includes(q) ||
        m.category.toLowerCase().includes(q)
    )
  }, [moves, search])

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search moves..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
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
