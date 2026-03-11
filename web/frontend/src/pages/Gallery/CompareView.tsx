import { assetsApi, type AssetInfo } from '@/api/assets'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'

interface Props {
  left: AssetInfo | null
  right: AssetInfo | null
}

function AssetPanel({ asset, label }: { asset: AssetInfo | null; label: string }) {
  if (!asset) {
    return (
      <Card className="bg-stone/30 border-stone-light/30 flex-1">
        <CardHeader>
          <CardTitle className="text-parchment/40 text-sm">{label}</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="aspect-square bg-stone-light/10 rounded-lg flex items-center justify-center">
            <p className="text-parchment/30 text-sm">Select an asset to compare</p>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card className="bg-stone/30 border-stone-light/30 flex-1">
      <CardHeader>
        <CardTitle className="text-gold text-sm font-heading">{label}</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="aspect-square bg-stone-light/10 rounded-lg flex items-center justify-center p-4 mb-3">
          <img
            src={assetsApi.fileUrl(asset.path)}
            alt={asset.filename}
            className="max-h-full max-w-full object-contain"
          />
        </div>
        <div className="space-y-1 text-sm">
          <p className="text-parchment font-medium truncate">{asset.filename}</p>
          <p className="text-parchment/40 text-xs truncate">{asset.path}</p>
          <div className="flex items-center gap-2">
            <Badge variant="outline" className="text-[10px] text-parchment/60 border-stone-light/40">
              {asset.width && asset.height ? `${asset.width}x${asset.height}` : 'N/A'}
            </Badge>
            <span className="text-xs text-parchment/40 capitalize">{asset.status}</span>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}

export default function CompareView({ left, right }: Props) {
  return (
    <div className="flex gap-4 p-4">
      <AssetPanel asset={left} label="Asset A" />
      <AssetPanel asset={right} label="Asset B" />
    </div>
  )
}
