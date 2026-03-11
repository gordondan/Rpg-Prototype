import { useParams } from 'react-router-dom'
import { useState, useEffect, useCallback } from 'react'
import { creaturesApi, type Creature } from '@/api/creatures'
import { movesApi, type Move } from '@/api/moves'
import { itemsApi, type Item } from '@/api/items'
import { mapsApi, type GameMap } from '@/api/maps'
import { shopsApi, type Shop } from '@/api/shops'
import CreatureList from './CreatureList'
import CreatureForm from './CreatureForm'
import MovesList from './MovesList'
import MoveForm from './MoveForm'
import ItemsList from './ItemsList'
import ItemForm from './ItemForm'
import MapsList from './MapsList'
import MapForm from './MapForm'
import ShopsList from './ShopsList'
import ShopForm from './ShopForm'
import { toast } from 'sonner'

export default function DataEditor() {
  const { category } = useParams<{ category: string }>()
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const [creatures, setCreatures] = useState<Record<string, Creature>>({})
  const [moves, setMoves] = useState<Record<string, Move>>({})
  const [items, setItems] = useState<Record<string, Item>>({})
  const [maps, setMaps] = useState<Record<string, GameMap>>({})
  const [shops, setShops] = useState<Record<string, Shop>>({})
  const [loading, setLoading] = useState(false)

  const loadData = useCallback(async () => {
    setLoading(true)
    setSelectedId(null)
    try {
      switch (category) {
        case 'creatures': {
          const data = await creaturesApi.list()
          setCreatures(data)
          break
        }
        case 'moves': {
          const data = await movesApi.list()
          setMoves(data)
          break
        }
        case 'items': {
          const data = await itemsApi.list()
          setItems(data)
          break
        }
        case 'maps': {
          const data = await mapsApi.list()
          setMaps(data)
          break
        }
        case 'shops': {
          const data = await shopsApi.list()
          setShops(data)
          break
        }
      }
    } catch (err) {
      toast.error(`Failed to load ${category}: ${err instanceof Error ? err.message : 'Unknown error'}`)
    } finally {
      setLoading(false)
    }
  }, [category])

  useEffect(() => {
    loadData()
  }, [loadData])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-parchment/50 font-heading text-lg">Loading {category}...</p>
      </div>
    )
  }

  return (
    <div className="flex h-full">
      {/* List panel */}
      <div className="w-[280px] shrink-0">
        {category === 'creatures' && (
          <CreatureList creatures={creatures} selectedId={selectedId} onSelect={setSelectedId} />
        )}
        {category === 'moves' && (
          <MovesList moves={moves} selectedId={selectedId} onSelect={setSelectedId} />
        )}
        {category === 'items' && (
          <ItemsList items={items} selectedId={selectedId} onSelect={setSelectedId} />
        )}
        {category === 'maps' && (
          <MapsList maps={maps} selectedId={selectedId} onSelect={setSelectedId} />
        )}
        {category === 'shops' && (
          <ShopsList shops={shops} selectedId={selectedId} onSelect={setSelectedId} />
        )}
      </div>

      {/* Detail panel */}
      <div className="flex-1">
        {selectedId ? (
          <>
            {category === 'creatures' && creatures[selectedId] && (
              <CreatureForm id={selectedId} creature={creatures[selectedId]} />
            )}
            {category === 'moves' && moves[selectedId] && (
              <MoveForm id={selectedId} move={moves[selectedId]} />
            )}
            {category === 'items' && items[selectedId] && (
              <ItemForm id={selectedId} item={items[selectedId]} />
            )}
            {category === 'maps' && maps[selectedId] && (
              <MapForm id={selectedId} map={maps[selectedId]} />
            )}
            {category === 'shops' && shops[selectedId] && (
              <ShopForm id={selectedId} shop={shops[selectedId]} />
            )}
          </>
        ) : (
          <div className="flex items-center justify-center h-full">
            <div className="text-center">
              <p className="text-parchment/40 font-heading text-lg">
                Select a {category?.slice(0, -1) ?? 'record'} to edit
              </p>
              <p className="text-parchment/30 text-sm mt-1">
                Choose from the list on the left
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
