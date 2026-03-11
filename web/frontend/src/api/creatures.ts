import { get, put } from './client'

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
  evolution?: { creature_id: string; level: number; flavor: string }
  recruit_method?: string
  recruit_chance?: number
  recruit_dialogue?: string
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
}
