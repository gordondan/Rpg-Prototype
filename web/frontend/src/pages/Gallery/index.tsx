import { useState, useEffect, useMemo, useCallback } from 'react'
import { assetsApi, type AssetInfo } from '@/api/assets'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Badge } from '@/components/ui/badge'
import { Search, Columns2 } from 'lucide-react'
import Lightbox from './Lightbox'
import CompareView from './CompareView'
import { toast } from 'sonner'

const CATEGORIES = ['all', 'creatures', 'items', 'maps', 'ui', 'effects']

export default function Gallery() {
  const [category, setCategory] = useState('all')
  const [assets, setAssets] = useState<AssetInfo[]>([])
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [lightboxIndex, setLightboxIndex] = useState(0)
  const [lightboxOpen, setLightboxOpen] = useState(false)
  const [compareMode, setCompareMode] = useState(false)
  const [compareLeft, setCompareLeft] = useState<AssetInfo | null>(null)
  const [compareRight, setCompareRight] = useState<AssetInfo | null>(null)

  const loadAssets = useCallback(async () => {
    setLoading(true)
    try {
      const data = await assetsApi.list(category === 'all' ? undefined : category)
      setAssets(data)
    } catch (err) {
      toast.error(`Failed to load: ${err instanceof Error ? err.message : 'Unknown'}`)
    } finally {
      setLoading(false)
    }
  }, [category])

  useEffect(() => {
    loadAssets()
  }, [loadAssets])

  const filtered = useMemo(() => {
    if (!search) return assets
    const q = search.toLowerCase()
    return assets.filter(
      (a) =>
        a.filename.toLowerCase().includes(q) ||
        a.path.toLowerCase().includes(q)
    )
  }, [assets, search])

  const handleClick = (asset: AssetInfo, index: number) => {
    if (compareMode) {
      if (!compareLeft) {
        setCompareLeft(asset)
      } else if (!compareRight) {
        setCompareRight(asset)
      } else {
        setCompareLeft(asset)
        setCompareRight(null)
      }
    } else {
      setLightboxIndex(index)
      setLightboxOpen(true)
    }
  }

  return (
    <div className="flex flex-col h-full">
      <div className="p-4 pb-0">
        <div className="flex items-center justify-between mb-4">
          <h1 className="font-heading text-2xl text-gold">Gallery</h1>
          <Button
            variant={compareMode ? 'default' : 'outline'}
            size="sm"
            onClick={() => {
              setCompareMode(!compareMode)
              setCompareLeft(null)
              setCompareRight(null)
            }}
            className={compareMode ? 'bg-gold text-dark-slate' : 'border-stone-light/30 text-parchment/70'}
          >
            <Columns2 className="size-4" />
            Compare
          </Button>
        </div>
      </div>

      <Tabs value={category} onValueChange={setCategory} className="flex-1 flex flex-col overflow-hidden">
        <div className="px-4 flex items-center gap-4">
          <TabsList className="bg-stone/50">
            {CATEGORIES.map((c) => (
              <TabsTrigger key={c} value={c} className="capitalize text-parchment/70 data-active:text-gold">
                {c}
              </TabsTrigger>
            ))}
          </TabsList>
          <div className="relative flex-1 max-w-xs">
            <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
            <Input
              placeholder="Search..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
            />
          </div>
          <Badge variant="outline" className="text-parchment/50 border-stone-light/40">
            {filtered.length} assets
          </Badge>
        </div>

        {compareMode && (
          <CompareView left={compareLeft} right={compareRight} />
        )}

        {CATEGORIES.map((c) => (
          <TabsContent key={c} value={c} className="flex-1 overflow-hidden">
            {loading ? (
              <div className="flex items-center justify-center h-full">
                <p className="text-parchment/50">Loading...</p>
              </div>
            ) : (
              <ScrollArea className="h-full">
                <div className="grid grid-cols-[repeat(auto-fill,minmax(200px,1fr))] gap-4 p-4">
                  {filtered.map((asset, i) => (
                    <button
                      key={asset.path}
                      onClick={() => handleClick(asset, i)}
                      className="group rounded-lg border border-stone-light/30 bg-stone/30 overflow-hidden hover:border-gold/30 transition-all hover:shadow-lg hover:shadow-gold/5 text-left"
                    >
                      <div className="aspect-square bg-stone-light/10 flex items-center justify-center p-3">
                        <img
                          src={assetsApi.thumbnailUrl(asset.path, 256)}
                          alt={asset.filename}
                          className="max-h-full max-w-full object-contain group-hover:scale-105 transition-transform"
                          onError={(e) => {
                            ;(e.target as HTMLImageElement).style.display = 'none'
                          }}
                        />
                      </div>
                      <div className="p-2.5">
                        <p className="text-sm text-parchment/80 truncate">{asset.filename}</p>
                        <p className="text-xs text-parchment/40 capitalize mt-0.5">{asset.category}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </ScrollArea>
            )}
          </TabsContent>
        ))}
      </Tabs>

      <Lightbox
        assets={filtered}
        currentIndex={lightboxIndex}
        open={lightboxOpen}
        onOpenChange={setLightboxOpen}
        onNavigate={setLightboxIndex}
      />
    </div>
  )
}
