import { useState, useEffect, useCallback } from 'react'
import { assetsApi, type AssetInfo } from '@/api/assets'
import { Tabs, TabsList, TabsTrigger, TabsContent } from '@/components/ui/tabs'
import DashboardBar from './DashboardBar'
import AssetGrid from './AssetGrid'
import AssetDetailModal from './AssetDetailModal'
import DropZone from './DropZone'
import { toast } from 'sonner'

const CATEGORIES = ['creatures', 'items', 'maps', 'ui', 'effects', 'all']

export default function AssetManager() {
  const [category, setCategory] = useState('all')
  const [assets, setAssets] = useState<AssetInfo[]>([])
  const [summary, setSummary] = useState<Record<string, number>>({})
  const [selectedAsset, setSelectedAsset] = useState<AssetInfo | null>(null)
  const [detailOpen, setDetailOpen] = useState(false)
  const [loading, setLoading] = useState(false)

  const loadData = useCallback(async () => {
    setLoading(true)
    try {
      const [assetList, sum] = await Promise.all([
        assetsApi.list(category === 'all' ? undefined : category),
        assetsApi.summary(),
      ])
      setAssets(assetList)
      setSummary(sum)
    } catch (err) {
      toast.error(`Failed to load assets: ${err instanceof Error ? err.message : 'Unknown'}`)
    } finally {
      setLoading(false)
    }
  }, [category])

  useEffect(() => {
    loadData()
  }, [loadData])

  const handleSelect = (asset: AssetInfo) => {
    setSelectedAsset(asset)
    setDetailOpen(true)
  }

  return (
    <div className="flex flex-col h-full">
      <div className="p-4 pb-0">
        <h1 className="font-heading text-2xl text-gold mb-4">Asset Manager</h1>
      </div>

      <DashboardBar summary={summary} />

      <Tabs value={category} onValueChange={setCategory} className="flex-1 flex flex-col overflow-hidden">
        <div className="px-4 pt-3">
          <TabsList className="bg-stone/50">
            {CATEGORIES.map((c) => (
              <TabsTrigger key={c} value={c} className="capitalize text-parchment/70 data-active:text-gold">
                {c}
              </TabsTrigger>
            ))}
          </TabsList>
        </div>

        {CATEGORIES.map((c) => (
          <TabsContent key={c} value={c} className="flex-1 overflow-hidden flex flex-col">
            {loading ? (
              <div className="flex items-center justify-center flex-1">
                <p className="text-parchment/50">Loading assets...</p>
              </div>
            ) : (
              <>
                <div className="flex-1 overflow-hidden">
                  <AssetGrid assets={assets} onSelect={handleSelect} />
                </div>
                <div className="p-4 border-t border-stone-light/30">
                  <DropZone category={category === 'all' ? 'misc' : category} onUploaded={loadData} />
                </div>
              </>
            )}
          </TabsContent>
        ))}
      </Tabs>

      <AssetDetailModal
        asset={selectedAsset}
        open={detailOpen}
        onOpenChange={setDetailOpen}
        onUpdate={loadData}
      />
    </div>
  )
}
