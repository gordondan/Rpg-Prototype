import { get, put } from './client'

export interface Move {
  name: string
  type: string
  category: string
  power: number
  accuracy: number
  pp: number
  description: string
  effect?: { stat?: string; stages?: number; target?: string; status?: string }
  effect_chance?: number
  priority?: number
}

export const movesApi = {
  list: () => get<Record<string, Move>>('/moves/'),
  getOne: (id: string) => get<Move>(`/moves/${id}`),
  update: (id: string, data: Move) => put<Move>(`/moves/${id}`, data),
}
