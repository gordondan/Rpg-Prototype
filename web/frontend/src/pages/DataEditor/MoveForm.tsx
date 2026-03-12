import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Trash2 } from 'lucide-react'
import { TYPE_COLORS } from '@/theme/colors'
import { type Move, movesApi } from '@/api/moves'
import { useChanges } from '@/context/ChangeContext'
import { toast } from 'sonner'

interface Props {
  id: string
  move: Move
  onDelete?: () => void
}

export default function MoveForm({ id, move: initial, onDelete }: Props) {
  const [form, setForm] = useState<Move>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<Move>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('moves', id, next, `${next.name}`)
  }

  const handleDelete = async () => {
    if (!confirm(`Delete move "${form.name}"?`)) return
    try {
      await movesApi.delete(id)
      toast.success('Move deleted')
      onDelete?.()
    } catch (err) {
      toast.error(`Failed to delete: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-6 space-y-6 max-w-2xl">
        <div className="flex items-start gap-4">
          <div className="flex-1 space-y-3">
            <div>
              <Label className="text-parchment/60">Name</Label>
              <Input
                value={form.name}
                onChange={(e) => update({ name: e.target.value })}
                className="bg-stone/50 border-stone-light/30 text-parchment font-heading text-lg"
              />
            </div>
            <div>
              <Label className="text-parchment/60">Description</Label>
              <Textarea
                value={form.description}
                onChange={(e) => update({ description: e.target.value })}
                rows={2}
                className="bg-stone/50 border-stone-light/30 text-parchment resize-none"
              />
            </div>
          </div>
          <div className="text-right space-y-1">
            <Badge
              className="text-sm px-3 py-1 border-0"
              style={{
                backgroundColor: `${TYPE_COLORS[form.type] ?? '#666'}33`,
                color: TYPE_COLORS[form.type] ?? '#999',
              }}
            >
              {form.type}
            </Badge>
            <p className="text-xs text-parchment/40 font-mono">{id}</p>
            <Button
              variant="ghost"
              size="sm"
              onClick={handleDelete}
              className="text-parchment/40 hover:text-destructive text-xs"
            >
              <Trash2 className="size-3" />
              Delete
            </Button>
          </div>
        </div>

        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Properties</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-3 gap-3">
              <div>
                <Label className="text-parchment/60 text-xs">Type</Label>
                <Input
                  value={form.type}
                  onChange={(e) => update({ type: e.target.value })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Category</Label>
                <Input
                  value={form.category}
                  onChange={(e) => update({ category: e.target.value })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Priority</Label>
                <Input
                  type="number"
                  value={form.priority ?? 0}
                  onChange={(e) => update({ priority: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Power</Label>
                <Input
                  type="number"
                  value={form.power}
                  onChange={(e) => update({ power: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Accuracy</Label>
                <Input
                  type="number"
                  value={form.accuracy}
                  onChange={(e) => update({ accuracy: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">PP</Label>
                <Input
                  type="number"
                  value={form.pp}
                  onChange={(e) => update({ pp: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
            </div>
          </CardContent>
        </Card>

        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Effect</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-parchment/60 text-xs">Stat</Label>
                <Input
                  value={form.effect?.stat ?? ''}
                  onChange={(e) =>
                    update({ effect: { ...form.effect, stat: e.target.value } })
                  }
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Stages</Label>
                <Input
                  type="number"
                  value={form.effect?.stages ?? 0}
                  onChange={(e) =>
                    update({ effect: { ...form.effect, stages: Number(e.target.value) } })
                  }
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Target</Label>
                <Input
                  value={form.effect?.target ?? ''}
                  onChange={(e) =>
                    update({ effect: { ...form.effect, target: e.target.value } })
                  }
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Status</Label>
                <Input
                  value={form.effect?.status ?? ''}
                  onChange={(e) =>
                    update({ effect: { ...form.effect, status: e.target.value } })
                  }
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Effect Chance</Label>
                <Input
                  type="number"
                  value={form.effect_chance ?? 0}
                  onChange={(e) => update({ effect_chance: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </ScrollArea>
  )
}
