import { useState, useMemo } from 'react'
import { Input } from '@/components/ui/input'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Search, ScrollText, Plus } from 'lucide-react'
import { questsApi, type Quest } from '@/api/quests'
import { cn } from '@/lib/utils'
import { toast } from 'sonner'

interface Props {
  quests: Record<string, Quest>
  selectedId: string | null
  onSelect: (id: string) => void
  onRefresh?: () => void
}

export default function QuestsList({ quests, selectedId, onSelect, onRefresh }: Props) {
  const [search, setSearch] = useState('')
  const [creating, setCreating] = useState(false)
  const [newId, setNewId] = useState('')
  const [newName, setNewName] = useState('')
  const [newMapId, setNewMapId] = useState('')

  const filtered = useMemo(() => {
    const entries = Object.entries(quests)
    if (!search) return entries
    const q = search.toLowerCase()
    return entries.filter(
      ([id, quest]) =>
        quest.name.toLowerCase().includes(q) ||
        id.toLowerCase().includes(q) ||
        quest.map_id.toLowerCase().includes(q)
    )
  }, [quests, search])

  const handleCreate = async () => {
    if (!newId.trim() || !newName.trim()) return
    try {
      await questsApi.create(newId.trim(), {
        name: newName.trim(),
        description: '',
        map_id: newMapId.trim(),
        reward: { gold: 0, items: [], exp: 0 },
        stages: [],
      })
      toast.success(`Quest "${newName.trim()}" created`)
      setCreating(false)
      setNewId('')
      setNewName('')
      setNewMapId('')
      onRefresh?.()
    } catch (err) {
      toast.error(`Failed to create quest: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  return (
    <div className="flex flex-col h-full border-r border-stone-light/30">
      <div className="p-3 border-b border-stone-light/30 space-y-2">
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setCreating(!creating)}
          className="w-full text-gold/70 hover:text-gold justify-start"
        >
          <Plus className="size-3.5" />
          New Quest
        </Button>
        {creating && (
          <div className="space-y-1.5 p-2 rounded-md bg-stone/50 border border-stone-light/30">
            <Input
              placeholder="Quest ID (e.g. rescue_elder)"
              value={newId}
              onChange={(e) => setNewId(e.target.value)}
              className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 placeholder:text-parchment/30"
            />
            <Input
              placeholder="Quest Name"
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 placeholder:text-parchment/30"
            />
            <Input
              placeholder="Map ID"
              value={newMapId}
              onChange={(e) => setNewMapId(e.target.value)}
              className="bg-stone/50 border-stone-light/30 text-parchment text-sm h-7 placeholder:text-parchment/30"
            />
            <div className="flex gap-1.5">
              <Button size="sm" onClick={handleCreate} className="flex-1 bg-gold/20 text-gold hover:bg-gold/30 h-7 text-xs">
                Create
              </Button>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => { setCreating(false); setNewId(''); setNewName(''); setNewMapId('') }}
                className="text-parchment/50 h-7 text-xs"
              >
                Cancel
              </Button>
            </div>
          </div>
        )}
        <div className="relative">
          <Search className="absolute left-2 top-1/2 -translate-y-1/2 size-4 text-parchment/40" />
          <Input
            placeholder="Search quests..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-8 bg-stone/50 border-stone-light/30 text-parchment placeholder:text-parchment/30"
          />
        </div>
        <p className="text-xs text-parchment/40">
          {filtered.length} of {Object.keys(quests).length} quests
        </p>
      </div>
      <ScrollArea className="flex-1">
        <div className="flex flex-col gap-0.5 p-1.5">
          {filtered.map(([id, quest]) => (
            <button
              key={id}
              onClick={() => onSelect(id)}
              className={cn(
                'flex items-center gap-3 rounded-md px-3 py-2 text-left transition-colors',
                selectedId === id
                  ? 'bg-gold/15 text-gold'
                  : 'text-parchment/80 hover:bg-stone-light/20'
              )}
            >
              <ScrollText className="size-4 shrink-0 text-gold/50" />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium truncate">{quest.name}</p>
                <div className="flex gap-1 mt-0.5">
                  <Badge variant="outline" className="text-[10px] text-parchment/50 border-stone-light/40">
                    {quest.map_id || 'no map'}
                  </Badge>
                  <Badge variant="outline" className="text-[10px] text-parchment/50 border-stone-light/40">
                    {quest.stages.length} stage{quest.stages.length !== 1 ? 's' : ''}
                  </Badge>
                </div>
              </div>
            </button>
          ))}
        </div>
      </ScrollArea>
    </div>
  )
}
