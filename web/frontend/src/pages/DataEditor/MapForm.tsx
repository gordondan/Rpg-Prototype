import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Button } from '@/components/ui/button'
import { Plus, Trash2 } from 'lucide-react'
import type { GameMap } from '@/api/maps'
import { useChanges } from '@/context/ChangeContext'

interface Props {
  id: string
  map: GameMap
}

export default function MapForm({ id, map: initial }: Props) {
  const [form, setForm] = useState<GameMap>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<GameMap>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('maps', id, next, `${next.name}`)
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-6 space-y-6 max-w-2xl">
        <div className="space-y-3">
          <div>
            <Label className="text-parchment/60">Name</Label>
            <Input
              value={form.name}
              onChange={(e) => update({ name: e.target.value })}
              className="bg-stone/50 border-stone-light/30 text-parchment font-heading text-lg"
            />
          </div>
          <p className="text-xs text-parchment/40 font-mono">{id}</p>
          <div>
            <Label className="text-parchment/60">Description</Label>
            <Textarea
              value={form.description}
              onChange={(e) => update({ description: e.target.value })}
              rows={3}
              className="bg-stone/50 border-stone-light/30 text-parchment resize-none"
            />
          </div>
        </div>

        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Encounters</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {/* Header */}
              <div className="grid grid-cols-[1fr_60px_60px_60px_32px] gap-2 text-xs text-parchment/40 px-1">
                <span>Creature</span>
                <span>Min Lv</span>
                <span>Max Lv</span>
                <span>Weight</span>
                <span />
              </div>

              {form.encounters.map((enc, i) => (
                <div key={i} className="grid grid-cols-[1fr_60px_60px_60px_32px] gap-2">
                  <Input
                    value={enc.creature_id}
                    onChange={(e) => {
                      const next = [...form.encounters]
                      next[i] = { ...next[i], creature_id: e.target.value }
                      update({ encounters: next })
                    }}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                  />
                  <Input
                    type="number"
                    value={enc.level_min}
                    onChange={(e) => {
                      const next = [...form.encounters]
                      next[i] = { ...next[i], level_min: Number(e.target.value) }
                      update({ encounters: next })
                    }}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 text-center"
                  />
                  <Input
                    type="number"
                    value={enc.level_max}
                    onChange={(e) => {
                      const next = [...form.encounters]
                      next[i] = { ...next[i], level_max: Number(e.target.value) }
                      update({ encounters: next })
                    }}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 text-center"
                  />
                  <Input
                    type="number"
                    value={enc.weight}
                    onChange={(e) => {
                      const next = [...form.encounters]
                      next[i] = { ...next[i], weight: Number(e.target.value) }
                      update({ encounters: next })
                    }}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 text-center"
                  />
                  <Button
                    variant="ghost"
                    size="icon-xs"
                    onClick={() => {
                      const next = form.encounters.filter((_, j) => j !== i)
                      update({ encounters: next })
                    }}
                    className="text-parchment/40 hover:text-destructive"
                  >
                    <Trash2 className="size-3" />
                  </Button>
                </div>
              ))}

              <Button
                variant="ghost"
                size="sm"
                onClick={() =>
                  update({
                    encounters: [
                      ...form.encounters,
                      { creature_id: '', level_min: 1, level_max: 5, weight: 10 },
                    ],
                  })
                }
                className="text-gold/70 hover:text-gold"
              >
                <Plus className="size-3.5" />
                Add Encounter
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </ScrollArea>
  )
}
