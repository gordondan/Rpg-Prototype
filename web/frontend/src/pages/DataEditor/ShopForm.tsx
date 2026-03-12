import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Button } from '@/components/ui/button'
import { Plus, Trash2 } from 'lucide-react'
import type { Shop } from '@/api/shops'
import { useChanges } from '@/context/ChangeContext'

interface Props {
  id: string
  shop: Shop
}

export default function ShopForm({ id, shop: initial }: Props) {
  const [form, setForm] = useState<Shop>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<Shop>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('shops', id, next, `${next.name}`)
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
            <Label className="text-parchment/60">Greeting</Label>
            <Textarea
              value={form.greeting}
              onChange={(e) => update({ greeting: e.target.value })}
              rows={2}
              className="bg-stone/50 border-stone-light/30 text-parchment resize-none"
            />
          </div>
        </div>

        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Shop Items</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {form.items.map((itemId, i) => (
                <div key={i} className="flex items-center gap-2">
                  <Input
                    value={itemId}
                    onChange={(e) => {
                      const next = [...form.items]
                      next[i] = e.target.value
                      update({ items: next })
                    }}
                    className="flex-1 bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                    placeholder="Item ID"
                  />
                  <Button
                    variant="ghost"
                    size="icon-xs"
                    onClick={() => {
                      const next = form.items.filter((_, j) => j !== i)
                      update({ items: next })
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
                onClick={() => update({ items: [...form.items, ''] })}
                className="text-gold/70 hover:text-gold"
              >
                <Plus className="size-3.5" />
                Add Item
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </ScrollArea>
  )
}
