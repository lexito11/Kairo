'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { Avatar } from '@/components/atoms/Avatar'

type ConversationType = 'direct' | 'group'

type Conversation = {
  id: string
  type: ConversationType
  name: string
  avatarText?: string
  avatarUrl?: string | null
  lastMessage: {
    text: string
    kind?: 'text' | 'photo'
  }
  lastMessageAt: Date
  lastTimeLabel: string
  unreadCount: number
  pinned?: boolean
  online?: boolean
  membersCount?: number
}

type FilterKey = 'all' | 'unread' | 'pinned' | 'groups'

function IconCompose() {
  return (
    <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M12 20h9"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
      <path
        d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function IconSearch() {
  return (
    <svg className="w-5 h-5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M21 21l-4.35-4.35"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
      />
      <circle
        cx="11"
        cy="11"
        r="7"
        stroke="currentColor"
        strokeWidth="2"
      />
    </svg>
  )
}

function IconPin() {
  return (
    <svg className="w-4 h-4" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d="M14 2l8 8-3 3v4l-3 3h-4l-3 3-1-1 3-3v-4l3-3 3-3Z"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinejoin="round"
      />
    </svg>
  )
}

function Chip({
  active,
  label,
  count,
  onClick,
}: {
  active: boolean
  label: string
  count?: number
  onClick: () => void
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-full border text-sm transition-colors whitespace-nowrap ${
        active
          ? 'bg-primary-600 text-white border-primary-600'
          : 'bg-dark-card text-dark-text-secondary border-dark-border hover:bg-dark-hover hover:text-white'
      }`}
    >
      <span className={active ? 'font-semibold' : 'font-medium'}>{label}</span>
      {typeof count === 'number' && (
        <span
          className={`min-w-[20px] h-5 px-1.5 rounded-full text-[11px] leading-5 text-center ${
            active ? 'bg-white/20 text-white' : 'bg-dark-hover text-white'
          }`}
        >
          {count}
        </span>
      )}
    </button>
  )
}

function UnreadBadge({ count }: { count: number }) {
  if (count <= 0) return null
  return (
    <span className="min-w-[22px] h-[22px] px-1.5 rounded-full bg-primary-500 text-dark-bg text-[12px] font-bold flex items-center justify-center">
      {count}
    </span>
  )
}

function ConversationRow({ convo }: { convo: Conversation }) {
  const subtitle =
    convo.type === 'group' && convo.membersCount
      ? `${convo.membersCount} miembros`
      : convo.lastMessage.kind === 'photo'
        ? 'Foto'
        : convo.lastMessage.text

  return (
    <Link
      href="#"
      className="flex items-center gap-3 px-2 py-3 rounded-xl hover:bg-dark-hover transition-colors"
    >
      <div className="relative">
        {convo.type === 'group' ? (
          <div className="w-12 h-12 rounded-full bg-primary-600 flex items-center justify-center text-white font-bold">
            {convo.avatarText ?? convo.name.slice(0, 2).toUpperCase()}
          </div>
        ) : (
          <Avatar
            src={convo.avatarUrl}
            alt={convo.name}
            size="lg"
            className="w-12 h-12"
          />
        )}
        {convo.online && (
          <span className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-green-500 rounded-full border-2 border-dark-bg" />
        )}
      </div>

      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between gap-3">
          <div className="min-w-0">
            <p className="text-white font-semibold truncate">{convo.name}</p>
          </div>
          <p className="text-xs text-dark-text-secondary flex-shrink-0">
            {convo.lastTimeLabel}
          </p>
        </div>
        <div className="flex items-center justify-between gap-3 mt-0.5">
          <p className="text-sm text-dark-text-secondary truncate flex items-center gap-2">
            {convo.lastMessage.kind === 'photo' && (
              <span className="inline-flex items-center justify-center w-5 h-5 rounded-md bg-dark-hover text-white">
                <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                  <path
                    d="M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7Z"
                    stroke="currentColor"
                    strokeWidth="2"
                  />
                  <path
                    d="M8 11a2 2 0 1 0 0.001 0Z"
                    fill="currentColor"
                  />
                  <path
                    d="M21 15l-5-5-4 4-2-2-6 6"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
              </span>
            )}
            <span className="truncate">{subtitle}</span>
          </p>

          <UnreadBadge count={convo.unreadCount} />
        </div>
      </div>
    </Link>
  )
}

export default function ChatPage() {
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<FilterKey>('all')

  // UI mock (para que se vea como la captura). Luego lo conectamos a Prisma/Supabase.
  const conversations: Conversation[] = useMemo(
    () => [
      {
        id: 'c1',
        type: 'direct',
        name: 'Juan Pérez',
        avatarUrl: 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=200&h=200&fit=crop',
        lastMessage: { text: 'Gracias por tu testimonio, me inspiró mucho 🙏', kind: 'text' },
        lastMessageAt: new Date(Date.now() - 33 * 60 * 1000),
        lastTimeLabel: '33m',
        unreadCount: 2,
        pinned: true,
        online: true,
      },
      {
        id: 'c2',
        type: 'direct',
        name: 'Ana Martínez',
        avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&h=200&fit=crop',
        lastMessage: { text: 'Foto', kind: 'photo' },
        lastMessageAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
        lastTimeLabel: '2h',
        unreadCount: 0,
      },
      {
        id: 'c3',
        type: 'group',
        name: 'Grupo de Oración 🙏',
        avatarText: 'GO',
        lastMessage: { text: 'María: Los esperamos esta noche a las 8pm', kind: 'text' },
        lastMessageAt: new Date(Date.now() - 5 * 60 * 60 * 1000),
        lastTimeLabel: '5h',
        unreadCount: 5,
        membersCount: 12,
      },
    ],
    []
  )

  const counts = useMemo(() => {
    const unread = conversations.filter((c) => c.unreadCount > 0).length
    const pinned = conversations.filter((c) => c.pinned).length
    const groups = conversations.filter((c) => c.type === 'group').length
    return {
      all: conversations.length,
      unread,
      pinned,
      groups,
      totalUnreadMessages: conversations.reduce((sum, c) => sum + c.unreadCount, 0),
    }
  }, [conversations])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()

    return conversations.filter((c) => {
      if (filter === 'unread' && c.unreadCount <= 0) return false
      if (filter === 'pinned' && !c.pinned) return false
      if (filter === 'groups' && c.type !== 'group') return false

      if (!q) return true
      const haystack = `${c.name} ${c.lastMessage.text}`.toLowerCase()
      return haystack.includes(q)
    })
  }, [conversations, query, filter])

  const pinned = useMemo(
    () =>
      filtered
        .filter((c) => c.pinned)
        .sort((a, b) => new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime()),
    [filtered]
  )
  const normal = useMemo(
    () =>
      filtered
        .filter((c) => !c.pinned)
        .sort((a, b) => new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime()),
    [filtered]
  )

  return (
    <div className="min-h-screen bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        {/* Header */}
        <header className="px-4 pt-6 pb-3">
          <div className="flex items-start justify-between gap-4">
            <div>
              <h1 className="text-2xl font-bold text-white leading-tight">Mensajes</h1>
              <p className="text-sm text-dark-text-secondary mt-1">
                {counts.totalUnreadMessages} sin leer
              </p>
            </div>
            <button
              type="button"
              className="w-11 h-11 rounded-full bg-primary-500 text-dark-bg flex items-center justify-center shadow-lg shadow-primary-500/20 hover:opacity-95 transition-opacity"
              aria-label="Nuevo mensaje"
            >
              <IconCompose />
            </button>
          </div>
        </header>

        {/* Search */}
        <div className="px-4">
          <div className="flex items-center gap-3 bg-dark-card border border-dark-border rounded-2xl px-4 py-3">
            <span className="text-dark-text-secondary">
              <IconSearch />
            </span>
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Buscar conversaciones..."
              className="flex-1 bg-transparent outline-none text-white placeholder:text-dark-text-secondary text-sm"
            />
          </div>
        </div>

        {/* Filters */}
        <div className="px-4 mt-4">
          <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1">
            <Chip
              active={filter === 'all'}
              label="Todos"
              count={counts.all}
              onClick={() => setFilter('all')}
            />
            <Chip
              active={filter === 'unread'}
              label="No leídos"
              count={counts.unread}
              onClick={() => setFilter('unread')}
            />
            <Chip
              active={filter === 'pinned'}
              label="Fijados"
              count={counts.pinned}
              onClick={() => setFilter('pinned')}
            />
            <Chip
              active={filter === 'groups'}
              label="Grupos"
              count={counts.groups}
              onClick={() => setFilter('groups')}
            />
          </div>
        </div>

        <div className="px-4 mt-4">
          <div className="border-t border-dark-border" />
        </div>

        {/* List */}
        <div className="px-4 py-3">
          {pinned.length > 0 && (
            <>
              <div className="flex items-center gap-2 text-primary-400 text-xs font-bold tracking-widest mb-2">
                <span className="text-primary-400">
                  <IconPin />
                </span>
                <span>FIJADOS</span>
              </div>
              <div className="space-y-1">
                {pinned.map((c) => (
                  <ConversationRow key={c.id} convo={c} />
                ))}
              </div>
            </>
          )}

          {normal.length > 0 && (
            <>
              <div className="mt-4 text-xs font-bold tracking-widest text-dark-text-secondary mb-2">
                MENSAJES
              </div>
              <div className="space-y-1">
                {normal.map((c) => (
                  <ConversationRow key={c.id} convo={c} />
                ))}
              </div>
            </>
          )}

          {pinned.length === 0 && normal.length === 0 && (
            <div className="py-12 text-center text-dark-text-secondary">
              No hay conversaciones para mostrar.
            </div>
          )}
        </div>
      </div>

      <BottomNavigation />
    </div>
  )
}

