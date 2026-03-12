import { Badge } from '@/components/ui/badge'
import { CheckCircle2, Clock, AlertTriangle, Archive } from 'lucide-react'

interface Props {
  summary: Record<string, number>
}

const statusConfig = [
  { key: 'active', label: 'Active', icon: CheckCircle2, color: 'text-green-400 bg-green-400/10' },
  { key: 'in_development', label: 'In Dev', icon: Clock, color: 'text-yellow-400 bg-yellow-400/10' },
  { key: 'needs_review', label: 'Review', icon: AlertTriangle, color: 'text-orange-400 bg-orange-400/10' },
  { key: 'deprecated', label: 'Deprecated', icon: Archive, color: 'text-red-400 bg-red-400/10' },
]

export default function DashboardBar({ summary }: Props) {
  const total = Object.values(summary).reduce((a, b) => a + b, 0)

  return (
    <div className="flex items-center gap-3 p-4 border-b border-stone-light/30">
      <Badge className="bg-gold/20 text-gold border-0 text-sm px-3 py-1">
        {total} Assets
      </Badge>
      <div className="flex gap-2">
        {statusConfig.map(({ key, label, icon: Icon, color }) => {
          const count = summary[key] ?? 0
          if (count === 0) return null
          return (
            <div key={key} className={`flex items-center gap-1.5 rounded-md px-2 py-1 ${color}`}>
              <Icon className="size-3.5" />
              <span className="text-xs font-medium">{count} {label}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}
