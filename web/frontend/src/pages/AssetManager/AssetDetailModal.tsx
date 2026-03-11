import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { assetsApi, type AssetInfo } from '@/api/assets'
import { toast } from 'sonner'
import { Download, Trash2 } from 'lucide-react'

interface Props {
  asset: AssetInfo | null
  open: boolean
  onOpenChange: (open: boolean) => void
  onUpdate: () => void
}

const statusColors: Record<string, string> = {
  active: 'bg-green-400/10 text-green-400',
  in_development: 'bg-yellow-400/10 text-yellow-400',
  needs_review: 'bg-orange-400/10 text-orange-400',
  deprecated: 'bg-red-400/10 text-red-400',
}

export default function AssetDetailModal({ asset, open, onOpenChange, onUpdate }: Props) {
  if (!asset) return null

  const handleStatusChange = async (status: string) => {
    try {
      await assetsApi.updateStatus(asset.path, status)
      toast.success(`Status updated to ${status}`)
      onUpdate()
    } catch {
      toast.error('Failed to update status')
    }
  }

  const handleDelete = async () => {
    try {
      await assetsApi.delete(asset.path)
      toast.success('Asset deleted')
      onOpenChange(false)
      onUpdate()
    } catch {
      toast.error('Failed to delete asset')
    }
  }

  const sizeStr =
    asset.size_bytes < 1024
      ? `${asset.size_bytes} B`
      : asset.size_bytes < 1048576
        ? `${(asset.size_bytes / 1024).toFixed(1)} KB`
        : `${(asset.size_bytes / 1048576).toFixed(1)} MB`

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-lg bg-dark-slate border-stone-light/30 text-parchment">
        <DialogHeader>
          <DialogTitle className="text-gold font-heading">{asset.filename}</DialogTitle>
          <DialogDescription className="text-parchment/50">{asset.path}</DialogDescription>
        </DialogHeader>

        <div className="flex flex-col items-center gap-4">
          <div className="bg-stone/50 rounded-lg p-4 flex items-center justify-center max-h-[300px] w-full">
            <img
              src={assetsApi.fileUrl(asset.path)}
              alt={asset.filename}
              className="max-h-[280px] max-w-full object-contain"
            />
          </div>

          <div className="grid grid-cols-2 gap-3 w-full text-sm">
            <div>
              <span className="text-parchment/50 text-xs">Size</span>
              <p>{sizeStr}</p>
            </div>
            <div>
              <span className="text-parchment/50 text-xs">Dimensions</span>
              <p>
                {asset.width && asset.height
                  ? `${asset.width} x ${asset.height}`
                  : 'Unknown'}
              </p>
            </div>
            <div>
              <span className="text-parchment/50 text-xs">Category</span>
              <p className="capitalize">{asset.category}</p>
            </div>
            <div>
              <span className="text-parchment/50 text-xs">Status</span>
              <div className="mt-0.5">
                <Badge className={`border-0 ${statusColors[asset.status] ?? ''}`}>
                  {asset.status}
                </Badge>
              </div>
            </div>
          </div>

          <div className="flex gap-2 w-full">
            <span className="text-xs text-parchment/50 mr-auto self-center">Set status:</span>
            {['active', 'in_development', 'needs_review', 'deprecated'].map((s) => (
              <Button
                key={s}
                variant="ghost"
                size="xs"
                onClick={() => handleStatusChange(s)}
                className={`text-xs ${asset.status === s ? 'bg-stone-light/30' : ''} text-parchment/70`}
              >
                {s.replace('_', ' ')}
              </Button>
            ))}
          </div>

          <div className="flex gap-2 w-full border-t border-stone-light/30 pt-3">
            <a
              href={assetsApi.fileUrl(asset.path)}
              download
              className="inline-flex items-center gap-1.5 text-sm text-gold hover:text-gold/80"
            >
              <Download className="size-4" />
              Download
            </a>
            <Button
              variant="destructive"
              size="sm"
              onClick={handleDelete}
              className="ml-auto"
            >
              <Trash2 className="size-3.5" />
              Delete
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
