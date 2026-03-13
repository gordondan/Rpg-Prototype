import { useState, useRef } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Button } from '@/components/ui/button'
import { Upload, Loader2 } from 'lucide-react'
import { toast } from 'sonner'
import { type ImageType, type GridDetection, assetsApi } from '@/api/assets'

interface Props {
  /** Which image types to offer in the selector */
  allowedTypes?: ImageType[]
  /** Entity this upload is for (e.g., creature ID) */
  entityId: string
  /** Called after a successful upload */
  onUpload?: (result: { path: string; imageType: ImageType }) => void
  /** For character images: overworld or battle */
  variant?: 'overworld' | 'battle'
}

const TYPE_LABELS: Record<ImageType, string> = {
  character: 'Character Image',
  sprite2d: 'Animation (Sprite 2D)',
  player: 'Animation (Player)',
  map: 'Map',
}

export default function ImageUpload({
  allowedTypes = ['character', 'sprite2d', 'player'],
  entityId,
  onUpload,
  variant = 'overworld',
}: Props) {
  const [imageType, setImageType] = useState<ImageType>(allowedTypes[0])
  const [file, setFile] = useState<File | null>(null)
  const [preview, setPreview] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [analyzing, setAnalyzing] = useState(false)
  const fileRef = useRef<HTMLInputElement>(null)

  // Animation-specific fields
  const [animName, setAnimName] = useState('')
  const [frameWidth, setFrameWidth] = useState(64)
  const [frameHeight, setFrameHeight] = useState(64)
  const [columns, setColumns] = useState(1)
  const [rows, setRows] = useState(1)
  const [frameCount, setFrameCount] = useState(1)
  const [fps, setFps] = useState(8)
  const [loop, setLoop] = useState(true)
  const [detection, setDetection] = useState<GridDetection | null>(null)

  const isAnimation = imageType === 'sprite2d' || imageType === 'player'

  const handleFileSelect = (f: File) => {
    setFile(f)
    setDetection(null)

    // Generate preview
    const url = URL.createObjectURL(f)
    setPreview(url)

    // If animation type, get image dimensions for default grid calc
    if (isAnimation) {
      const img = new Image()
      img.onload = () => {
        // Default: assume square frames based on height
        const h = img.height
        const w = img.width
        const cols = Math.max(1, Math.round(w / h))
        setFrameWidth(Math.round(w / cols))
        setFrameHeight(h)
        setColumns(cols)
        setRows(1)
        setFrameCount(cols)
      }
      img.src = url
    }
  }

  const handleAnalyze = async () => {
    if (!file) return

    // First upload the sprite sheet to a temp-ish location
    const path = `assets/sprites/creatures/${entityId}/${animName || 'unnamed'}/spritesheet.png`
    setAnalyzing(true)
    try {
      const uploadRes = await assetsApi.upload(path, file, imageType)
      if (!uploadRes.ok) throw new Error('Upload failed')

      const result = await assetsApi.analyzeSpriteSheet(path)
      setDetection(result)
      setFrameWidth(result.frame_width)
      setFrameHeight(result.frame_height)
      setColumns(result.columns)
      setRows(result.rows)
      setFrameCount(result.frame_count)

      if (result.detected) {
        toast.success(`Grid detected: ${result.columns}x${result.rows}, ${result.frame_width}x${result.frame_height}px frames`)
      } else {
        toast.info('Could not auto-detect grid. Using fallback dimensions.')
      }
    } catch (err) {
      toast.error(`Analysis failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setAnalyzing(false)
    }
  }

  const handleUpload = async () => {
    if (!file) return
    setUploading(true)

    try {
      if (isAnimation) {
        if (!animName.trim()) {
          toast.error('Animation name is required')
          setUploading(false)
          return
        }

        // Upload sprite sheet
        const path = `assets/sprites/creatures/${entityId}/${animName}/spritesheet.png`
        const uploadRes = await assetsApi.upload(path, file, imageType)
        if (!uploadRes.ok) throw new Error('Upload failed')

        // Generate Godot resource
        await assetsApi.generateAnimationResource({
          creature_id: entityId,
          animation_name: animName,
          frame_width: frameWidth,
          frame_height: frameHeight,
          columns,
          rows,
          frame_count: frameCount,
          fps,
          loop,
          animation_type: imageType,
        })

        toast.success(`Animation "${animName}" created with .tres resource`)
        onUpload?.({ path, imageType })
      } else if (imageType === 'character') {
        const suffix = variant === 'battle' ? `_battle.png` : `.png`
        const path = `assets/sprites/creatures/${entityId}${suffix}`
        const res = await assetsApi.upload(path, file, 'character')
        if (!res.ok) throw new Error('Upload failed')
        toast.success(`${variant} sprite uploaded`)
        onUpload?.({ path, imageType })
      } else {
        // Map type — save as-is
        const path = `assets/sprites/creatures/${entityId}/${file.name}`
        const res = await assetsApi.upload(path, file, 'map')
        if (!res.ok) throw new Error('Upload failed')
        toast.success('File uploaded')
        onUpload?.({ path, imageType })
      }
    } catch (err) {
      toast.error(`Upload failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setUploading(false)
      setFile(null)
      setPreview(null)
    }
  }

  return (
    <div className="space-y-3">
      {/* Type selector — only show if multiple types allowed */}
      {allowedTypes.length > 1 && (
        <div>
          <Label className="text-parchment/60 text-xs">Image Type</Label>
          <select
            value={imageType}
            onChange={(e) => {
              setImageType(e.target.value as ImageType)
              setFile(null)
              setPreview(null)
              setDetection(null)
            }}
            className="w-full bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2 mt-1"
          >
            {allowedTypes.map((t) => (
              <option key={t} value={t} className="bg-stone text-parchment">
                {TYPE_LABELS[t]}
              </option>
            ))}
          </select>
        </div>
      )}

      {/* File picker */}
      <div>
        <input
          ref={fileRef}
          type="file"
          accept="image/png"
          className="hidden"
          onChange={(e) => {
            const f = e.target.files?.[0]
            if (f) handleFileSelect(f)
            e.target.value = ''
          }}
        />
        <Button
          variant="outline"
          size="sm"
          onClick={() => fileRef.current?.click()}
          className="w-full border-stone-light/30 text-parchment/70 hover:text-gold"
        >
          <Upload className="size-3.5 mr-1.5" />
          {file ? file.name : 'Choose file...'}
        </Button>
      </div>

      {/* Preview */}
      {preview && (
        <div className="rounded-lg bg-stone-light/10 border border-stone-light/20 p-2 flex items-center justify-center">
          <img
            src={preview}
            alt="Preview"
            className="max-h-40 object-contain"
            style={{ imageRendering: 'pixelated' }}
          />
        </div>
      )}

      {/* Animation fields */}
      {isAnimation && file && (
        <div className="space-y-2 border border-stone-light/20 rounded-lg p-3 bg-stone/20">
          <div>
            <Label className="text-parchment/60 text-xs">Animation Name</Label>
            <Input
              value={animName}
              onChange={(e) => setAnimName(e.target.value.replace(/[^a-z0-9_-]/gi, '_').toLowerCase())}
              placeholder="e.g. idle, walk, attack"
              className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
            />
          </div>

          <div className="flex gap-2">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frame W</Label>
              <Input
                type="number"
                value={frameWidth}
                onChange={(e) => setFrameWidth(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frame H</Label>
              <Input
                type="number"
                value={frameHeight}
                onChange={(e) => setFrameHeight(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
          </div>

          <div className="flex gap-2">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Columns</Label>
              <Input
                type="number"
                value={columns}
                onChange={(e) => setColumns(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Rows</Label>
              <Input
                type="number"
                value={rows}
                onChange={(e) => setRows(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">Frames</Label>
              <Input
                type="number"
                value={frameCount}
                onChange={(e) => setFrameCount(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
          </div>

          <div className="flex gap-2 items-end">
            <div className="flex-1">
              <Label className="text-parchment/60 text-xs">FPS</Label>
              <Input
                type="number"
                value={fps}
                onChange={(e) => setFps(Number(e.target.value))}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <label className="flex items-center gap-1.5 pb-1 cursor-pointer">
              <input
                type="checkbox"
                checked={loop}
                onChange={(e) => setLoop(e.target.checked)}
                className="rounded border-stone-light/30"
              />
              <span className="text-xs text-parchment/60">Loop</span>
            </label>
          </div>

          {/* Auto-detect button */}
          <Button
            variant="outline"
            size="sm"
            onClick={handleAnalyze}
            disabled={analyzing || !animName.trim()}
            className="w-full border-stone-light/30 text-parchment/70 hover:text-gold"
          >
            {analyzing ? (
              <><Loader2 className="size-3.5 mr-1.5 animate-spin" />Analyzing...</>
            ) : (
              'Auto-detect grid (Gemini)'
            )}
          </Button>

          {detection && (
            <p className="text-xs text-parchment/40">
              {detection.detected
                ? `Gemini detected grid with ${(detection.confidence * 100).toFixed(0)}% confidence`
                : 'Auto-detection unavailable. Using fallback dimensions.'}
            </p>
          )}
        </div>
      )}

      {/* Upload button */}
      {file && (
        <Button
          onClick={handleUpload}
          disabled={uploading || (isAnimation && !animName.trim())}
          className="w-full bg-gold/20 text-gold hover:bg-gold/30 border border-gold/30"
        >
          {uploading ? (
            <><Loader2 className="size-3.5 mr-1.5 animate-spin" />Uploading...</>
          ) : (
            <><Upload className="size-3.5 mr-1.5" />{isAnimation ? 'Upload & Generate .tres' : 'Upload'}</>
          )}
        </Button>
      )}
    </div>
  )
}
