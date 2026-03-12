import { useChanges } from '@/context/ChangeContext'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { Save, Undo2, History } from 'lucide-react'

export default function ChangeBar({ onOpenHistory }: { onOpenHistory: () => void }) {
  const { changeCount, saveAll, discardAll, saving, changes } = useChanges()

  if (changeCount === 0) return null

  const changePills = Array.from(changes.values()).slice(0, 5)

  return (
    <div className="flex items-center gap-3 border-t border-stone-light/30 bg-dark-slate px-4 py-2">
      <Badge variant="secondary" className="bg-gold/20 text-gold border-gold/30">
        {changeCount} unsaved change{changeCount !== 1 ? 's' : ''}
      </Badge>

      <div className="flex items-center gap-1.5 overflow-hidden">
        {changePills.map((c) => (
          <Badge
            key={`${c.type}:${c.id}`}
            variant="outline"
            className="text-parchment/70 border-stone-light/40 text-xs truncate max-w-[150px]"
          >
            {c.label}
          </Badge>
        ))}
        {changeCount > 5 && (
          <span className="text-xs text-parchment/50">+{changeCount - 5} more</span>
        )}
      </div>

      <div className="ml-auto flex items-center gap-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={onOpenHistory}
          className="text-parchment/70 hover:text-parchment hover:bg-stone-light/30"
        >
          <History className="size-4" />
          History
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={discardAll}
          className="text-parchment/70 hover:text-destructive hover:bg-stone-light/30"
        >
          <Undo2 className="size-4" />
          Discard
        </Button>
        <Button
          size="sm"
          onClick={saveAll}
          disabled={saving}
          className="bg-gold text-dark-slate hover:bg-gold/80 font-medium"
        >
          <Save className="size-4" />
          {saving ? 'Saving...' : 'Save All'}
        </Button>
      </div>
    </div>
  )
}
