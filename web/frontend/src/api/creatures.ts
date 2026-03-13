import { get, put, post, httpDelete } from './client'

export interface DialogueChoice {
  text: string
  id: string
  next: DialogueLine[]
}

export interface DialogueLine {
  text: string
  speaker: string
  choices?: DialogueChoice[]
}

export interface DialogueEntry {
  lines: DialogueLine[]
}

export interface SoundEntry {
  type: string // attack, defend, greet
  path: string
}

export interface RosterEntry {
  creature_id: string
  level: number
}

export interface Creature {
  name: string
  description: string
  types: string[]
  base_hp: number
  base_attack: number
  base_defense: number
  base_sp_attack: number
  base_sp_defense: number
  base_speed: number
  base_exp: number
  class: string
  category: string
  evolution?: { creature_id: string; level: number; flavor: string }
  recruit_method?: string
  recruit_chance?: number
  recruit_dialogue?: string
  has_overworld_sprite?: boolean
  has_battle_sprite?: boolean
  learnset: { level: number; move_id: string }[]
  sounds: SoundEntry[]
  npc_sprite?: string
  dialogues?: Record<string, DialogueEntry>
  is_hostile?: boolean
  lead_creature?: RosterEntry | null
  roster?: RosterEntry[]
  reserves?: RosterEntry[]
}

/** Convention-based sprite paths derived from creature ID */
export function spritePath(creatureId: string, variant: 'overworld' | 'battle' = 'overworld'): string {
  const file = variant === 'battle' ? `${creatureId}_battle.png` : `${creatureId}.png`
  return `assets/sprites/creatures/${file}`
}

export const creaturesApi = {
  list: () => get<Record<string, Creature>>('/creatures/'),
  getOne: (id: string) => get<Creature>(`/creatures/${id}`),
  update: (id: string, data: Creature) => put<Creature>(`/creatures/${id}`, data),
  create: (category?: string) => post<{ status: string; creature_id: string }>(`/creatures/${category ? `?category=${category}` : ''}`),
  delete: (id: string) => httpDelete<{ status: string }>(`/creatures/${id}`),
  getViewOrder: () => get<string[]>('/creatures/view-order'),
  selectViewOrder: (id: string) => put<string[]>(`/creatures/view-order/${id}`, {}),
}
