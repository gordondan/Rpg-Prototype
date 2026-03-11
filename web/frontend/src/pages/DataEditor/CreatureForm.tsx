import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Slider } from '@/components/ui/slider'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Plus, Trash2 } from 'lucide-react'
import StatRadarChart from '@/components/RadarChart'
import { TYPE_COLORS, STAT_LABELS } from '@/theme/colors'
import { type Creature, spritePath } from '@/api/creatures'
import { useChanges } from '@/context/ChangeContext'

interface Props {
  id: string
  creature: Creature
}

export default function CreatureForm({ id, creature: initial }: Props) {
  const [form, setForm] = useState<Creature>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<Creature>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('creatures', id, next, `${next.name}`)
  }

  const updateStat = (key: string, value: number) => {
    update({ [key]: value } as unknown as Partial<Creature>)
  }

  const statKeys = Object.keys(STAT_LABELS) as (keyof Creature)[]
  const stats: Record<string, number> = {}
  for (const k of statKeys) {
    stats[k] = (form[k] as number) ?? 0
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-6 space-y-6 max-w-3xl">
        {/* Header with sprites */}
        <div className="flex items-start gap-6">
          {/* Overworld sprite */}
          <div className="flex flex-col items-center gap-1">
            <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
              <img
                src={`/api/assets/thumbnail/${spritePath(id)}?size=128`}
                alt={`${form.name} overworld`}
                className="size-20 object-contain"
                onError={(e) => {
                  ;(e.target as HTMLImageElement).style.display = 'none'
                }}
              />
            </div>
            <span className="text-[10px] text-parchment/40">Overworld</span>
          </div>

          {/* Battle sprite */}
          <div className="flex flex-col items-center gap-1">
            <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
              <img
                src={`/api/assets/thumbnail/${spritePath(id, 'battle')}?size=128`}
                alt={`${form.name} battle`}
                className="size-20 object-contain"
                onError={(e) => {
                  ;(e.target as HTMLImageElement).style.display = 'none'
                }}
              />
            </div>
            <span className="text-[10px] text-parchment/40">Battle</span>
          </div>

          <span className="text-xs text-parchment/40 font-mono mt-auto">{id}</span>
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
        </div>

        {/* Types & class */}
        <div className="flex gap-4">
          <div className="flex-1">
            <Label className="text-parchment/60">Types</Label>
            <div className="flex gap-1.5 mt-1">
              {form.types.map((t) => (
                <Badge
                  key={t}
                  className="border-0"
                  style={{
                    backgroundColor: `${TYPE_COLORS[t] ?? '#666'}33`,
                    color: TYPE_COLORS[t] ?? '#999',
                  }}
                >
                  {t}
                </Badge>
              ))}
            </div>
          </div>
          <div className="w-32">
            <Label className="text-parchment/60">Class</Label>
            <Input
              value={form.class}
              onChange={(e) => update({ class: e.target.value })}
              className="bg-stone/50 border-stone-light/30 text-parchment"
            />
          </div>
          <div className="w-24">
            <Label className="text-parchment/60">Base EXP</Label>
            <Input
              type="number"
              value={form.base_exp}
              onChange={(e) => update({ base_exp: Number(e.target.value) })}
              className="bg-stone/50 border-stone-light/30 text-parchment"
            />
          </div>
        </div>

        <Separator className="bg-stone-light/30" />

        {/* Stats */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Base Stats</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-[1fr_auto] gap-4">
              <div className="space-y-3">
                {statKeys.map((key) => (
                  <div key={key} className="flex items-center gap-3">
                    <span className="w-14 text-xs font-medium text-parchment/60">
                      {STAT_LABELS[key]}
                    </span>
                    <Slider
                      value={[(form[key] as number) ?? 0]}
                      onValueChange={(val) => {
                        const v = Array.isArray(val) ? val[0] : val
                        updateStat(key, v)
                      }}
                      max={200}
                      step={1}
                      className="flex-1"
                    />
                    <Input
                      type="number"
                      value={(form[key] as number) ?? 0}
                      onChange={(e) => updateStat(key, Number(e.target.value))}
                      className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                    />
                  </div>
                ))}
              </div>
              <div className="w-[220px]">
                <StatRadarChart stats={stats} />
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Learnset */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Learnset</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {form.learnset.map((entry, i) => (
                <div key={i} className="flex items-center gap-2">
                  <Input
                    type="number"
                    value={entry.level}
                    onChange={(e) => {
                      const next = [...form.learnset]
                      next[i] = { ...next[i], level: Number(e.target.value) }
                      update({ learnset: next })
                    }}
                    className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                    placeholder="Lvl"
                  />
                  <Input
                    value={entry.move_id}
                    onChange={(e) => {
                      const next = [...form.learnset]
                      next[i] = { ...next[i], move_id: e.target.value }
                      update({ learnset: next })
                    }}
                    className="flex-1 bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                    placeholder="Move ID"
                  />
                  <Button
                    variant="ghost"
                    size="icon-xs"
                    onClick={() => {
                      const next = form.learnset.filter((_, j) => j !== i)
                      update({ learnset: next })
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
                  update({ learnset: [...form.learnset, { level: 1, move_id: '' }] })
                }
                className="text-gold/70 hover:text-gold"
              >
                <Plus className="size-3.5" />
                Add Move
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Evolution */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Evolution</CardTitle>
          </CardHeader>
          <CardContent>
            {form.evolution ? (
              <div className="space-y-2">
                <div className="flex gap-2">
                  <div className="flex-1">
                    <Label className="text-parchment/60 text-xs">Creature ID</Label>
                    <Input
                      value={form.evolution.creature_id}
                      onChange={(e) =>
                        update({ evolution: { ...form.evolution!, creature_id: e.target.value } })
                      }
                      className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                    />
                  </div>
                  <div className="w-20">
                    <Label className="text-parchment/60 text-xs">Level</Label>
                    <Input
                      type="number"
                      value={form.evolution.level}
                      onChange={(e) =>
                        update({
                          evolution: { ...form.evolution!, level: Number(e.target.value) },
                        })
                      }
                      className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                    />
                  </div>
                </div>
                <div>
                  <Label className="text-parchment/60 text-xs">Flavor Text</Label>
                  <Input
                    value={form.evolution.flavor}
                    onChange={(e) =>
                      update({ evolution: { ...form.evolution!, flavor: e.target.value } })
                    }
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                  />
                </div>
              </div>
            ) : (
              <p className="text-sm text-parchment/40">No evolution data</p>
            )}
          </CardContent>
        </Card>

        {/* Recruitment */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Recruitment</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <Label className="text-parchment/60 text-xs">Method</Label>
                <Input
                  value={form.recruit_method ?? ''}
                  onChange={(e) => update({ recruit_method: e.target.value })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                />
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Chance</Label>
                <Input
                  type="number"
                  value={form.recruit_chance ?? 0}
                  onChange={(e) => update({ recruit_chance: Number(e.target.value) })}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                  step={0.01}
                  min={0}
                  max={1}
                />
              </div>
              <div className="col-span-2">
                <Label className="text-parchment/60 text-xs">Dialogue</Label>
                <Textarea
                  value={form.recruit_dialogue ?? ''}
                  onChange={(e) => update({ recruit_dialogue: e.target.value })}
                  rows={2}
                  className="bg-stone/50 border-stone-light/30 text-parchment text-sm resize-none"
                />
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </ScrollArea>
  )
}
