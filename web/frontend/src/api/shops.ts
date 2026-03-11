import { get, put } from './client'

export interface Shop {
  name: string
  greeting: string
  items: string[]
}

export const shopsApi = {
  list: () => get<Record<string, Shop>>('/shops/'),
  update: (id: string, data: Shop) => put<Shop>(`/shops/${id}`, data),
}
