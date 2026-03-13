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
import { Plus, Trash2, Upload, ChevronDown, ChevronRight, Volume2 } from 'lucide-react'
import StatRadarChart from '@/components/RadarChart'
import { TYPE_COLORS, STAT_LABELS } from '@/theme/colors'
import { type Creature, type DialogueEntry, type SoundEntry, type RosterEntry, spritePath, creaturesApi } from '@/api/creatures'
import { BASE } from '@/api/client'
import { type Move, movesApi } from '@/api/moves'
import { useChanges } from '@/context/ChangeContext'
import { toast } from 'sonner'
import ImageUpload from '@/components/ImageUpload'
import { type AnimationInfo, assetsApi } from '@/api/assets'

interface Props {
  id: string
  creature: Creature
}

export default function CreatureForm({ id, creature: initial }: Props) {
  const [form, setForm] = useState<Creature>(initial)
  const [spriteRev, setSpriteRev] = useState(0)
  const [moves, setMoves] = useState<Record<string, Move>>({})
  const [allCreatures, setAllCreatures] = useState<Record<string, Creature>>({})
  const { markChanged } = useChanges()

  useEffect(() => {
    movesApi.list().then(setMoves)
    creaturesApi.list().then(setAllCreatures)
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

  const statKeys = Object.keys(STAT_LABELS) as (keyof Creature)[]
  const stats: Record<string, number> = {}
  for (const k of statKeys) {
    stats[k] = (form[k] as number) ?? 0
  }

  const creatureOptions = Object.entries(allCreatures)
    .filter(([, c]) => c.category !== 'npc')
    .sort(([, a], [, b]) => a.name.localeCompare(b.name))

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
                  src={`${BASE}/assets/thumbnail/${form.npc_sprite.replace('res://', '')}?size=128&v=${spriteRev}`}
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
                    src={`${BASE}/assets/thumbnail/${spritePath(id)}?size=128&v=${spriteRev}`}
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
                    key={`bt-${spriteRev}`}
                    src={`${BASE}/assets/thumbnail/${spritePath(id, 'battle')}?size=128&v=${spriteRev}`}
                    alt={`${form.name} battle`}
                    className="size-20 object-contain"
                    onError={(e) => {
                      ;(e.target as HTMLImageElement).style.display = 'none'
                    }}
                  />
                </div>
                <span className="text-[10px] text-parchment/40">Battle</span>
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

        {/* Sprites & Animations */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Sprites & Animations</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {/* Character sprite uploads */}
              {!form.npc_sprite && (
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <Label className="text-parchment/60 text-xs mb-2 block">Overworld Sprite</Label>
                    <ImageUpload
                      allowedTypes={['character']}
                      entityId={id}
                      variant="overworld"
                      onUpload={() => setSpriteRev((r) => r + 1)}
                    />
                  </div>
                  <div>
                    <Label className="text-parchment/60 text-xs mb-2 block">Battle Sprite</Label>
                    <ImageUpload
                      allowedTypes={['character']}
                      entityId={id}
                      variant="battle"
                      onUpload={() => setSpriteRev((r) => r + 1)}
                    />
                  </div>
                </div>
              )}

              <Separator className="bg-stone-light/30" />

              {/* Animation uploads */}
              <div>
                <Label className="text-parchment/60 text-xs mb-2 block">Add Animation</Label>
                <ImageUpload
                  allowedTypes={['sprite2d', 'player']}
                  entityId={id}
                  onUpload={() => setSpriteRev((r) => r + 1)}
                />
              </div>

              {/* List existing animations */}
              <AnimationList creatureId={id} rev={spriteRev} />
            </div>
          </CardContent>
        </Card>

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

        {/* Sounds */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Sounds</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {(form.sounds ?? []).map((entry, i) => (
                <SoundRow
                  key={i}
                  entry={entry}
                  characterId={id}
                  onUpdate={(updated) => {
                    const next = [...(form.sounds ?? [])]
                    next[i] = updated
                    update({ sounds: next })
                  }}
                  onDelete={() => {
                    const next = (form.sounds ?? []).filter((_, j) => j !== i)
                    update({ sounds: next })
                  }}
                />
              ))}
              <Button
                variant="ghost"
                size="sm"
                onClick={() =>
                  update({ sounds: [...(form.sounds ?? []), { type: 'attack', path: '' }] })
                }
                className="text-gold/70 hover:text-gold"
              >
                <Plus className="size-3.5" />
                Add Sound
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
        {/* Battle Configuration — shown for NPCs */}
        {form.category === 'npc' && (
          <Card className="bg-stone/30 border-stone-light/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-gold font-heading text-base">Battle Configuration</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-4">
                {/* Hostile toggle */}
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={form.is_hostile ?? false}
                    onChange={(e) => update({ is_hostile: e.target.checked })}
                    className="rounded border-stone-light/30"
                  />
                  <span className="text-sm text-parchment/80">Is Hostile?</span>
                </label>

                {form.is_hostile && (
                  <>
                    {/* Lead Creature */}
                    <div>
                      <Label className="text-parchment/60 text-xs">Lead Creature (recruitable by player after defeat)</Label>
                      <div className="flex gap-2 mt-1">
                        <select
                          value={form.lead_creature?.creature_id ?? ''}
                          onChange={(e) => {
                            if (e.target.value) {
                              update({ lead_creature: { creature_id: e.target.value, level: form.lead_creature?.level ?? 5 } })
                            } else {
                              update({ lead_creature: null as unknown as RosterEntry })
                            }
                          }}
                          className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                        >
                          <option value="" className="bg-stone text-parchment">None</option>
                          {creatureOptions.map(([cId, c]) => (
                            <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                          ))}
                        </select>
                        {form.lead_creature && (
                          <Input
                            type="number"
                            value={form.lead_creature.level}
                            onChange={(e) => update({ lead_creature: { ...form.lead_creature!, level: Number(e.target.value) } })}
                            className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                            placeholder="Lvl"
                            min={1}
                          />
                        )}
                      </div>
                    </div>

                    {/* Party */}
                    <div>
                      <Label className="text-parchment/60 text-xs">Party</Label>
                      <div className="space-y-2 mt-1">
                        {(form.roster ?? []).map((entry, i) => (
                          <div key={i} className="flex items-center gap-2">
                            <select
                              value={entry.creature_id}
                              onChange={(e) => {
                                const next = [...(form.roster ?? [])]
                                next[i] = { ...next[i], creature_id: e.target.value }
                                update({ roster: next })
                              }}
                              className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                            >
                              <option value="" className="bg-stone text-parchment">Select creature...</option>
                              {creatureOptions.map(([cId, c]) => (
                                <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                              ))}
                            </select>
                            <Input
                              type="number"
                              value={entry.level}
                              onChange={(e) => {
                                const next = [...(form.roster ?? [])]
                                next[i] = { ...next[i], level: Number(e.target.value) }
                                update({ roster: next })
                              }}
                              className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                              placeholder="Lvl"
                              min={1}
                            />
                            <Button
                              variant="ghost"
                              size="icon-xs"
                              onClick={() => update({ roster: (form.roster ?? []).filter((_, j) => j !== i) })}
                              className="text-parchment/40 hover:text-destructive"
                            >
                              <Trash2 className="size-3" />
                            </Button>
                          </div>
                        ))}
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => update({ roster: [...(form.roster ?? []), { creature_id: '', level: 5 }] })}
                          className="text-gold/70 hover:text-gold"
                        >
                          <Plus className="size-3.5" />
                          Add Party Member
                        </Button>
                      </div>
                    </div>

                    {/* Reserves */}
                    <div>
                      <Label className="text-parchment/60 text-xs">Reserves (max 3)</Label>
                      <div className="space-y-2 mt-1">
                        {(form.reserves ?? []).map((entry, i) => (
                          <div key={i} className="flex items-center gap-2">
                            <select
                              value={entry.creature_id}
                              onChange={(e) => {
                                const next = [...(form.reserves ?? [])]
                                next[i] = { ...next[i], creature_id: e.target.value }
                                update({ reserves: next })
                              }}
                              className="flex-1 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
                            >
                              <option value="" className="bg-stone text-parchment">Select creature...</option>
                              {creatureOptions.map(([cId, c]) => (
                                <option key={cId} value={cId} className="bg-stone text-parchment">{c.name}</option>
                              ))}
                            </select>
                            <Input
                              type="number"
                              value={entry.level}
                              onChange={(e) => {
                                const next = [...(form.reserves ?? [])]
                                next[i] = { ...next[i], level: Number(e.target.value) }
                                update({ reserves: next })
                              }}
                              className="w-16 bg-stone/50 border-stone-light/30 text-parchment text-center text-sm h-7"
                              placeholder="Lvl"
                              min={1}
                            />
                            <Button
                              variant="ghost"
                              size="icon-xs"
                              onClick={() => update({ reserves: (form.reserves ?? []).filter((_, j) => j !== i) })}
                              className="text-parchment/40 hover:text-destructive"
                            >
                              <Trash2 className="size-3" />
                            </Button>
                          </div>
                        ))}
                        {(form.reserves ?? []).length < 3 && (
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => update({ reserves: [...(form.reserves ?? []), { creature_id: '', level: 5 }] })}
                            className="text-gold/70 hover:text-gold"
                          >
                            <Plus className="size-3.5" />
                            Add Reserve
                          </Button>
                        )}
                      </div>
                    </div>
                  </>
                )}
              </div>
            </CardContent>
          </Card>
        )}
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

const SOUND_TYPES = ['attack', 'defend', 'greet'] as const

function SoundRow({
  entry,
  characterId,
  onUpdate,
  onDelete,
}: {
  entry: SoundEntry
  characterId: string
  onUpdate: (entry: SoundEntry) => void
  onDelete: () => void
}) {
  const fileRef = useRef<HTMLInputElement>(null)

  const handleUpload = async (file: File) => {
    const ext = file.name.split('.').pop() ?? 'mp3'
    const path = `assets/audio/sfx/${characterId}_${entry.type}.${ext}`
    const formData = new FormData()
    formData.append('file', file)
    try {
      const res = await fetch(`${BASE}/assets/upload/${path}`, { method: 'POST', body: formData })
      if (!res.ok) throw new Error(`Upload failed: ${res.status}`)
      const result = await res.json()
      const finalPath = result.path ?? path
      onUpdate({ ...entry, path: `res://${finalPath}` })
      toast.success(`${entry.type} sound uploaded`)
    } catch (err) {
      toast.error(`Upload failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  const filename = entry.path ? entry.path.split('/').pop() : null

  return (
    <div className="flex items-center gap-2">
      <select
        value={entry.type}
        onChange={(e) => onUpdate({ ...entry, type: e.target.value })}
        className="w-24 bg-stone/50 border border-stone-light/30 text-parchment text-sm h-7 rounded-md px-2"
      >
        {SOUND_TYPES.map((t) => (
          <option key={t} value={t} className="bg-stone text-parchment">
            {t}
          </option>
        ))}
      </select>
      <div className="flex-1 flex items-center gap-2 min-w-0">
        {filename ? (
          <span className="text-xs text-parchment/60 font-mono truncate">{filename}</span>
        ) : (
          <span className="text-xs text-parchment/30 italic">No file</span>
        )}
        {entry.path && (
          <Button
            variant="ghost"
            size="icon-xs"
            title="Play"
            onClick={() => {
              const audioPath = entry.path.replace('res://', '')
              const audio = new Audio(`${BASE}/assets/file/${audioPath}`)
              audio.play()
            }}
            className="text-parchment/40 hover:text-gold shrink-0"
          >
            <Volume2 className="size-3" />
          </Button>
        )}
      </div>
      <input
        ref={fileRef}
        type="file"
        accept=".mp3,.ogg,.wav"
        className="hidden"
        onChange={(e) => {
          const f = e.target.files?.[0]
          if (f) handleUpload(f)
          e.target.value = ''
        }}
      />
      <Button
        variant="ghost"
        size="icon-xs"
        title="Upload sound"
        onClick={() => fileRef.current?.click()}
        className="text-parchment/40 hover:text-gold shrink-0"
      >
        <Upload className="size-3" />
      </Button>
      <Button
        variant="ghost"
        size="icon-xs"
        onClick={onDelete}
        className="text-parchment/40 hover:text-destructive shrink-0"
      >
        <Trash2 className="size-3" />
      </Button>
    </div>
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

function AnimationList({ creatureId, rev }: { creatureId: string; rev: number }) {
  const [animations, setAnimations] = useState<AnimationInfo[]>([])

  useEffect(() => {
    assetsApi.listAnimations(creatureId).then(setAnimations).catch(() => setAnimations([]))
  }, [creatureId, rev])

  if (animations.length === 0) return null

  return (
    <div className="space-y-2">
      <Label className="text-parchment/60 text-xs">Existing Animations</Label>
      {animations.map((anim) => (
        <div
          key={anim.name}
          className="flex items-center gap-3 rounded-md border border-stone-light/20 bg-stone/20 px-3 py-2"
        >
          <div className="size-10 rounded bg-stone-light/10 border border-stone-light/20 flex items-center justify-center overflow-hidden">
            <img
              src={assetsApi.thumbnailUrl(
                `assets/sprites/creatures/${creatureId}/${anim.name}/spritesheet.png`,
                64,
              )}
              alt={anim.name}
              className="size-8 object-contain"
              style={{ imageRendering: 'pixelated' }}
              onError={(e) => { (e.target as HTMLImageElement).style.display = 'none' }}
            />
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-sm text-parchment font-mono">{anim.name}</p>
            <p className="text-xs text-parchment/40">
              {anim.meta.frame_count} frames, {anim.meta.fps} FPS, {anim.meta.frame_width}x{anim.meta.frame_height}px
              {anim.meta.loop ? ', loop' : ''}
            </p>
          </div>
          <span className={`text-xs ${anim.has_tres ? 'text-green-400' : 'text-amber-400'}`}>
            {anim.has_tres ? '.tres' : 'no .tres'}
          </span>
        </div>
      ))}
    </div>
  )
}
