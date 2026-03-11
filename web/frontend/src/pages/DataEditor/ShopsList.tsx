import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Badge } from '@/components/ui/badge'
import { Search, Store } from 'lucide-react'
import type { Shop } from '@/api/shops'
import { cn } from '@/lib/utils'

interface Props {
  shops: Record<string, Shop>
  selectedId: string | null
  onSelect: (id: string) => void
}

export default function ShopsList({ shops, selectedId, onSelect }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const entries = Object.entries(shops)
    if (!search) return entries
    const q = search.toLowerCase()
    return entries.filter(
      ([id, s]) =>
        s.name.toLowerCase().includes(q) || id.toLowerCase().includes(q)
    )
  }, [shops, search])

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30">
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search shops..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>
        <p className="mt-1.5 text-xs text-parchment/40">
          {filtered.length} of {Object.keys(shops).length} shops
        </p>
      </div>
      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, shop]) => (
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
              <Store className="size-4 shrink-0 text-gold/50" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{shop.name}</p>
                <p className="text-xs text-parchment/40 truncate">{shop.greeting}</p>
              </div>
              <Badge variant="outline" className="text-[10px] text-parchment/50 border-stone-light/40">
                {shop.items.length} items
              </Badge>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
