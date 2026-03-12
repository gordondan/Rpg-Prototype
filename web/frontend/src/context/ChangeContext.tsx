import { createContext, useContext, useState, useCallback, type ReactNode } from 'react'
import { creaturesApi } from '@/api/creatures'
import { movesApi } from '@/api/moves'
import { itemsApi } from '@/api/items'
import { mapsApi } from '@/api/maps'
import { shopsApi } from '@/api/shops'
import { questsApi } from '@/api/quests'
import { gitApi } from '@/api/git'
import { toast } from 'sonner'

export interface Change {
  type: 'creatures' | 'moves' | 'items' | 'maps' | 'shops' | 'quests'
  id: string
  data: unknown
  label: string
}

interface ChangeContextValue {
  changes: Map<string, Change>
  changeCount: number
  markChanged: (type: Change['type'], id: string, data: unknown, label: string) => void
  discardAll: () => void
  saveAll: () => Promise<void>
  saving: boolean
}

const ChangeContext = createContext<ChangeContextValue | null>(null)

export function ChangeProvider({ children }: { children: ReactNode }) {
  const [changes, setChanges] = useState<Map<string, Change>>(new Map())
  const [saving, setSaving] = useState(false)

  const markChanged = useCallback((type: Change['type'], id: string, data: unknown, label: string) => {
    setChanges(prev => {
      const next = new Map(prev)
      next.set(`${type}:${id}`, { type, id, data, label })
      return next
    })
  }, [])

  const discardAll = useCallback(() => {
    setChanges(new Map())
  }, [])

  const saveAll = useCallback(async () => {
    setSaving(true)
    try {
      const entries = Array.from(changes.values())
      for (const change of entries) {
        switch (change.type) {
          case 'creatures':
            await creaturesApi.update(change.id, change.data as Parameters<typeof creaturesApi.update>[1])
            break
          case 'moves':
            await movesApi.update(change.id, change.data as Parameters<typeof movesApi.update>[1])
            break
          case 'items':
            await itemsApi.update(change.id, change.data as Parameters<typeof itemsApi.update>[1])
            break
          case 'maps':
            await mapsApi.update(change.id, change.data as Parameters<typeof mapsApi.update>[1])
            break
          case 'shops':
            await shopsApi.update(change.id, change.data as Parameters<typeof shopsApi.update>[1])
            break
          case 'quests':
            await questsApi.update(change.id, change.data as Parameters<typeof questsApi.update>[1])
            break
        }
      }
      const labels = entries.map(c => c.label)
      const message = `Update ${labels.join(', ')}`
      await gitApi.commit(message)
      setChanges(new Map())
      toast.success(`Saved ${entries.length} change(s) and committed`)
    } catch (err) {
      toast.error(`Save failed: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setSaving(false)
    }
  }, [changes])

  return (
    <ChangeContext.Provider value={{ changes, changeCount: changes.size, markChanged, discardAll, saveAll, saving }}>
      {children}
    </ChangeContext.Provider>
  )
}

export function useChanges() {
  const ctx = useContext(ChangeContext)
  if (!ctx) throw new Error('useChanges must be used within ChangeProvider')
  return ctx
}
