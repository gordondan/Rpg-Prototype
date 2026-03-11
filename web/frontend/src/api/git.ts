import { get, post } from './client'

export interface GitStatus {
  has_changes: boolean
  changed_files: string[]
}

export interface CommitInfo {
  sha: string
  message: string
  author: string
  date: string
  files: string[]
}

export const gitApi = {
  status: () => get<GitStatus>('/git/status'),
  commit: (message: string) =>
    post<{ status: string; sha: string }>('/git/commit', { message }),
  history: (limit = 50) => get<CommitInfo[]>(`/git/history?limit=${limit}`),
  diff: (sha?: string) =>
    get<{ diff: string }>(sha ? `/git/diff?sha=${sha}` : '/git/diff'),
  revert: (sha: string) => post(`/git/revert/${sha}`),
}
