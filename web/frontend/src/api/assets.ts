import { get, post, httpDelete, BASE } from './client'

export interface AssetInfo {
  path: string
  filename: string
  category: string
  size_bytes: number
  width?: number
  height?: number
  status: string
  notes: string
}

export const assetsApi = {
  list: (category?: string) =>
    get<AssetInfo[]>(`/assets/${category ? `?category=${category}` : ''}`),
  summary: () => get<Record<string, number>>('/assets/summary'),
  thumbnailUrl: (path: string, size = 128) =>
    `${BASE}/assets/thumbnail/${path}?size=${size}`,
  fileUrl: (path: string) => `${BASE}/assets/file/${path}`,
  updateStatus: (path: string, status: string, notes = '') =>
    fetch(`${BASE}/assets/status/${path}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status, notes }),
    }),
  upload: (path: string, file: File) => {
    const fd = new FormData()
    fd.append('file', file)
    return fetch(`${BASE}/assets/upload/${path}`, { method: 'POST', body: fd })
  },
  delete: (path: string) => httpDelete(`/assets/${path}`),
  rename: (oldPath: string, newPath: string) =>
    post('/assets/rename', { old_path: oldPath, new_path: newPath }),
}
