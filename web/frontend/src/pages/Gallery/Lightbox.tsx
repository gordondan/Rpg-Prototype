import {
  Dialog,
  DialogContent,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { ChevronLeft, ChevronRight, X } from 'lucide-react'
import { assetsApi, type AssetInfo } from '@/api/assets'

interface Props {
  assets: AssetInfo[]
  currentIndex: number
  open: boolean
  onOpenChange: (open: boolean) => void
  onNavigate: (index: number) => void
}

export default function Lightbox({ assets, currentIndex, open, onOpenChange, onNavigate }: Props) {
  const asset = assets[currentIndex]
  if (!asset) return null

  const hasPrev = currentIndex > 0
  const hasNext = currentIndex < assets.length - 1

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        showCloseButton={false}
        className="sm:max-w-4xl max-h-[90vh] bg-dark-slate border-stone-light/30 p-0 overflow-hidden"
      >
        <div className="relative flex items-center justify-center bg-stone/30 min-h-[400px]">
          {/* Navigation */}
          {hasPrev && (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => onNavigate(currentIndex - 1)}
              className="absolute left-2 top-1/2 -translate-y-1/2 z-10 text-parchment/70 hover:text-parchment bg-dark-slate/50 hover:bg-dark-slate/80"
            >
              <ChevronLeft className="size-6" />
            </Button>
          )}
          {hasNext && (
            <Button
              variant="ghost"
              size="icon"
              onClick={() => onNavigate(currentIndex + 1)}
              className="absolute right-2 top-1/2 -translate-y-1/2 z-10 text-parchment/70 hover:text-parchment bg-dark-slate/50 hover:bg-dark-slate/80"
            >
              <ChevronRight className="size-6" />
            </Button>
          )}

          {/* Close button */}
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => onOpenChange(false)}
            className="absolute top-2 right-2 z-10 text-parchment/70 hover:text-parchment bg-dark-slate/50"
          >
            <X className="size-4" />
          </Button>

          {/* Image */}
          <img
            src={assetsApi.fileUrl(asset.path)}
            alt={asset.filename}
            className="max-h-[70vh] max-w-full object-contain p-4"
          />
        </div>

        {/* Info bar */}
        <div className="flex items-center justify-between px-4 py-3 border-t border-stone-light/30">
          <div>
            <p className="text-sm text-parchment font-medium">{asset.filename}</p>
            <p className="text-xs text-parchment/40">{asset.path}</p>
          </div>
          <div className="text-xs text-parchment/50">
            {currentIndex + 1} / {assets.length}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
