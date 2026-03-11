import { get, put, post } from './client'

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
  sprite_overworld?: string
  sprite_battle?: string
}

export const creaturesApi = {
  list: () => get<Record<string, Creature>>('/creatures/'),
  getOne: (id: string) => get<Creature>(`/creatures/${id}`),
  update: (id: string, data: Creature) => put<Creature>(`/creatures/${id}`, data),
  autoMatchSprites: () => get<Record<string, { overworld: string | null; battle: string | null }>>('/creatures/auto-match-sprites'),
  applySprites: (matches: Record<string, { overworld: string | null; battle: string | null }>) =>
    post('/creatures/apply-sprite-matches', { matches }),
}
