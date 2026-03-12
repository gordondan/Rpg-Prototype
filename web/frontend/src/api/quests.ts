import { get, put, post, httpDelete } from './client'

export interface QuestReward {
  gold: number
  items: string[]
  exp: number
}

export interface QuestStage {
  id: string
  type: 'talk_to_npc' | 'defeat_creatures' | 'collect_items' | 'reach_location' | 'boss_encounter'
  description: string
  npc_id?: string
  dialogue_id?: string
  creature_id?: string
  count?: number
  item_id?: string
  map_id?: string
  level?: number
}

export interface Quest {
  name: string
  description: string
  map_id: string
  prerequisite_quest_id?: string | null
  reward: QuestReward
  stages: QuestStage[]
}

export const questsApi = {
  list: () => get<Record<string, Quest>>('/quests/'),
  getOne: (id: string) => get<Quest>(`/quests/${id}`),
  create: (id: string, data: Quest) => post<{ status: string; quest_id: string }>('/quests/', { id, ...data }),
  update: (id: string, data: Quest) => put<Quest>(`/quests/${id}`, data),
  delete: (id: string) => httpDelete<{ status: string }>(`/quests/${id}`),
}
