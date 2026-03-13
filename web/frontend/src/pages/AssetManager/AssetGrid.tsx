import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Search } from 'lucide-react'
import { assetsApi, type AssetInfo } from '@/api/assets'

interface Props {
  assets: AssetInfo[]
  onSelect: (asset: AssetInfo) => void
}

const statusColors: Record<string, string> = {
  active: 'bg-green-400/10 text-green-400',
  in_development: 'bg-yellow-400/10 text-yellow-400',
  needs_review: 'bg-orange-400/10 text-orange-400',
  deprecated: 'bg-red-400/10 text-red-400',
}

export default function AssetGrid({ assets, onSelect }: Props) {
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    if (!search) return assets
    const q = search.toLowerCase()
    return assets.filter(
      (a) =>
        a.filename.toLowerCase().includes(q) ||
        a.path.toLowerCase().includes(q) ||
        a.category.toLowerCase().includes(q)
    )
  }, [assets, search])

  return (
    <div className="flex flex-col h-full">
      <div className="p-4 border-b border-stone-light/30">
        <div className="relative max-w-md">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search assets..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>
        <p className="mt-1.5 text-xs text-parchment/40">
          {filtered.length} assets
        </p>
      </div>

      <ScrollArea className="flex-1">
        <div className="grid grid-cols-[repeat(auto-fill,minmax(160px,1fr))] gap-3 p-4">
          {filtered.map((asset) => (
            <button
              key={asset.path}
              onClick={() => onSelect(asset)}
              className="group rounded-lg border border-stone-light/30 bg-stone/30 overflow-hidden hover:border-gold/30 transition-colors text-left"
            >
              <div className="aspect-square bg-stone-light/10 flex items-center justify-center p-2">
                <img
                  src={assetsApi.thumbnailUrl(asset.path, 128)}
                  alt={asset.filename}
                  className="max-h-full max-w-full object-contain group-hover:scale-105 transition-transform"
                  onError={(e) => {
                    ;(e.target as HTMLImageElement).style.display = 'none'
                  }}
                />
              </div>
              <div className="p-2">
                <p className="text-xs text-parchment/80 truncate">{asset.filename}</p>
                <div className="flex items-center justify-between mt-1">
                  <span className="text-[10px] text-parchment/40 capitalize">{asset.category}</span>
                  <Badge
                    className={`text-[9px] px-1 py-0 h-3.5 border-0 ${statusColors[asset.status] ?? ''}`}
                  >
                    {asset.status}
                  </Badge>
                </div>
              </div>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
