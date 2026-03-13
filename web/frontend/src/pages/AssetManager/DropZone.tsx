import { useState, useCallback, type DragEvent } from 'react'
import { Upload } from 'lucide-react'
import { cn } from '@/lib/utils'
import { assetsApi } from '@/api/assets'
import { toast } from 'sonner'

interface Props {
  category: string
  onUploaded: () => void
}

export default function DropZone({ category, onUploaded }: Props) {
  const [dragging, setDragging] = useState(false)
  const [uploading, setUploading] = useState(false)

  const handleDrop = useCallback(
    async (e: DragEvent) => {
      e.preventDefault()
      setDragging(false)
      const files = Array.from(e.dataTransfer.files)
      if (files.length === 0) return
      setUploading(true)
      try {
        for (const file of files) {
          const path = `${category}/${file.name}`
          const res = await assetsApi.upload(path, file)
          if (!res.ok) throw new Error(`Upload failed: ${file.name}`)
        }
        toast.success(`Uploaded ${files.length} file(s)`)
        onUploaded()
      } catch (err) {
        toast.error(err instanceof Error ? err.message : 'Upload failed')
      } finally {
        setUploading(false)
      }
    },
    [category, onUploaded]
  )

  return (
    <div
      className={cn(
        'border-2 border-dashed rounded-xl p-8 text-center transition-colors',
        dragging
          ? 'border-gold bg-gold/5'
          : 'border-stone-light/30 hover:border-stone-light/50'
      )}
      onDragOver={(e) => {
        e.preventDefault()
        setDragging(true)
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={handleDrop}
    >
      <Upload className="size-8 mx-auto text-parchment/30 mb-2" />
      <p className="text-sm text-parchment/50">
        {uploading ? 'Uploading...' : 'Drop files here to upload'}
      </p>
      <p className="text-xs text-parchment/30 mt-1">
        Or use the file input below
      </p>
      <input
        type="file"
        multiple
        className="mt-3 text-sm text-parchment/60 file:mr-2 file:rounded-md file:border-0 file:bg-stone-light/30 file:px-3 file:py-1 file:text-sm file:text-parchment/70"
        onChange={async (e) => {
          const files = Array.from(e.target.files ?? [])
          if (files.length === 0) return
          setUploading(true)
          try {
            for (const file of files) {
              const path = `${category}/${file.name}`
              const res = await assetsApi.upload(path, file)
              if (!res.ok) throw new Error(`Upload failed: ${file.name}`)
            }
            toast.success(`Uploaded ${files.length} file(s)`)
            onUploaded()
          } catch (err) {
            toast.error(err instanceof Error ? err.message : 'Upload failed')
          } finally {
            setUploading(false)
          }
        }}
      />
    </div>
  )
}
