import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import type { Creature } from '@/api/creatures'
import { cn } from '@/lib/utils'

interface Props {
  creatures: Record<string, Creature>
  selectedId: string | null
  onSelect: (id: string) => void
}

export default function CreatureList({ creatures, selectedId, onSelect }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const entries = Object.entries(creatures)
    if (!search) return entries
    const q = search.toLowerCase()
    return entries.filter(
      ([id, c]) =>
        c.name.toLowerCase().includes(q) ||
        id.toLowerCase().includes(q) ||
        c.types.some((t) => t.toLowerCase().includes(q))
    )
  }, [creatures, search])

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search creatures..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>
        <p className="mt-1.5 text-xs text-parchment/40">
          {filtered.length} of {Object.keys(creatures).length} creatures
        </p>
      </div>

      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, creature]) => (
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
              <div className="flex size-10 items-center justify-center rounded-lg bg-stone-light/30 overflow-hidden shrink-0">
                {creature.sprite_battle ? (
                  <img
                    src={`/api/assets/thumbnail/${creature.sprite_battle}?size=64`}
                    alt={creature.name}
                    className="size-8 object-contain"
                    onError={(e) => {
                      ;(e.target as HTMLImageElement).style.display = 'none'
                    }}
                  />
                ) : (
                  <span className="text-parchment/30 text-[10px]">?</span>
                )}
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
  )
}
