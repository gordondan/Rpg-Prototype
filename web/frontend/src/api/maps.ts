import { get, put } from './client'

export interface GameMap {
  name: string
  description: string
  encounters: { creature_id: string; level_min: number; level_max: number; weight: number }[]
}

export const mapsApi = {
  list: () => get<Record<string, GameMap>>('/maps/'),
  update: (id: string, data: GameMap) => put<GameMap>(`/maps/${id}`, data),
}
