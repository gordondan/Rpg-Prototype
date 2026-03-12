import { NavLink } from 'react-router-dom'
import { useState } from 'react'
import {
  Sword,
  Zap,
  Package,
  Map,
  Store,
  ImageIcon,
  GalleryHorizontalEnd,
  ChevronRight,
  ChevronLeft,
  PawPrint,
  ScrollText,
  Users,
} from 'lucide-react'
import { cn } from '@/lib/utils'
import { ScrollArea } from '@/components/ui/scroll-area'
import { Button } from '@/components/ui/button'

const dataEditorLinks = [
  { to: '/editor/creatures', label: 'Creatures', icon: PawPrint },
  { to: '/editor/npcs', label: 'NPCs', icon: Users },
  { to: '/editor/moves', label: 'Moves', icon: Zap },
  { to: '/editor/items', label: 'Items', icon: Package },
  { to: '/editor/maps', label: 'Maps', icon: Map },
  { to: '/editor/shops', label: 'Shops', icon: Store },
  { to: '/editor/quests', label: 'Quests', icon: ScrollText },
]

const mainLinks = [
  { to: '/assets', label: 'Asset Manager', icon: ImageIcon },
  { to: '/gallery', label: 'Gallery', icon: GalleryHorizontalEnd },
]

export default function Sidebar({
  collapsed,
  onToggle,
}: {
  collapsed: boolean
  onToggle: () => void
}) {
  const [dataOpen, setDataOpen] = useState(true)

  return (
    <aside
      className={cn(
        'flex flex-col border-r border-stone-light/30 bg-dark-slate transition-all duration-200',
        collapsed ? 'w-[60px]' : 'w-[250px]'
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between border-b border-stone-light/30 px-3 py-4">
        {!collapsed && (
          <h1 className="font-heading text-lg font-bold text-gold tracking-wide">
            MonsterQuest
          </h1>
        )}
        <Button
          variant="ghost"
          size="icon-sm"
          onClick={onToggle}
          className="text-gold/70 hover:text-gold hover:bg-stone-light/30"
        >
          {collapsed ? <ChevronRight className="size-4" /> : <ChevronLeft className="size-4" />}
        </Button>
      </div>

      <ScrollArea className="flex-1">
        <nav className="flex flex-col gap-1 p-2">
          {/* Data Editor section */}
          {!collapsed && (
            <button
              onClick={() => setDataOpen(!dataOpen)}
              className="flex items-center gap-2 rounded-md px-2 py-1.5 text-xs font-semibold uppercase tracking-wider text-gold-dim hover:text-gold transition-colors"
            >
              <Sword className="size-3.5" />
              Data Editor
              <ChevronRight
                className={cn(
                  'ml-auto size-3.5 transition-transform',
                  dataOpen && 'rotate-90'
                )}
              />
            </button>
          )}

          {(dataOpen || collapsed) &&
            dataEditorLinks.map((link) => (
              <NavLink
                key={link.to}
                to={link.to}
                className={({ isActive }) =>
                  cn(
                    'flex items-center gap-2 rounded-md px-2 py-1.5 text-sm transition-colors',
                    collapsed && 'justify-center px-0',
                    isActive
                      ? 'bg-gold/15 text-gold font-medium'
                      : 'text-parchment/70 hover:text-parchment hover:bg-stone-light/30'
                  )
                }
                title={collapsed ? link.label : undefined}
              >
                <link.icon className="size-4 shrink-0" />
                {!collapsed && link.label}
              </NavLink>
            ))}

          {/* Separator */}
          <div className="mx-2 my-2 h-px bg-stone-light/30" />

          {/* Main links */}
          {mainLinks.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) =>
                cn(
                  'flex items-center gap-2 rounded-md px-2 py-1.5 text-sm transition-colors',
                  collapsed && 'justify-center px-0',
                  isActive
                    ? 'bg-gold/15 text-gold font-medium'
                    : 'text-parchment/70 hover:text-parchment hover:bg-stone-light/30'
                )
              }
              title={collapsed ? link.label : undefined}
            >
              <link.icon className="size-4 shrink-0" />
              {!collapsed && link.label}
            </NavLink>
          ))}
        </nav>
      </ScrollArea>
    </aside>
  )
}
