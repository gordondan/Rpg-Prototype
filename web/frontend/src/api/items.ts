import { get, put } from './client'

export interface Item {
  name: string
  description: string
  price: number
  effect: { type: string; amount?: number }
}

export const itemsApi = {
  list: () => get<Record<string, Item>>('/items/'),
  update: (id: string, data: Item) => put<Item>(`/items/${id}`, data),
}
