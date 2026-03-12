import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Layout from './components/Layout'
import DataEditor from './pages/DataEditor'
import AssetManager from './pages/AssetManager'
import Gallery from './pages/Gallery'
import { ChangeProvider } from './context/ChangeContext'

function App() {
  return (
    <ChangeProvider>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route path="/" element={<Navigate to="/editor/creatures" replace />} />
            <Route path="/editor/:category/:id?" element={<DataEditor />} />
            <Route path="/assets/*" element={<AssetManager />} />
            <Route path="/gallery" element={<Gallery />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </ChangeProvider>
  )
}

export default App
