import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import type { Item } from '@/api/items'
import { useChanges } from '@/context/ChangeContext'

interface Props {
  id: string
  item: Item
}

export default function ItemForm({ id, item: initial }: Props) {
  const [form, setForm] = useState<Item>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<Item>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('items', id, next, `${next.name}`)
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
            <CardTitle className="text-gold font-heading text-base">Properties</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-parchment/60 text-xs">Price</Label>
                <Input
                  type="number"
                  value={form.price}
                  onChange={(e) => update({ price: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Effect Type</Label>
                <Input
                  value={form.effect.type}
                  onChange={(e) => update({ effect: { ...form.effect, type: e.target.value } })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Effect Amount</Label>
                <Input
                  type="number"
                  value={form.effect.amount ?? ''}
                  onChange={(e) =>
                    update({
                      effect: {
                        ...form.effect,
                        amount: e.target.value ? Number(e.target.value) : undefined,
                      },
                    })
                  }
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
