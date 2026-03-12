import { useEffect, useState } from 'react'
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '@/components/ui/sheet'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { gitApi, type CommitInfo } from '@/api/git'
import { GitCommitHorizontal, RotateCcw, FileText } from 'lucide-react'
import { toast } from 'sonner'

export default function HistoryPanel({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [commits, setCommits] = useState<CommitInfo[]>([])
  const [loading, setLoading] = useState(false)
  const [diffSha, setDiffSha] = useState<string | null>(null)
  const [diffText, setDiffText] = useState('')

  useEffect(() => {
    if (open) {
      setLoading(true)
      gitApi
        .history(30)
        .then(setCommits)
        .catch(() => toast.error('Failed to load history'))
        .finally(() => setLoading(false))
    }
  }, [open])

  const viewDiff = async (sha: string) => {
    try {
      const result = await gitApi.diff(sha)
      setDiffText(result.diff)
      setDiffSha(sha)
    } catch {
      toast.error('Failed to load diff')
    }
  }

  const revertCommit = async (sha: string) => {
    try {
      await gitApi.revert(sha)
      toast.success('Commit reverted')
      const h = await gitApi.history(30)
      setCommits(h)
    } catch {
      toast.error('Revert failed')
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-[480px] sm:max-w-[480px] bg-dark-slate border-stone-light/30">
        <SheetHeader>
          <SheetTitle className="text-gold font-heading">Commit History</SheetTitle>
          <SheetDescription className="text-parchment/60">
            Recent changes to game data files
          </SheetDescription>
        </SheetHeader>

        <ScrollArea className="flex-1 mt-4 px-4">
          {loading && <p className="text-parchment/50 text-sm">Loading...</p>}

          {diffSha && (
            <div className="mb-4">
              <div className="flex items-center justify-between mb-2">
                <span className="text-sm font-medium text-gold">Diff: {diffSha.slice(0, 7)}</span>
                <Button variant="ghost" size="xs" onClick={() => setDiffSha(null)} className="text-parchment/60">
                  Close
                </Button>
              </div>
              <pre className="bg-stone p-3 rounded-md text-xs text-parchment/80 overflow-x-auto whitespace-pre-wrap max-h-[300px] overflow-y-auto">
                {diffText || 'No changes'}
              </pre>
            </div>
          )}

          <div className="flex flex-col gap-2 pb-4">
            {commits.map((c) => (
              <div
                key={c.sha}
                className="rounded-lg border border-stone-light/30 bg-stone/50 p-3"
              >
                <div className="flex items-start gap-2">
                  <GitCommitHorizontal className="size-4 text-gold/70 mt-0.5 shrink-0" />
                  <div className="flex-1 min-w-0">
                    <p className="text-sm text-parchment font-medium truncate">{c.message}</p>
                    <p className="text-xs text-parchment/50 mt-0.5">
                      {c.sha.slice(0, 7)} &middot; {c.author} &middot;{' '}
                      {new Date(c.date).toLocaleDateString()}
                    </p>
                    {c.files.length > 0 && (
                      <div className="flex flex-wrap gap-1 mt-1.5">
                        {c.files.slice(0, 3).map((f) => (
                          <Badge key={f} variant="outline" className="text-xs text-parchment/60 border-stone-light/40">
                            {f.split('/').pop()}
                          </Badge>
                        ))}
                        {c.files.length > 3 && (
                          <span className="text-xs text-parchment/40">+{c.files.length - 3}</span>
                        )}
                      </div>
                    )}
                  </div>
                </div>
                <div className="flex gap-1 mt-2 ml-6">
                  <Button
                    variant="ghost"
                    size="xs"
                    onClick={() => viewDiff(c.sha)}
                    className="text-parchment/60 hover:text-parchment"
                  >
                    <FileText className="size-3" />
                    Diff
                  </Button>
                  <Button
                    variant="ghost"
                    size="xs"
                    onClick={() => revertCommit(c.sha)}
                    className="text-parchment/60 hover:text-destructive"
                  >
                    <RotateCcw className="size-3" />
                    Revert
                  </Button>
                </div>
              </div>
            ))}
          </div>
        </ScrollArea>
      </SheetContent>
    </Sheet>
  )
}
