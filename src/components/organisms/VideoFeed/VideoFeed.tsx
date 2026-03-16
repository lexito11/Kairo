'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { Post } from '@/types'
import { Avatar } from '@/components/atoms/Avatar'

interface VideoFeedProps {
  posts: Post[]
  initialIndex: number
  onClose: (postId?: string) => void
  onLike: (postId: string) => void
  onComment: (postId: string) => void
  onShare: (postId: string) => void
  /** Guardar para ver después (bookmark, no descarga) */
  onSave?: (postId: string) => void
  /** 'feed' = relleno blanco como en la imagen; 'videos' = mismo estilo pero relleno azul */
  variant?: 'feed' | 'videos'
}

interface VideoPost {
  post: Post
  videoUrl: string
}

export function VideoFeed({ posts, initialIndex, onClose, onLike, onComment, onShare, onSave, variant = 'feed' }: VideoFeedProps) {
  const router = useRouter()
  const [currentIndex, setCurrentIndex] = useState(initialIndex)
  const [isPlaying, setIsPlaying] = useState(true)
  const [isMuted, setIsMuted] = useState(true)
  const [progress, setProgress] = useState(0) // 0..1 progreso del video activo
  const [duration, setDuration] = useState(0) // duración en segundos del video activo
  const videoRefs = useRef<(HTMLVideoElement | null)[]>([])
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  const fullscreenRef = useRef<HTMLDivElement>(null)
  const prevIndexRef = useRef<number | null>(null)
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [showMoreMenu, setShowMoreMenu] = useState(false)
  const [savedIds, setSavedIds] = useState<Set<string>>(() => {
    if (typeof window === 'undefined') return new Set()
    try {
      const saved = JSON.parse(window.localStorage.getItem('saved-posts') || '[]') as string[]
      return new Set(saved)
    } catch {
      return new Set()
    }
  })

  const handleSavePost = useCallback((postId: string) => {
    try {
      const saved = JSON.parse(
        typeof window !== 'undefined'
          ? window.localStorage.getItem('saved-posts') || '[]'
          : '[]'
      ) as string[]

      let next: string[]
      const isAlreadySaved = saved.includes(postId)

      if (isAlreadySaved) {
        next = saved.filter((id) => id !== postId)
        setSavedIds((prev) => {
          const copy = new Set(prev)
          copy.delete(postId)
          return copy
        })
      } else {
        next = [...saved, postId]
        setSavedIds((prev) => new Set([...prev, postId]))
      }

      if (typeof window !== 'undefined') {
        window.localStorage.setItem('saved-posts', JSON.stringify(next))
      }

      onSave?.(postId)
    } catch {
      onSave?.(postId)
    }
  }, [onSave])

  const reportWatchTime = useCallback((postId: string, watchedSeconds: number) => {
    if (watchedSeconds < 1) return
    fetch(`/api/posts/${postId}/view`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ watchedSeconds }),
    }).catch(() => {})
  }, [])

  // Filtrar solo posts con videos y extraer la URL del video
  const videoPosts: VideoPost[] = posts
    .map((post) => {
      // Buscar video en mediaUrl o mediaUrls
      let videoUrl: string | null = null
      
      if (post.mediaType === 'video' && post.mediaUrl) {
        videoUrl = post.mediaUrl
      } else if (post.mediaUrls && post.mediaUrls.length > 0) {
        // Buscar el primer video en mediaUrls
        const videoItem = post.mediaUrls.find(url => {
          const lowerUrl = url.toLowerCase()
          return lowerUrl.includes('.mp4') || 
                 lowerUrl.includes('.webm') || 
                 lowerUrl.includes('video') ||
                 lowerUrl.includes('gtv-videos-bucket')
        })
        if (videoItem) {
          videoUrl = videoItem
        }
      }
      
      return videoUrl ? { post, videoUrl } : null
    })
    .filter((item): item is VideoPost => item !== null)

  // Scroll al video inicial cuando se monta
  useEffect(() => {
    if (scrollContainerRef.current && initialIndex >= 0 && initialIndex < videoPosts.length) {
      const container = scrollContainerRef.current
      const videoHeight = container.clientHeight
      container.scrollTop = initialIndex * videoHeight
    }
  }, [initialIndex, videoPosts.length])

  // Detectar qué video está visible al hacer scroll usando IntersectionObserver
  useEffect(() => {
    const container = scrollContainerRef.current
    if (!container) return

    const videoElements = Array.from(container.children) as HTMLElement[]
    
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.intersectionRatio > 0.5) {
            const index = videoElements.indexOf(entry.target as HTMLElement)
            if (index !== -1 && index !== currentIndex) {
              setCurrentIndex(index)
            }
          }
        })
      },
      {
        root: container,
        threshold: 0.5, // Cuando al menos el 50% del video está visible
      }
    )

    videoElements.forEach((element) => {
      observer.observe(element)
    })

    return () => {
      videoElements.forEach((element) => {
        observer.unobserve(element)
      })
    }
  }, [currentIndex, videoPosts.length])

  // Forzar play del video actual (siempre muted primero para que el navegador no bloquee)
  const tryPlayCurrent = useCallback(() => {
    const currentVideo = videoRefs.current[currentIndex]
    if (!currentVideo) return
    currentVideo.muted = true
    currentVideo.currentTime = 0
    setIsPlaying(true)
    const p = currentVideo.play()
    if (p && typeof p.catch === 'function') p.catch(() => {})
  }, [currentIndex])

  useEffect(() => {
    tryPlayCurrent()
    const t1 = setTimeout(tryPlayCurrent, 80)
    const t2 = setTimeout(tryPlayCurrent, 200)
    const t3 = setTimeout(tryPlayCurrent, 500)
    const t4 = setTimeout(tryPlayCurrent, 1000)
    return () => {
      clearTimeout(t1)
      clearTimeout(t2)
      clearTimeout(t3)
      clearTimeout(t4)
    }
  }, [currentIndex, tryPlayCurrent])

  // Al cambiar de video: registrar tiempo de reproducción del anterior
  useEffect(() => {
    const prev = prevIndexRef.current
    if (prev !== null && prev !== currentIndex && videoPosts[prev] && videoRefs.current[prev]) {
      const elapsed = Math.floor(videoRefs.current[prev]!.currentTime)
      if (elapsed > 0) reportWatchTime(videoPosts[prev].post.id, elapsed)
    }
    prevIndexRef.current = currentIndex
  }, [currentIndex, videoPosts, reportWatchTime])

  // Pausar todos los videos excepto el actual
  useEffect(() => {
    videoRefs.current.forEach((video, index) => {
      if (video && index !== currentIndex) {
        video.pause()
        video.currentTime = 0
      }
    })
  }, [currentIndex])

  // Prevenir scroll del body/html cuando está abierto (sin provocar salto de layout)
  useEffect(() => {
    const html = document.documentElement
    const body = document.body
    html.style.overflow = 'hidden'
    body.style.overflow = 'hidden'
    return () => {
      html.style.overflow = ''
      body.style.overflow = ''
    }
  }, [])

  // Sincronizar estado de fullscreen con el API (p. ej. Escape)
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement)
    }
    document.addEventListener('fullscreenchange', handleFullscreenChange)
    return () => document.removeEventListener('fullscreenchange', handleFullscreenChange)
  }, [])

  // Manejar clic en el video para pausar/reproducir
  const handleVideoClick = () => {
    const currentVideo = videoRefs.current[currentIndex]
    if (!currentVideo) return

    if (isPlaying) {
      currentVideo.pause()
      setIsPlaying(false)
    } else {
      currentVideo.play()
      setIsPlaying(true)
    }
  }

  // Manejar mute/unmute
  const toggleMute = () => {
    setIsMuted(!isMuted)
  }

  // Manejar cambio de progreso desde la barra (seek)
  const handleSeek = (value: number) => {
    const currentVideo = videoRefs.current[currentIndex]
    if (!currentVideo || !duration) return
    const newTime = (value / 100) * duration
    currentVideo.currentTime = newTime
    setProgress(value / 100)
  }

  // Navegar al perfil del autor (por ahora al perfil general, con userId en query)
  const handleAuthorClick = (authorId: string) => {
    router.push(`/profile?userId=${authorId}`)
  }

  // Toggle fullscreen
  const toggleFullscreen = useCallback(() => {
    const el = fullscreenRef.current
    if (!el) return
    if (!document.fullscreenElement) {
      el.requestFullscreen().then(() => setIsFullscreen(true)).catch(() => {})
    } else {
      document.exitFullscreen().then(() => setIsFullscreen(false)).catch(() => {})
    }
  }, [])

  // Cerrar menú al hacer clic fuera
  useEffect(() => {
    if (!showMoreMenu) return
    const close = () => setShowMoreMenu(false)
    document.addEventListener('click', close)
    return () => document.removeEventListener('click', close)
  }, [showMoreMenu])

  if (videoPosts.length === 0) return null

  return (
    <div ref={fullscreenRef} className="fixed inset-0 bg-black z-40">
      {/* Botón de cerrar: registrar tiempo visto y pasar postId para reanudar en el feed */}
      <button
        onClick={() => {
          const postId = videoPosts[currentIndex]?.post.id
          const video = videoRefs.current[currentIndex]
          if (postId && video) {
            const sec = Math.floor(video.currentTime)
            if (sec > 0) reportWatchTime(postId, sec)
          }
          onClose(postId)
        }}
        className="absolute top-4 left-4 z-50 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>

      {/* Contenedor de videos con scroll nativo */}
      <div 
        ref={scrollContainerRef}
        className="w-full h-screen overflow-y-scroll scrollbar-hide pb-24"
        style={{ 
          scrollSnapType: 'y mandatory',
          WebkitOverflowScrolling: 'touch',
          maxHeight: '100vh',
        }}
      >
        {videoPosts.map((videoPost, index) => {
          const { post, videoUrl } = videoPost
          const authorName = post.author.name || post.author.username || 'Usuario'
          const isActive = index === currentIndex
          
          return (
            <div
              key={post.id}
              className="relative w-full flex-shrink-0 snap-start flex items-center justify-center bg-black"
              style={{
                height: '100vh',
                width: '100%',
                overflow: 'hidden',
              }}
            >
              {/* Contenedor tipo móvil centrado (como TikTok/Facebook video) */}
              <div className="relative w-full max-w-[420px] max-h-[82vh] aspect-[9/16] bg-black flex items-center justify-center">
                <video
                  ref={(el) => {
                    videoRefs.current[index] = el
                    if (el && index === currentIndex) {
                      el.muted = true
                      el.play().catch(() => {})
                    }
                  }}
                  src={videoUrl}
                  className="w-full h-full object-contain bg-black"
                  autoPlay
                  loop
                  playsInline
                  preload="auto"
                  muted={isMuted}
                  onClick={handleVideoClick}
                  onLoadedData={(e) => {
                    if (index === currentIndex) {
                      e.currentTarget.muted = true
                      e.currentTarget.play().catch(() => {})
                    }
                  }}
                  onCanPlay={(e) => {
                    if (index === currentIndex) {
                      e.currentTarget.muted = true
                      e.currentTarget.play().catch(() => {})
                    }
                  }}
                  onLoadedMetadata={(e) => {
                    if (index === currentIndex) {
                      const d = e.currentTarget.duration || 0
                      setDuration(d)
                      setProgress(0)
                    }
                  }}
                  onTimeUpdate={(e) => {
                    if (index === currentIndex) {
                      const d = e.currentTarget.duration || 0
                      const t = e.currentTarget.currentTime
                      if (d > 0) {
                        setDuration(d)
                        setProgress(t / d)
                      }
                    }
                  }}
                  onPlay={() => {
                    if (isActive) setIsPlaying(true)
                  }}
                  onPause={() => {
                    if (isActive) setIsPlaying(false)
                  }}
                />
              </div>

              {/* Botones de reacción en vertical a la derecha (estilo Instagram) */}
              <div className="absolute right-2 top-1/2 -translate-y-1/2 flex flex-col gap-5 pointer-events-auto z-10">
                <button
                  type="button"
                  onClick={() => onLike(post.id)}
                  className={`flex flex-col items-center gap-0.5 py-1 ${
                    post.isLiked ? 'text-red-500' : 'text-white'
                  }`}
                >
                  <svg
                    className="w-8 h-8"
                    fill={post.isLiked ? '#ef4444' : 'none'}
                    stroke={post.isLiked ? 'none' : 'currentColor'}
                    strokeWidth={post.isLiked ? 0 : 1.5}
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
                    />
                  </svg>
                  <span className="text-xs font-medium text-white">
                    {(post as any).likesCount ?? post._count?.likes ?? 0}
                  </span>
                </button>
                <button
                  type="button"
                  onClick={() => onComment(post.id)}
                  className="flex flex-col items-center gap-0.5 py-1 text-white"
                >
                  <svg
                    className="w-8 h-8"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z"
                    />
                  </svg>
                  <span className="text-xs font-medium text-white">
                    {(post as any).commentsCount ?? post._count?.comments ?? 0}
                  </span>
                </button>
                <button
                  type="button"
                  onClick={() => onShare(post.id)}
                  className="flex flex-col items-center gap-0.5 py-1 text-white"
                >
                  <svg
                    className="w-8 h-8"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth={1.5}
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
                    />
                  </svg>
                  <span className="text-xs font-medium text-white">Compartir</span>
                </button>
                <button
                  type="button"
                  onClick={() => handleSavePost(post.id)}
                  className="flex flex-col items-center gap-0.5 py-1 text-white"
                  title="Guardar en Guardados del perfil"
                >
                  <svg
                    className="w-8 h-8"
                    fill={savedIds.has(post.id) ? 'currentColor' : 'none'}
                    stroke="currentColor"
                    strokeWidth={1.5}
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z"
                    />
                  </svg>
                  <span className="text-xs font-medium text-white">Guardar</span>
                </button>
              </div>

              {/* Overlay con información del autor y barra de progreso (pb-24 para que la línea de tiempo no se esconda bajo el menú) */}
              <div className="absolute inset-x-0 bottom-0 px-4 pt-4 pb-24 bg-gradient-to-t from-black/80 to-transparent pointer-events-none">
                <div className="max-w-[420px] mx-auto flex flex-col gap-3">
                  {/* Información del autor */}
                  <div className={`flex items-center pointer-events-auto ${variant === 'videos' ? 'justify-between gap-3' : ''}`}>
                    <button
                      type="button"
                      onClick={() => handleAuthorClick(post.author.id)}
                      className="flex items-center gap-3"
                    >
                      <Avatar src={post.author.image} alt={authorName} size="sm" />
                      <div>
                        <p className="text-white font-semibold text-sm">{authorName}</p>
                      </div>
                    </button>
                    {/* En sección videos: botones a la derecha, misma fila que el perfil */}
                    {variant === 'videos' && isActive && (
                      <div className="flex items-center gap-2 flex-shrink-0">
                        <button
                          type="button"
                          onClick={toggleMute}
                          className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                          aria-label={isMuted ? 'Activar sonido' : 'Silenciar'}
                        >
                          {isMuted ? (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                            </svg>
                          ) : (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                            </svg>
                          )}
                        </button>
                        <button
                          type="button"
                          onClick={toggleFullscreen}
                          className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                          aria-label={isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa'}
                        >
                          {isFullscreen ? (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
                            </svg>
                          ) : (
                            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                            </svg>
                          )}
                        </button>
                        <div className="relative ml-auto">
                          <button
                            type="button"
                            onClick={(e) => { e.stopPropagation(); setShowMoreMenu(v => !v) }}
                            className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                            aria-label="Más opciones"
                          >
                            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                              <circle cx="12" cy="5" r="1.5" />
                              <circle cx="12" cy="12" r="1.5" />
                              <circle cx="12" cy="19" r="1.5" />
                            </svg>
                          </button>
                          {showMoreMenu && (
                            <div
                              className="absolute bottom-full right-0 mb-2 py-1 min-w-[160px] bg-gray-900/95 rounded-lg shadow-xl border border-gray-700"
                              onClick={(e) => e.stopPropagation()}
                            >
                              <button
                                type="button"
                                onClick={() => { handleSavePost(post.id); setShowMoreMenu(false) }}
                                className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" />
                                </svg>
                                Guardar
                              </button>
                              <button
                                type="button"
                                onClick={() => { onShare(post.id); setShowMoreMenu(false) }}
                                className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" />
                                </svg>
                                Compartir
                              </button>
                              <button
                                type="button"
                                onClick={() => { handleAuthorClick(post.author.id); setShowMoreMenu(false) }}
                                className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2"
                              >
                                <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                                </svg>
                                Ver perfil
                              </button>
                            </div>
                          )}
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Barra de progreso debajo del perfil */}
                  {isActive && (
                    <div className="w-full pointer-events-auto -mt-1 flex flex-col gap-2">
                      <input
                        type="range"
                        min={0}
                        max={100}
                        step={0.5}
                        value={progress * 100}
                        onChange={(e) => handleSeek(Number(e.target.value))}
                        className={`video-progress video-progress--${variant} w-full cursor-pointer`}
                        style={
                          {
                            '--progress': `${progress * 100}%`,
                            '--fill-color': variant === 'videos' ? '#0ea5e9' : 'rgba(255, 255, 255, 0.9)',
                          } as React.CSSProperties
                        }
                        aria-label="Progreso del video"
                      />
                      {/* En feed: controles debajo de la barra; en videos ya están al lado del perfil */}
                      {variant === 'feed' && (
                        <div className="flex items-center gap-2">
                          <button
                            type="button"
                            onClick={toggleMute}
                            className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                            aria-label={isMuted ? 'Activar sonido' : 'Silenciar'}
                          >
                            {isMuted ? (
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                              </svg>
                            ) : (
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                              </svg>
                            )}
                          </button>
                          <button
                            type="button"
                            onClick={toggleFullscreen}
                            className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                            aria-label={isFullscreen ? 'Salir de pantalla completa' : 'Pantalla completa'}
                          >
                            {isFullscreen ? (
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
                              </svg>
                            ) : (
                              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
                              </svg>
                            )}
                          </button>
                          <div className="relative ml-auto">
                            <button
                              type="button"
                              onClick={(e) => { e.stopPropagation(); setShowMoreMenu(v => !v) }}
                              className="w-9 h-9 rounded-full bg-black/50 flex items-center justify-center text-white hover:bg-black/70 transition-all"
                              aria-label="Más opciones"
                            >
                              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                                <circle cx="12" cy="5" r="1.5" />
                                <circle cx="12" cy="12" r="1.5" />
                                <circle cx="12" cy="19" r="1.5" />
                              </svg>
                            </button>
                            {showMoreMenu && (
                              <div
                                className="absolute bottom-full right-0 mb-2 py-1 min-w-[160px] bg-gray-900/95 rounded-lg shadow-xl border border-gray-700"
                                onClick={(e) => e.stopPropagation()}
                              >
                                <button type="button" onClick={() => { handleSavePost(post.id); setShowMoreMenu(false) }} className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2">
                                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 5a2 2 0 012-2h10a2 2 0 012 2v16l-7-3.5L5 21V5z" /></svg>
                                  Guardar
                                </button>
                                <button type="button" onClick={() => { onShare(post.id); setShowMoreMenu(false) }} className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2">
                                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z" /></svg>
                                  Compartir
                                </button>
                                <button type="button" onClick={() => { handleAuthorClick(post.author.id); setShowMoreMenu(false) }} className="w-full px-4 py-2 text-left text-white text-sm hover:bg-gray-700/80 flex items-center gap-2">
                                  <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                                  Ver perfil
                                </button>
                              </div>
                            )}
                          </div>
                        </div>
                      )}
                    </div>
                  )}
                </div>
              </div>

              {/* Indicador de pausa/reproducción */}
              {isActive && !isPlaying && (
                <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                  <div className="w-16 h-16 bg-black/50 rounded-full flex items-center justify-center">
                    <svg className="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M8 5v14l11-7z" />
                    </svg>
                  </div>
                </div>
              )}
            </div>
          )
        })}
      </div>

      <style jsx global>{`
        /* Barra de progreso tipo reels: pista oscura, relleno según variant, thumb blanco */
        .video-progress {
          -webkit-appearance: none;
          appearance: none;
          background: transparent;
          outline: none;
          border: 0;
          height: 18px; /* área de toque cómoda */
          padding: 0;
          margin: 0;
        }
        .video-progress::-webkit-slider-runnable-track {
          height: 4px;
          background: linear-gradient(
            to right,
            var(--fill-color, rgba(255, 255, 255, 0.9)) 0%,
            var(--fill-color, rgba(255, 255, 255, 0.9)) var(--progress, 0%),
            rgba(255, 255, 255, 0.35) var(--progress, 0%),
            rgba(255, 255, 255, 0.35) 100%
          );
          border-radius: 9999px;
          border: 0;
        }
        .video-progress::-webkit-slider-thumb {
          -webkit-appearance: none;
          appearance: none;
          width: 14px;
          height: 14px;
          border-radius: 9999px;
          background: #fff; /* thumb blanco como en la imagen */
          border: 0;
          box-shadow: none;
          margin-top: -5px; /* centra el thumb con la pista de 4px */
        }
        .video-progress:focus {
          outline: none;
        }

        /* Firefox */
        .video-progress::-moz-range-track {
          height: 4px;
          background: linear-gradient(
            to right,
            var(--fill-color, rgba(255, 255, 255, 0.9)) 0%,
            var(--fill-color, rgba(255, 255, 255, 0.9)) var(--progress, 0%),
            rgba(255, 255, 255, 0.35) var(--progress, 0%),
            rgba(255, 255, 255, 0.35) 100%
          );
          border-radius: 9999px;
          border: 0;
        }
        .video-progress::-moz-range-thumb {
          width: 14px;
          height: 14px;
          border-radius: 9999px;
          background: #fff;
          border: 0;
          box-shadow: none;
        }
        .video-progress::-moz-focus-outer {
          border: 0;
        }
      `}</style>
    </div>
  )
}
