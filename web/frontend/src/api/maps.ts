import { get, put, post, httpDelete } from './client'

export interface GameMap {
  name: string
  description: string
  encounters: { creature_id: string; level_min: number; level_max: number; weight: number }[]
}

export const mapsApi = {
  list: () => get<Record<string, GameMap>>('/maps/'),
  create: (id: string, data: GameMap) => post<{ status: string; map_id: string }>('/maps/', { id, ...data }),
  update: (id: string, data: GameMap) => put<GameMap>(`/maps/${id}`, data),
  delete: (id: string) => httpDelete<{ status: string }>(`/maps/${id}`),
}
