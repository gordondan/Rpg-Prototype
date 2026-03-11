import { get, put, post, httpDelete } from './client'

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
  create: () => post<{ status: string; creature_id: string }>('/creatures/'),
  delete: (id: string) => httpDelete<{ status: string }>(`/creatures/${id}`),
}
