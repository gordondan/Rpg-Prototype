import { get, post, httpDelete, BASE } from './client'

export type ImageType = 'character' | 'sprite2d' | 'player' | 'map'

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

export interface GridDetection {
  detected: boolean
  frame_width: number
  frame_height: number
  columns: number
  rows: number
  frame_count: number
  confidence: number
  image_width: number
  image_height: number
}

export interface AnimationInfo {
  name: string
  meta: {
    frame_width: number
    frame_height: number
    columns: number
    rows: number
    frame_count: number
    fps: number
    loop: boolean
    animation_type: string
  }
  has_tres: boolean
  has_spritesheet: boolean
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
  upload: (path: string, file: File, imageType: ImageType = 'character') => {
    const fd = new FormData()
    fd.append('file', file)
    return fetch(`${BASE}/assets/upload/${path}?image_type=${imageType}`, { method: 'POST', body: fd })
  },
  delete: (path: string) => httpDelete(`/assets/${path}`),
  rename: (oldPath: string, newPath: string) =>
    post('/assets/rename', { old_path: oldPath, new_path: newPath }),
  analyzeSpriteSheet: (path: string) =>
    get<GridDetection>(`/assets/analyze-spritesheet/${path}`),
  generateAnimationResource: (params: {
    creature_id: string
    animation_name: string
    frame_width: number
    frame_height: number
    columns: number
    rows: number
    frame_count: number
    fps: number
    loop: boolean
    animation_type: string
  }) => post<{ status: string; tres_path: string }>('/assets/generate-animation-resource', params),
  listAnimations: (creatureId: string) =>
    get<AnimationInfo[]>(`/assets/animations/${creatureId}`),
}
