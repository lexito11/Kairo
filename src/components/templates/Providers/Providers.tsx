'use client'

import { SessionProvider } from 'next-auth/react'
import { ReactNode } from 'react'
import { ThemeProvider } from '@/contexts/ThemeContext'
import { ScrollToTop } from '@/components/templates/ScrollToTop/ScrollToTop'

export function Providers({ children }: { children: ReactNode }) {
  return (
    <SessionProvider>
      <ThemeProvider>
        <ScrollToTop />
        {children}
      </ThemeProvider>
    </SessionProvider>
  )
}








