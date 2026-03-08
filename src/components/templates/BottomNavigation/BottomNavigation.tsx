'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'

export function BottomNavigation() {
  const pathname = usePathname()

  const navItems = [
    {
      href: '/feed',
      label: 'Feed',
      icon: (
        <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
          <path d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z"/>
        </svg>
      ),
    },
    {
      href: '/events',
      label: 'Eventos',
      icon: (
        <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
          />
        </svg>
      ),
    },
    {
      href: '/videos',
      label: 'Videos',
      icon: (
        <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="10" fill="currentColor"/>
          <path d="M10 8l6 4-6 4V8z" fill="white"/>
        </svg>
      ),
    },
    {
      href: '/chat',
      label: 'Chat',
      icon: (
        <svg className="w-7 h-7" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zm0 14H6l-2 2V4h16v12z"/>
        </svg>
      ),
      badge: true,
    },
    {
      href: '/profile',
      label: 'Perfil',
      icon: (
        <svg className="w-7 h-7" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
          />
        </svg>
      ),
    },
  ]

  const isActive = (href: string) => {
    if (href === '/feed') {
      return pathname === '/' || pathname === '/feed'
    }
    if (href === '/events') {
      return pathname === '/events'
    }
    if (href === '/videos') {
      return pathname === '/videos'
    }
    return pathname?.startsWith(href)
  }

  return (
    <nav className="fixed bottom-0 left-0 right-0 border-t border-gray-200 dark:border-dark-border bg-white/95 dark:bg-dark-bg/95 backdrop-blur-xl flex justify-around items-center py-2 px-3 z-30 shadow-2xl">
      {navItems.map((item) => (
        <Link
          key={item.href}
          href={item.href}
          className={`flex flex-col items-center gap-1 transition-all relative ${
            isActive(item.href)
              ? 'text-primary-500'
              : 'text-gray-500 hover:text-white'
          }`}
        >
          {item.icon}
          {item.badge && (
            <span className="absolute -top-1 right-2 w-5 h-5 bg-red-500 rounded-full text-[9px] font-bold flex items-center justify-center text-white">
              3
            </span>
          )}
          <span className={`text-[10px] ${isActive(item.href) ? 'font-bold' : ''}`}>
            {item.label}
          </span>
        </Link>
      ))}
    </nav>
  )
}

