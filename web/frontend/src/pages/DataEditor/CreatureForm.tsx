import { useState, useEffect, useRef } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Slider } from '@/components/ui/slider'
import { Separator } from '@/components/ui/separator'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Plus, Trash2, Upload, Download, ChevronDown, ChevronRight } from 'lucide-react'
import StatRadarChart from '@/components/RadarChart'
import { TYPE_COLORS, STAT_LABELS } from '@/theme/colors'
import { type Creature, type DialogueEntry, spritePath } from '@/api/creatures'
import { type Move, movesApi } from '@/api/moves'
import { useChanges } from '@/context/ChangeContext'
import { toast } from 'sonner'

interface Props {
  id: string
  creature: Creature
}

export default function CreatureForm({ id, creature: initial }: Props) {
  const [form, setForm] = useState<Creature>(initial)
  const [spriteRev, setSpriteRev] = useState(0)
  const [moves, setMoves] = useState<Record<string, Move>>({})
  const { markChanged } = useChanges()
  const owUploadRef = useRef<HTMLInputElement>(null)
  const btUploadRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    movesApi.list().then(setMoves)
  }, [])

  useEffect(() => {
    setForm(initial)
    setSpriteRev((r) => r + 1)
  }, [initial])

  const update = (patch: Partial<Creature>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('creatures', id, next, `${next.name}`)
  }

  const updateStat = (key: string, value: number) => {
    update({ [key]: value } as unknown as Partial<Creature>)
  }

  const uploadSprite = async (file: File, variant: 'overworld' | 'battle') => {
    const path = spritePath(id, variant)
    const formData = new FormData()
    formData.append('file', file)
    try {
      const res = await fetch(`/api/assets/upload/${path}`, { method: 'POST', body: formData })
      if (!res.ok) throw new Error(`Upload failed: ${res.status}`)
      setSpriteRev((r) => r + 1)
      markChanged('creatures', id, form, `${form.name}`)
      toast.success(`${variant} sprite uploaded`)
    } catch (err) {
      toast.error(`Upload failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  const downloadSprite = (variant: 'overworld' | 'battle') => {
    const path = spritePath(id, variant)
    const originalPath = path.replace('assets/sprites/creatures/', 'assets/sprites/creatures/original/')
    const a = document.createElement('a')
    a.href = `/api/assets/file/${originalPath}`
    a.download = path.split('/').pop() ?? `${id}.png`
    a.click()
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
          {form.npc_sprite ? (
            /* NPC sprite */
            <div className="flex flex-col items-center gap-1">
              <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
                <img
                  key={`npc-${spriteRev}`}
                  src={`/api/assets/thumbnail/${form.npc_sprite.replace('res://', '')}?size=128&v=${spriteRev}`}
                  alt={form.name}
                  className="size-20 object-contain"
                  onError={(e) => {
                    ;(e.target as HTMLImageElement).style.display = 'none'
                  }}
                />
              </div>
              <span className="text-[10px] text-parchment/40">Sprite</span>
            </div>
          ) : (
            <>
              {/* Overworld sprite */}
              <div className="flex flex-col items-center gap-1">
                <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
                  <img
                    key={`ow-${spriteRev}`}
                    src={`/api/assets/thumbnail/${spritePath(id)}?size=128&v=${spriteRev}`}
                    alt={`${form.name} overworld`}
                    className="size-20 object-contain"
                    onError={(e) => {
                      ;(e.target as HTMLImageElement).style.display = 'none'
                    }}
                  />
                </div>
                <span className="text-[10px] text-parchment/40">Overworld</span>
                <div className="flex gap-1">
                  <input ref={owUploadRef} type="file" accept="image/png,image/jpeg,image/gif" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadSprite(f, 'overworld'); e.target.value = '' }} />
                  <Button variant="ghost" size="icon-xs" title="Upload" onClick={() => owUploadRef.current?.click()} className="text-parchment/40 hover:text-gold"><Upload className="size-3" /></Button>
                  <Button variant="ghost" size="icon-xs" title="Download" onClick={() => downloadSprite('overworld')} className="text-parchment/40 hover:text-gold"><Download className="size-3" /></Button>
                </div>
              </div>

              {/* Battle sprite */}
              <div className="flex flex-col items-center gap-1">
                <div className="size-24 rounded-xl bg-stone-light/20 border border-stone-light/30 flex items-center justify-center overflow-hidden">
                  <img
                    key={`bt-${spriteRev}`}
                    src={`/api/assets/thumbnail/${spritePath(id, 'battle')}?size=128&v=${spriteRev}`}
                    alt={`${form.name} battle`}
                    className="size-20 object-contain"
                    onError={(e) => {
                      ;(e.target as HTMLImageElement).style.display = 'none'
                    }}
                  />
                </div>
                <span className="text-[10px] text-parchment/40">Battle</span>
                <div className="flex gap-1">
                  <input ref={btUploadRef} type="file" accept="image/png,image/jpeg,image/gif" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadSprite(f, 'battle'); e.target.value = '' }} />
                  <Button variant="ghost" size="icon-xs" title="Upload" onClick={() => btUploadRef.current?.click()} className="text-parchment/40 hover:text-gold"><Upload className="size-3" /></Button>
                  <Button variant="ghost" size="icon-xs" title="Download" onClick={() => downloadSprite('battle')} className="text-parchment/40 hover:text-gold"><Download className="size-3" /></Button>
                </div>
              </div>
            </>
          )}

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
                  <select
                    value={entry.move_id}
                    onChange={(e) => {
                      const next = [...form.learnset]
                      next[i] = { ...next[i], move_id: e.target.value }
                      update({ learnset: next })
                    }}
                    className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                  >
                    <option value="" className="bg-stone text-parchment">Select move...</option>
                    {Object.entries(moves)
                      .sort(([, a], [, b]) => a.name.localeCompare(b.name))
                      .map(([moveId, move]) => (
                        <option key={moveId} value={moveId} className="bg-stone text-parchment">
                          {move.name}
                        </option>
                      ))}
                  </select>
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
            <div className="space-y-3">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={form.recruit_method != null}
                  onChange={(e) => {
                    if (e.target.checked) {
                      update({ recruit_method: form.recruit_method ?? 'battle', recruit_chance: form.recruit_chance ?? 0.5 })
                    } else {
                      update({ recruit_method: undefined as unknown as string, recruit_chance: undefined as unknown as number, recruit_dialogue: undefined as unknown as string })
                    }
                  }}
                  className="rounded border-stone-light/30"
                />
                <span className="text-sm text-parchment/80">Is Recruitable?</span>
              </label>
              {form.recruit_method != null && (
                <div>
                  <Label className="text-parchment/60 text-xs">Dialogue</Label>
                  <Textarea
                    value={form.recruit_dialogue ?? ''}
                    onChange={(e) => update({ recruit_dialogue: e.target.value })}
                    rows={2}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm resize-none"
                  />
                </div>
              )}
            </div>
          </CardContent>
        </Card>
        {/* Dialogues — shown for NPCs */}
        {form.category === 'npc' && (
          <Card className="bg-stone/30 border-stone-light/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-gold font-heading text-base">Dialogues</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {form.npc_sprite != null && (
                  <div>
                    <Label className="text-parchment/60 text-xs">NPC Sprite Path</Label>
                    <Input
                      value={form.npc_sprite ?? ''}
                      onChange={(e) => update({ npc_sprite: e.target.value })}
                      className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 font-mono"
                      placeholder="res://assets/sprites/npcs/..."
                    />
                  </div>
                )}
                {Object.entries(form.dialogues ?? {}).map(([dialogueId, entry]) => (
                  <DialogueBlock
                    key={dialogueId}
                    dialogueId={dialogueId}
                    entry={entry}
                    onUpdate={(updated) => {
                      const next = { ...form.dialogues, [dialogueId]: updated }
                      update({ dialogues: next })
                    }}
                    onDelete={() => {
                      const next = { ...form.dialogues }
                      delete next[dialogueId]
                      update({ dialogues: next })
                    }}
                  />
                ))}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => {
                    const newId = `${id}_dialogue_${Object.keys(form.dialogues ?? {}).length + 1}`
                    update({
                      dialogues: { ...form.dialogues, [newId]: { lines: [] } },
                    })
                  }}
                  className="text-gold/70 hover:text-gold"
                >
                  <Plus className="size-3.5" />
                  Add Dialogue
                </Button>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </ScrollArea>
  )
}

function DialogueBlock({
  dialogueId,
  entry,
  onUpdate,
  onDelete,
}: {
  dialogueId: string
  entry: DialogueEntry
  onUpdate: (entry: DialogueEntry) => void
  onDelete: () => void
}) {
  const [open, setOpen] = useState(false)

  return (
    <div className="rounded-md border border-stone-light/30 bg-stone/30">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 w-full px-3 py-2 text-left"
      >
        {open ? <ChevronDown className="size-3 text-parchment/50" /> : <ChevronRight className="size-3 text-parchment/50" />}
        <span className="text-sm font-mono text-parchment/70">{dialogueId}</span>
        <span className="text-xs text-parchment/40 ml-auto">{entry.lines.length} lines</span>
      </button>
      {open && (
        <div className="px-3 pb-3 space-y-2">
          {entry.lines.map((line, i) => (
            <div key={i} className="flex gap-2">
              <Input
                value={line.speaker}
                onChange={(e) => {
                  const lines = [...entry.lines]
                  lines[i] = { ...lines[i], speaker: e.target.value }
                  onUpdate({ ...entry, lines })
                }}
                className="w-28 bg-stone/50 border-stone-light/30 text-parchment text-xs h-7"
                placeholder="Speaker"
              />
              <Textarea
                value={line.text}
                onChange={(e) => {
                  const lines = [...entry.lines]
                  lines[i] = { ...lines[i], text: e.target.value }
                  onUpdate({ ...entry, lines })
                }}
                rows={1}
                className="flex-1 bg-stone/50 border-stone-light/30 text-parchment text-xs resize-none"
              />
              <Button
                variant="ghost"
                size="icon-xs"
                onClick={() => {
                  const lines = entry.lines.filter((_, j) => j !== i)
                  onUpdate({ ...entry, lines })
                }}
                className="text-parchment/40 hover:text-destructive shrink-0"
              >
                <Trash2 className="size-3" />
              </Button>
            </div>
          ))}
          <div className="flex gap-2">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => onUpdate({ ...entry, lines: [...entry.lines, { text: '', speaker: '' }] })}
              className="text-gold/70 hover:text-gold text-xs"
            >
              <Plus className="size-3" />
              Add Line
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={onDelete}
              className="text-parchment/40 hover:text-destructive text-xs ml-auto"
            >
              <Trash2 className="size-3" />
              Remove Dialogue
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}
