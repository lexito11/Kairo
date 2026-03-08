'use client'

import { memo } from 'react'
import { Avatar } from '@/components/atoms/Avatar'

interface AvatarItem {
  id: string
  label: string
  image?: string | null
  isNew?: boolean
}

function ProfileAvatarsComponent() {
  // Mock data - en producción esto vendría de una API
  const avatars: AvatarItem[] = [
    {
      id: 'new',
      label: 'Nuevo',
      isNew: true,
    },
    {
      id: 'featured',
      label: 'Destacado',
      image: null, // En producción, usar imagen real
    },
    {
      id: 'favorites',
      label: 'Favoritos',
      image: null, // En producción, usar imagen real
    },
  ]

  return (
    <div className="flex gap-4 items-start">
      {avatars.map((avatar) => (
        <div key={avatar.id} className="flex flex-col items-center gap-2">
          {avatar.isNew ? (
            <div className="w-16 h-16 rounded-full border-2 border-dashed border-gray-600 flex items-center justify-center bg-dark-hover">
              <svg className="w-6 h-6 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
              </svg>
            </div>
          ) : (
            <div className="w-16 h-16 rounded-full border-2 border-primary-500 overflow-hidden">
              <Avatar
                src={avatar.image}
                alt={avatar.label}
                size="lg"
                className="border-0"
              />
            </div>
          )}
          <span className="text-xs text-gray-400 text-center">{avatar.label}</span>
        </div>
      ))}
    </div>
  )
}

export const ProfileAvatars = memo(ProfileAvatarsComponent)

