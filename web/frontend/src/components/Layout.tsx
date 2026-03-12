import { useState } from 'react'
import { Outlet } from 'react-router-dom'
import Sidebar from './Sidebar'
import ChangeBar from './ChangeBar'
import HistoryPanel from './HistoryPanel'
import { Toaster } from 'sonner'

export default function Layout() {
  const [collapsed, setCollapsed] = useState(false)
  const [historyOpen, setHistoryOpen] = useState(false)

  return (
    <div className="flex h-screen bg-dark-slate text-parchment">
      <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
      <div className="flex flex-1 flex-col overflow-hidden">
        <main className="flex-1 overflow-auto bg-stone/30">
          <Outlet />
        </main>
        <ChangeBar onOpenHistory={() => setHistoryOpen(true)} />
      </div>
      <HistoryPanel open={historyOpen} onOpenChange={setHistoryOpen} />
      <Toaster
        theme="dark"
        toastOptions={{
          style: {
            background: '#2a2540',
            border: '1px solid #3d3655',
            color: '#f5f0e8',
          },
        }}
      />
    </div>
  )
}
