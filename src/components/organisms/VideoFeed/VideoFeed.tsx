'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Post } from '@/types'
import { Avatar } from '@/components/atoms/Avatar'

interface VideoFeedProps {
  posts: Post[]
  initialIndex: number
  onClose: () => void
  onLike: (postId: string) => void
  onComment: (postId: string) => void
  onShare: (postId: string) => void
}

interface VideoPost {
  post: Post
  videoUrl: string
}

export function VideoFeed({ posts, initialIndex, onClose, onLike, onComment, onShare }: VideoFeedProps) {
  const [currentIndex, setCurrentIndex] = useState(initialIndex)
  const [isPlaying, setIsPlaying] = useState(true)
  const [isMuted, setIsMuted] = useState(false)
  const videoRefs = useRef<(HTMLVideoElement | null)[]>([])
  const scrollContainerRef = useRef<HTMLDivElement>(null)

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

  // Manejar reproducción/pausa del video actual
  useEffect(() => {
    const currentVideo = videoRefs.current[currentIndex]
    if (!currentVideo) return

    // Reproducir automáticamente cuando cambia el video
    setIsPlaying(true)
    currentVideo.currentTime = 0
    currentVideo.muted = isMuted
    currentVideo.play().catch((error) => {
      console.log('Error al reproducir:', error)
      // Si falla con sonido, intentar con muted
      currentVideo.muted = true
      setIsMuted(true)
      currentVideo.play().catch(() => {
        console.log('Autoplay bloqueado')
      })
    })
  }, [currentIndex, isMuted])

  // Pausar todos los videos excepto el actual
  useEffect(() => {
    videoRefs.current.forEach((video, index) => {
      if (video && index !== currentIndex) {
        video.pause()
        video.currentTime = 0
      }
    })
  }, [currentIndex])

  // Prevenir scroll del body cuando está abierto el video feed
  useEffect(() => {
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = 'unset'
    }
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

  if (videoPosts.length === 0) return null

  return (
    <div className="fixed inset-0 bg-black z-50">
      {/* Botón de cerrar */}
      <button
        onClick={onClose}
        className="absolute top-4 left-4 z-50 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>

      {/* Contenedor de videos con scroll nativo */}
      <div 
        ref={scrollContainerRef}
        className="w-full h-screen overflow-y-scroll scrollbar-hide"
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
                overflow: 'hidden'
              }}
            >
              <video
                ref={(el) => {
                  videoRefs.current[index] = el
                }}
                src={videoUrl}
                className="w-full h-full object-contain"
                style={{ 
                  width: '100%',
                  height: '100%',
                  objectFit: 'contain'
                }}
                loop
                playsInline
                muted={isMuted}
                onClick={handleVideoClick}
                onPlay={() => {
                  if (isActive) setIsPlaying(true)
                }}
                onPause={() => {
                  if (isActive) setIsPlaying(false)
                }}
              />

              {/* Overlay con información del autor y reacciones */}
              <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black/80 to-transparent pointer-events-none">
                <div className="flex flex-col gap-3">
                  {/* Reacciones horizontales arriba */}
                  <div className="flex items-center gap-3 pointer-events-auto">
                    <button
                      onClick={() => onLike(post.id)}
                      className={`flex items-center gap-1.5 px-3 py-2 rounded-full transition-all ${
                        post.isLiked 
                          ? 'bg-red-500/70' 
                          : 'bg-black/50'
                      }`}
                    >
                      <svg
                        className="w-5 h-5 text-white"
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
                      <span className="text-white text-sm font-medium">
                        {post._count?.likes || 0}
                      </span>
                    </button>

                    <button
                      onClick={() => onComment(post.id)}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-full bg-black/50 transition-all"
                    >
                      <svg
                        className="w-5 h-5 text-white"
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
                      <span className="text-white text-sm font-medium">
                        {post._count?.comments || 0}
                      </span>
                    </button>

                    <button
                      onClick={() => onShare(post.id)}
                      className="flex items-center gap-1.5 px-3 py-2 rounded-full bg-black/50 transition-all"
                    >
                      <svg
                        className="w-5 h-5 text-white"
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
                      <span className="text-white text-sm font-medium">Compartir</span>
                    </button>
                  </div>

                  {/* Información del autor abajo */}
                  <div className="flex items-center gap-3">
                    <Avatar src={post.author.image} alt={authorName} size="sm" />
                    <div>
                      <p className="text-white font-semibold text-sm">{authorName}</p>
                    </div>
                  </div>
                </div>
              </div>

              {/* Botón de mute en la esquina superior derecha */}
              {isActive && (
                <button
                  onClick={toggleMute}
                  className="absolute top-16 right-4 w-10 h-10 bg-black/50 rounded-full flex items-center justify-center text-white hover:bg-black/70 transition-all z-10 pointer-events-auto"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d="M19.114 5.636a9 9 0 010 12.728M16.463 8.288a5 5 0 010 7.072M13 3L8 8H3v8h5l5 5V3z"
                    />
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
              )}

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
    </div>
  )
}
