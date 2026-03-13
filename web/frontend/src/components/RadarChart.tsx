import {
  Radar,
  RadarChart as RechartsRadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  ResponsiveContainer,
} from 'recharts'
import { STAT_LABELS } from '@/theme/colors'

interface Props {
  stats: Record<string, number>
  color?: string
}

export default function StatRadarChart({ stats, color = '#c9a84c' }: Props) {
  const data = Object.entries(STAT_LABELS).map(([key, label]) => ({
    stat: label,
    value: stats[key] ?? 0,
    fullMark: 150,
  }))

  return (
    <ResponsiveContainer width="100%" height={220}>
      <RechartsRadarChart data={data} cx="50%" cy="50%" outerRadius="70%">
        <PolarGrid stroke="#3d3655" />
        <PolarAngleAxis dataKey="stat" tick={{ fill: '#f5f0e8', fontSize: 11 }} />
        <PolarRadiusAxis
          angle={90}
          domain={[0, 150]}
          tick={{ fill: '#8b7635', fontSize: 9 }}
          tickCount={4}
        />
        <Radar
          dataKey="value"
          stroke={color}
          fill={color}
          fillOpacity={0.25}
          strokeWidth={2}
        />
      </RechartsRadarChart>
    </ResponsiveContainer>
  )
}
