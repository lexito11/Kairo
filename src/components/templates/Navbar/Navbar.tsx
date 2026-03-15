'use client'

import Link from 'next/link'
import { useSession, signOut } from 'next-auth/react'
import { Avatar } from '@/components/atoms/Avatar'
import { Button } from '@/components/atoms/Button'

export function Navbar() {
  const { data: session } = useSession()

  return (
    <nav className="bg-white shadow-md sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <Link href="/" className="text-2xl font-bold text-primary-600">
            KAIRO
          </Link>

          {/* Navigation */}
          <div className="flex items-center gap-4">
            {session ? (
              <>
                <Link href="/feed">
                  <Button variant="outline" size="sm">
                    Feed
                  </Button>
                </Link>
                <Link href="/messages">
                  <Button variant="outline" size="sm">
                    Mensajes
                  </Button>
                </Link>
                <Link href={`/profile/${session.user?.email}`}>
                  <Avatar
                    src={session.user?.image}
                    alt={session.user?.name || 'Usuario'}
                    size="sm"
                  />
                </Link>
                <Button variant="outline" size="sm" onClick={() => signOut()}>
                  Salir
                </Button>
              </>
            ) : (
              <>
                <Link href="/auth/signin">
                  <Button variant="outline" size="sm">
                    Iniciar Sesión
                  </Button>
                </Link>
                <Link href="/auth/signup">
                  <Button size="sm">Registrarse</Button>
                </Link>
              </>
            )}
          </div>
        </div>
      </div>
    </nav>
  )
}











