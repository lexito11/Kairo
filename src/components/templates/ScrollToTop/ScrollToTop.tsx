'use client'

import { useEffect } from 'react'
import { usePathname } from 'next/navigation'

/**
 * Hace scroll al inicio de la página cada vez que cambia la ruta,
 * para que la app siempre abra mostrando la parte de arriba (header, stories, etc.).
 */
export function ScrollToTop() {
  const pathname = usePathname()

  useEffect(() => {
    window.scrollTo(0, 0)
    document.documentElement.scrollTop = 0
    document.body.scrollTop = 0
  }, [pathname])

  return null
}
