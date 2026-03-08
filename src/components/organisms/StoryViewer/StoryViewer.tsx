'use client'

import { useEffect, useRef } from 'react'
import { useSession } from 'next-auth/react'

interface Story {
  id: string
  image?: string
  video?: string
  type: 'image' | 'video'
  views: number
  likes: number
  viewed?: boolean
  author: {
    id: string
    name: string
    username: string
    avatar?: string
  }
}

interface StoryViewerProps {
  story: Story | null
  onClose: () => void
  onMarkAsViewed?: (storyId: string) => void
}

export function StoryViewer({ story, onClose, onMarkAsViewed }: StoryViewerProps) {
  const { data: session } = useSession()
  const currentUserId = session?.user?.id
  const timerRef = useRef<NodeJS.Timeout | null>(null)
  const videoRef = useRef<HTMLVideoElement | null>(null)

  useEffect(() => {
    if (story && !story.viewed && onMarkAsViewed) {
      onMarkAsViewed(story.id)
    }

    // Si es imagen, cerrar automáticamente después de 5 segundos
    if (story && story.type === 'image') {
      timerRef.current = setTimeout(() => {
        onClose()
      }, 5000) // 5 segundos
    }

    // Limitar videos a máximo 1 minuto
    if (story && story.type === 'video' && videoRef.current) {
      const video = videoRef.current
      const handleTimeUpdate = () => {
        if (video.currentTime >= 60) {
          video.pause()
          onClose()
        }
      }
      video.addEventListener('timeupdate', handleTimeUpdate)
      return () => {
        video.removeEventListener('timeupdate', handleTimeUpdate)
      }
    }

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current)
      }
    }
  }, [story, onClose, onMarkAsViewed])

  if (!story) return null

  return (
    <div className="fixed inset-0 z-50 bg-black flex items-center justify-center">
      {/* Close Button */}
      <button
        onClick={onClose}
        className="absolute top-4 right-4 z-10 w-10 h-10 flex items-center justify-center rounded-full bg-black/50 text-white hover:bg-black/70 transition-colors"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M6 18L18 6M6 6l12 12"
          />
        </svg>
      </button>

      {/* Story Content */}
      <div className="w-full h-full flex items-center justify-center">
        {story.type === 'image' && story.image ? (
          <img
            src={story.image}
            alt="Story"
            className="max-w-full max-h-full object-contain"
          />
        ) : story.type === 'video' && story.video ? (
          <video
            ref={videoRef}
            src={story.video}
            className="max-w-full max-h-full object-contain"
            controls
            autoPlay
            onLoadedMetadata={(e) => {
              const video = e.currentTarget
              // Si el video es más largo de 1 minuto, cortar
              if (video.duration > 60) {
                video.currentTime = 60
              }
            }}
          />
        ) : null}
      </div>

      {/* Story Info - Bottom Left */}
      <div className="absolute bottom-0 left-0 p-6 bg-gradient-to-t from-black/80 via-black/40 to-transparent">
        <div className="flex items-center gap-3">
          {story.author.avatar ? (
            <img
              src={story.author.avatar}
              alt={story.author.name}
              className="w-12 h-12 rounded-full border-2 border-white"
            />
          ) : (
            <div className="w-12 h-12 rounded-full bg-gray-500 border-2 border-white flex items-center justify-center text-white text-lg font-bold">
              {story.author.name.charAt(0).toUpperCase()}
            </div>
          )}
          <div>
            <p className="text-white font-semibold">{story.author.name}</p>
            <p className="text-white/70 text-sm">{story.author.username}</p>
          </div>
        </div>
      </div>

      {/* Stats - Bottom Right Vertical - Solo visible para el dueño de la historia */}
      {currentUserId === story.author.id && (
        <div className="absolute bottom-20 right-0 p-6 flex flex-col gap-4 items-end">
          <div className="flex flex-col items-center gap-2 text-white">
            <div className="flex flex-col items-center gap-1">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                />
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                />
              </svg>
              <span className="font-medium text-sm">{story.views}</span>
            </div>
            <div className="flex flex-col items-center gap-1">
              <svg className="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M20.84 4.61a5.5 5.5 0 00-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 00-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 000-7.78z" />
              </svg>
              <span className="font-medium text-sm">{story.likes}</span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

