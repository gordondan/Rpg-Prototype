import { useState, useEffect } from 'react'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Button } from '@/components/ui/button'
import { Separator } from '@/components/ui/separator'
import { Plus, Trash2 } from 'lucide-react'
import { questsApi, type Quest, type QuestStage } from '@/api/quests'
import { useChanges } from '@/context/ChangeContext'
import { toast } from 'sonner'

const STAGE_TYPES: QuestStage['type'][] = [
  'talk_to_npc',
  'defeat_creatures',
  'collect_items',
  'reach_location',
  'boss_encounter',
]

interface Props {
  id: string
  quest: Quest
  onDelete?: () => void
}

export default function QuestForm({ id, quest: initial, onDelete }: Props) {
  const [form, setForm] = useState<Quest>(initial)
  const { markChanged } = useChanges()

  useEffect(() => {
    setForm(initial)
  }, [initial])

  const update = (patch: Partial<Quest>) => {
    const next = { ...form, ...patch }
    setForm(next)
    markChanged('quests', id, next, `${next.name}`)
  }

  const updateStage = (index: number, patch: Partial<QuestStage>) => {
    const next = [...form.stages]
    next[index] = { ...next[index], ...patch }
    update({ stages: next })
  }

  const addStage = () => {
    update({
      stages: [
        ...form.stages,
        { id: '', type: 'talk_to_npc', description: '' },
      ],
    })
  }

  const removeStage = (index: number) => {
    update({ stages: form.stages.filter((_, i) => i !== index) })
  }

  const addRewardItem = () => {
    update({ reward: { ...form.reward, items: [...form.reward.items, ''] } })
  }

  const removeRewardItem = (index: number) => {
    update({
      reward: {
        ...form.reward,
        items: form.reward.items.filter((_, i) => i !== index),
      },
    })
  }

  const updateRewardItem = (index: number, value: string) => {
    const items = [...form.reward.items]
    items[index] = value
    update({ reward: { ...form.reward, items } })
  }

  const handleDelete = async () => {
    if (!window.confirm(`Delete quest "${form.name}" (${id})? This cannot be undone.`)) return
    try {
      await questsApi.delete(id)
      toast.success(`Quest "${form.name}" deleted`)
      onDelete?.()
    } catch (err) {
      toast.error(`Failed to delete quest: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  return (
    <ScrollArea className="h-full">
      <div className="p-6 space-y-6 max-w-3xl">
        {/* Identity */}
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
          <div className="grid grid-cols-2 gap-3">
            <div>
              <Label className="text-parchment/60 text-xs">Map ID</Label>
              <Input
                value={form.map_id}
                onChange={(e) => update({ map_id: e.target.value })}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
              />
            </div>
            <div>
              <Label className="text-parchment/60 text-xs">Prerequisite Quest ID</Label>
              <Input
                value={form.prerequisite_quest_id ?? ''}
                onChange={(e) => update({ prerequisite_quest_id: e.target.value || null })}
                className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                placeholder="(none)"
              />
            </div>
          </div>
        </div>

        <Separator className="bg-stone-light/30" />

        {/* Reward */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Reward</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <Label className="text-parchment/60 text-xs">Gold</Label>
                  <Input
                    type="number"
                    value={form.reward.gold}
                    onChange={(e) => update({ reward: { ...form.reward, gold: Number(e.target.value) } })}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                  />
                </div>
                <div>
                  <Label className="text-parchment/60 text-xs">EXP</Label>
                  <Input
                    type="number"
                    value={form.reward.exp}
                    onChange={(e) => update({ reward: { ...form.reward, exp: Number(e.target.value) } })}
                    className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                  />
                </div>
              </div>
              <div>
                <Label className="text-parchment/60 text-xs">Items</Label>
                <div className="space-y-1.5 mt-1">
                  {form.reward.items.map((item, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <Input
                        value={item}
                        onChange={(e) => updateRewardItem(i, e.target.value)}
                        className="flex-1 bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        placeholder="Item ID"
                      />
                      <Button
                        variant="ghost"
                        size="icon-xs"
                        onClick={() => removeRewardItem(i)}
                        className="text-parchment/40 hover:text-destructive"
                      >
                        <Trash2 className="size-3" />
                      </Button>
                    </div>
                  ))}
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={addRewardItem}
                    className="text-gold/70 hover:text-gold"
                  >
                    <Plus className="size-3.5" />
                    Add Item
                  </Button>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Stages */}
        <Card className="bg-stone/30 border-stone-light/30">
          <CardHeader className="pb-2">
            <CardTitle className="text-gold font-heading text-base">Stages</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {form.stages.map((stage, i) => (
                <div key={i} className="p-3 rounded-md bg-stone/50 border border-stone-light/20 space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-xs font-medium text-parchment/60">Stage {i + 1}</span>
                    <Button
                      variant="ghost"
                      size="icon-xs"
                      onClick={() => removeStage(i)}
                      className="text-parchment/40 hover:text-destructive"
                    >
                      <Trash2 className="size-3" />
                    </Button>
                  </div>
                  <div className="grid grid-cols-2 gap-2">
                    <div>
                      <Label className="text-parchment/60 text-xs">Stage ID</Label>
                      <Input
                        value={stage.id}
                        onChange={(e) => updateStage(i, { id: e.target.value })}
                        className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                      />
                    </div>
                    <div>
                      <Label className="text-parchment/60 text-xs">Type</Label>
                      <select
                        value={stage.type}
                        onChange={(e) => updateStage(i, { type: e.target.value as QuestStage['type'] })}
                        className="w-full h-7 rounded-md bg-stone/50 border border-stone-light/30 text-parchment text-sm px-2"
                      >
                        {STAGE_TYPES.map((t) => (
                          <option key={t} value={t}>
                            {t.replace(/_/g, ' ')}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                  <div>
                    <Label className="text-parchment/60 text-xs">Description</Label>
                    <Input
                      value={stage.description}
                      onChange={(e) => updateStage(i, { description: e.target.value })}
                      className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                    />
                  </div>

                  {/* Conditional fields based on type */}
                  {stage.type === 'talk_to_npc' && (
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <Label className="text-parchment/60 text-xs">NPC ID</Label>
                        <Input
                          value={stage.npc_id ?? ''}
                          onChange={(e) => updateStage(i, { npc_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                      <div>
                        <Label className="text-parchment/60 text-xs">Dialogue ID</Label>
                        <Input
                          value={stage.dialogue_id ?? ''}
                          onChange={(e) => updateStage(i, { dialogue_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                    </div>
                  )}

                  {stage.type === 'defeat_creatures' && (
                    <div className="grid grid-cols-3 gap-2">
                      <div>
                        <Label className="text-parchment/60 text-xs">Creature ID</Label>
                        <Input
                          value={stage.creature_id ?? ''}
                          onChange={(e) => updateStage(i, { creature_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                      <div>
                        <Label className="text-parchment/60 text-xs">Count</Label>
                        <Input
                          type="number"
                          value={stage.count ?? 1}
                          onChange={(e) => updateStage(i, { count: Number(e.target.value) })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                      <div>
                        <Label className="text-parchment/60 text-xs">Map ID (optional)</Label>
                        <Input
                          value={stage.map_id ?? ''}
                          onChange={(e) => updateStage(i, { map_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                    </div>
                  )}

                  {stage.type === 'collect_items' && (
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <Label className="text-parchment/60 text-xs">Item ID</Label>
                        <Input
                          value={stage.item_id ?? ''}
                          onChange={(e) => updateStage(i, { item_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                      <div>
                        <Label className="text-parchment/60 text-xs">Count</Label>
                        <Input
                          type="number"
                          value={stage.count ?? 1}
                          onChange={(e) => updateStage(i, { count: Number(e.target.value) })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                    </div>
                  )}

                  {stage.type === 'reach_location' && (
                    <div>
                      <Label className="text-parchment/60 text-xs">Map ID</Label>
                      <Input
                        value={stage.map_id ?? ''}
                        onChange={(e) => updateStage(i, { map_id: e.target.value })}
                        className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                      />
                    </div>
                  )}

                  {stage.type === 'boss_encounter' && (
                    <div className="grid grid-cols-2 gap-2">
                      <div>
                        <Label className="text-parchment/60 text-xs">Creature ID</Label>
                        <Input
                          value={stage.creature_id ?? ''}
                          onChange={(e) => updateStage(i, { creature_id: e.target.value })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                      <div>
                        <Label className="text-parchment/60 text-xs">Level</Label>
                        <Input
                          type="number"
                          value={stage.level ?? 1}
                          onChange={(e) => updateStage(i, { level: Number(e.target.value) })}
                          className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7"
                        />
                      </div>
                    </div>
                  )}
                </div>
              ))}

              <Button
                variant="ghost"
                size="sm"
                onClick={addStage}
                className="text-gold/70 hover:text-gold"
              >
                <Plus className="size-3.5" />
                Add Stage
              </Button>
            </div>
          </CardContent>
        </Card>

        {/* Delete */}
        <Button
          variant="ghost"
          size="sm"
          onClick={handleDelete}
          className="text-destructive hover:text-destructive hover:bg-destructive/10"
        >
          <Trash2 className="size-3.5" />
          Delete Quest
        </Button>
      </div>
    </ScrollArea>
  )
}
