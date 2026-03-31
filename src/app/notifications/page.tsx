'use client'

import { useCallback, useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { useSession } from 'next-auth/react'
import { Avatar } from '@/components/atoms/Avatar'
import { BottomNavigation } from '@/components/templates/BottomNavigation'

type IncomingItem = {
  id: string
  name: string | null
  username: string | null
  image: string | null
  isMutual: boolean
  followId: string
  createdAt: string
}

export default function NotificationsPage() {
  const router = useRouter()
  const { status } = useSession()
  const [items, setItems] = useState<IncomingItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [actionId, setActionId] = useState<string | null>(null)

  const load = useCallback(async () => {
    setError(null)
    const res = await fetch('/api/users/me/notifications')
    if (!res.ok) {
      setError('No se pudieron cargar las notificaciones')
      setLoading(false)
      return
    }
    const data = await res.json()
    setItems(data.items || [])
    setLoading(false)
  }, [])

  useEffect(() => {
    if (status === 'unauthenticated') {
      router.replace('/auth/signin')
      return
    }
    if (status !== 'authenticated') return

    ;(async () => {
      await fetch('/api/users/me/notifications', { method: 'POST' }).catch(() => {})
      await load()
    })()
  }, [status, router, load])

  const handleAgregarTambien = async (userId: string) => {
    setActionId(userId)
    try {
      const res = await fetch(`/api/users/${userId}/follow`, { method: 'POST' })
      if (!res.ok) throw new Error()
      setItems((prev) =>
        prev.map((row) => (row.id === userId ? { ...row, isMutual: true } : row))
      )
    } catch {
      alert('No se pudo agregar. Intenta de nuevo.')
    } finally {
      setActionId(null)
    }
  }

  return (
    <div className="min-h-screen bg-white dark:bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        <header className="flex items-center gap-3 px-4 py-3 border-b border-gray-200 dark:border-dark-border sticky top-0 z-10 bg-white/95 dark:bg-dark-bg/95 backdrop-blur-md">
          <button
            type="button"
            onClick={() => router.back()}
            className="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-dark-hover text-gray-700 dark:text-gray-300"
            aria-label="Volver"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h1 className="text-lg font-bold text-gray-900 dark:text-white">Notificaciones</h1>
        </header>

        <div className="px-4 py-4">
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
            Personas que te agregaron. Si agregas de vuelta, pasan a ser amigos (mutuo).
          </p>

          {loading && (
            <p className="text-center text-gray-500 dark:text-gray-400 py-8">Cargando…</p>
          )}
          {error && <p className="text-center text-red-500 py-4">{error}</p>}
          {!loading && !error && items.length === 0 && (
            <p className="text-center text-gray-500 dark:text-gray-400 py-12">
              Nadie nuevo te ha agregado aún.
            </p>
          )}
          <ul className="space-y-3">
            {items.map((row) => {
              const label = row.name || row.username || 'Usuario'
              return (
                <li
                  key={row.followId}
                  className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 dark:bg-dark-card border border-gray-100 dark:border-dark-border"
                >
                  <button
                    type="button"
                    onClick={() => router.push(`/profile?userId=${encodeURIComponent(row.id)}`)}
                    className="flex items-center gap-3 flex-1 min-w-0 text-left"
                  >
                    <Avatar src={row.image} alt={label} size="md" />
                    <div className="min-w-0 flex-1">
                      <p className="font-semibold text-gray-900 dark:text-white truncate">{label}</p>
                      {row.username && (
                        <p className="text-xs text-gray-500 dark:text-gray-400 truncate">
                          @{row.username}
                        </p>
                      )}
                    </div>
                  </button>
                  {row.isMutual ? (
                    <span className="text-xs font-medium text-emerald-600 dark:text-emerald-400 shrink-0">
                      Amigos
                    </span>
                  ) : (
                    <button
                      type="button"
                      disabled={actionId === row.id}
                      onClick={() => handleAgregarTambien(row.id)}
                      className="shrink-0 px-3 py-1.5 rounded-lg text-sm font-semibold bg-primary-500 text-white hover:bg-primary-600 disabled:opacity-60"
                    >
                      {actionId === row.id ? '…' : 'Agregar también'}
                    </button>
                  )}
                </li>
              )
            })}
          </ul>
        </div>
      </div>
      <BottomNavigation />
    </div>
  )
}
