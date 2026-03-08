'use client'

import { useRef, useEffect, useState } from 'react'

interface VideoPlayerProps {
  src: string
  className?: string
}

export function VideoPlayer({ src, className = '' }: VideoPlayerProps) {
  const videoRef = useRef<HTMLVideoElement>(null)
  const [isMuted, setIsMuted] = useState(false)

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
            // Reproducir automáticamente (muted para que funcione)
            video.play().catch((error) => {
              console.log('Autoplay blocked:', error)
            })
          } else {
            video.pause()
          }
        })
      },
      {
        threshold: 0.3,
        rootMargin: '0px',
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
  }, [])

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
        preload="auto"
        loop
        playsInline
        muted
        className={className}
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

