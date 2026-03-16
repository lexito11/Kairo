'use client'

import { useRef, useEffect, useState } from 'react'

interface VideoPlayerProps {
  src: string
  className?: string
  fit?: 'cover' | 'contain'
  /** Cuando true, reanudar reproducción (p. ej. al cerrar el modal del video) */
  forcePlayVideo?: boolean
  /** Para registrar tiempo de reproducción en el feed personalizado */
  postId?: string
}

export function VideoPlayer({ src, className = '', fit = 'contain', forcePlayVideo = false, postId }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const watchStartRef = useRef<number | null>(null)
  const [isMuted, setIsMuted] = useState(false)

  // Reanudar el video cuando se cierra el modal: siempre debe seguir reproduciéndose en el feed
  useEffect(() => {
    if (!forcePlayVideo) return
    const play = () => {
      const video = videoRef.current
      if (!video) return
      video.muted = true
      video.play().catch(() => {})
    }
    const t1 = setTimeout(play, 50)
    const t2 = setTimeout(play, 200)
    const t3 = setTimeout(play, 450)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
    }
  }, [forcePlayVideo])

  useEffect(() => {
    const video = videoRef.current
    if (!video) return

    // Para autoplay, el video debe estar muted inicialmente
    video.muted = true
    video.volume = 1.0
    setIsMuted(true)
    
    // Intentar activar el sonido cuando el usuario interactúa
    const handleUserInteraction = () => {
      if (video.muted) {
        video.muted = false
        video.volume = 1.0
        setIsMuted(false)
      }
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            watchStartRef.current = Date.now()
            video.muted = true
            video.play().catch(() => {})
          } else {
            if (postId && watchStartRef.current !== null) {
              const watchedSeconds = Math.floor((Date.now() - watchStartRef.current) / 1000)
              if (watchedSeconds >= 1) {
                fetch(`/api/posts/${postId}/view`, {
                  method: 'POST',
                  headers: { 'Content-Type': 'application/json' },
                  body: JSON.stringify({ watchedSeconds }),
                }).catch(() => {})
              }
              watchStartRef.current = null
            }
            video.pause()
          }
        })
      },
      {
        threshold: 0.15,
        rootMargin: '50px 0px',
      }
    )

    observer.observe(video)

    // Actualizar estado de mute cuando cambia desde los controles nativos
    const handleVolumeChange = () => {
      setIsMuted(video.muted)
    }

    // Detectar clics para activar sonido
    const handleClick = () => {
      if (video.muted) {
        video.muted = false
        video.volume = 1.0
        setIsMuted(false)
      }
      setTimeout(() => {
        setIsMuted(video.muted)
      }, 10)
    }

    video.addEventListener('volumechange', handleVolumeChange)
    video.addEventListener('click', handleClick)
    video.addEventListener('play', handleUserInteraction)

    return () => {
      observer.disconnect()
      video.removeEventListener('volumechange', handleVolumeChange)
      video.removeEventListener('click', handleClick)
      video.removeEventListener('play', handleUserInteraction)
    }
  }, [postId])

  const toggleMute = () => {
    const video = videoRef.current
    if (!video) return
    video.muted = !video.muted
    setIsMuted(video.muted)
  }

  // Determinar si usa altura automática
  const usesAutoHeight = className?.includes('h-auto')
  
  return (
    <div className={`relative group ${usesAutoHeight ? 'w-full' : 'w-full h-full'}`}>
      <video
        ref={videoRef}
        src={src}
        controls
        autoPlay
        preload="auto"
        loop
        playsInline
        muted
        className={`absolute inset-0 w-full h-full ${
          fit === 'cover' ? 'object-cover' : 'object-contain bg-black'
        } ${className}`}
      />
      
      {/* Botón de mute en la esquina */}
      <button
        onClick={(e) => {
          e.stopPropagation()
          toggleMute()
        }}
        className="absolute top-12 right-3 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all z-10"
      >
        <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24" style={{ position: 'relative' }}>
          {/* Bocina siempre completa con ondas de sonido */}
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M19.114 5.636a9 9 0 010 12.728M16.463 8.288a5 5 0 010 7.072M13 3L8 8H3v8h5l5 5V3z"
          />
          {/* Línea diagonal solo cuando está muteado */}
          {isMuted && (
            <line
              x1="4"
              y1="4"
              x2="20"
              y2="20"
              stroke="currentColor"
              strokeWidth="2.5"
              strokeLinecap="round"
            />
          )}
        </svg>
      </button>
    </div>
  )
}

