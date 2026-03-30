'use client'

import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { VideoFeed } from '@/components/organisms/VideoFeed'
import { CommentsModal } from '@/components/organisms/CommentsModal'
import { ShareModal } from '@/components/organisms/ShareModal'
import { useCallback, useState, useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { Post } from '@/types'

type VideoPost = Post & {
  likesCount?: number
  commentsCount?: number
}

interface RecommendedVideosResponse {
  page: number
  limit: number
  total: number
  totalPages: number
  videos: VideoPost[]
}

export default function VideosPage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const [videos, setVideos] = useState<VideoPost[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [selectedVideoIndex, setSelectedVideoIndex] = useState<number | null>(null)
  const [selectedPostForComments, setSelectedPostForComments] = useState<string | null>(null)
  const [selectedPostForShare, setSelectedPostForShare] = useState<string | null>(null)

  const handleLike = useCallback((postId: string) => {
    // Actualización optimista en el estado local
    setVideos((prev) =>
      prev.map((post) => {
        if (post.id !== postId) return post
        const currentLikes =
          (post.likesCount ?? post._count?.likes ?? 0)
        const currentlyLiked = post.isLiked ?? false
        const newLikes = currentLikes + (currentlyLiked ? -1 : 1)

        return {
          ...post,
          isLiked: !currentlyLiked,
          likesCount: Math.max(0, newLikes),
          _count: {
            ...(post._count || { comments: 0, likes: 0 }),
            likes: Math.max(0, newLikes),
          },
        }
      })
    )

    // Llamada real al backend (si falla, solo logueamos por ahora)
    fetch(`/api/posts/${postId}/like`, {
      method: 'POST',
    }).catch((err) => {
      console.error('Error al dar like desde videos:', err)
    })
  }, [])

  const handleComment = useCallback((postId: string) => {
    setSelectedPostForComments(postId)
  }, [])

  const handleShare = useCallback((postId: string) => {
    setSelectedPostForShare(postId)
  }, [])

  const handleSave = useCallback((postId: string) => {
    const saved = JSON.parse(localStorage.getItem('saved-posts') || '[]') as string[]
    const isAlreadySaved = saved.includes(postId)
    const next = isAlreadySaved ? saved.filter(id => id !== postId) : [...saved, postId]
    localStorage.setItem('saved-posts', JSON.stringify(next))
  }, [])

  const handleCommentAdded = useCallback(async () => {
    // Aquí podrías volver a pedir el ranking o actualizar un solo post si lo necesitas
  }, [])

  // Cargar videos recomendados desde el backend
  useEffect(() => {
    let cancelled = false

    const load = async () => {
      try {
        setLoading(true)
        setError(null)

        const res = await fetch('/api/videos/recommended?limit=20&page=1')
        if (!res.ok) {
          throw new Error('Error al cargar videos recomendados')
        }
        const data: RecommendedVideosResponse = await res.json()
        if (!cancelled) {
          setVideos(data.videos || [])
        }
      } catch (err) {
        if (!cancelled) {
          setError(
            err instanceof Error ? err.message : 'Error al cargar videos recomendados'
          )
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    load()

    return () => {
      cancelled = true
    }
  }, [])

  // Abrir automáticamente el VideoFeed cuando se carga la página
  useEffect(() => {
    if (!loading && videos.length > 0) {
      // Si hay un postId en la URL, buscar ese video específico
      const postIdFromUrl = searchParams.get('postId')
      if (postIdFromUrl) {
        const index = videos.findIndex(p => p.id === postIdFromUrl)
        if (index !== -1) {
          setSelectedVideoIndex(index)
          return
        }
      }
      // Si no hay postId o no se encontró, abrir el primer video (más popular)
      setSelectedVideoIndex(0)
    }
  }, [loading, videos.length, videos, searchParams])

  const handleCloseVideoFeed = useCallback(() => {
    setSelectedVideoIndex(null)
    router.push('/feed')
  }, [router])

  return (
    <div className="h-screen bg-gray-200 dark:bg-dark-bg flex flex-col overflow-hidden">
      {/* Mostrar mensaje de carga o error solo si no hay VideoFeed abierto y no hay videos */}
      {selectedVideoIndex === null && (loading || videos.length === 0) && (
        <div className="max-w-md mx-auto w-full flex flex-col h-full">
          {/* Header */}
          <header className="flex items-center justify-between px-4 py-2 bg-white/95 dark:bg-dark-bg/95 backdrop-blur-md border-b border-gray-200 dark:border-dark-border flex-shrink-0">
            <div className="flex items-center gap-2">
              <div className="w-9 h-9 bg-gradient-to-tr from-primary-500 to-purple-600 rounded-xl flex items-center justify-center text-white text-sm shadow-lg shadow-primary-500/30">
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              </div>
              <span className="font-bold text-lg bg-gradient-to-r from-primary-500 to-pink-500 bg-clip-text text-transparent">
                Videos
              </span>
            </div>
          </header>

          {/* Error Message */}
          {error && (
            <div className="mx-4 mt-4 bg-red-500/20 dark:bg-red-500/20 border border-red-500/50 dark:border-red-500/50 text-red-600 dark:text-red-400 px-4 py-3 rounded-lg flex-shrink-0">
              {error}
            </div>
          )}

          {/* Mensaje de carga o sin videos */}
          <div className="flex-1 flex items-center justify-center">
            {loading ? (
              <div className="p-4 text-center text-gray-500 dark:text-gray-400">
                Cargando videos...
              </div>
            ) : (
              <div className="p-4 text-center text-gray-500 dark:text-gray-400">
                No hay videos disponibles
              </div>
            )}
          </div>
        </div>
      )}

      {/* Bottom Navigation - siempre visible en esta sección */}
      <BottomNavigation />

      {/* Video Feed Modal */}
      {selectedVideoIndex !== null && videos.length > 0 && (
        <VideoFeed
          posts={videos}
          initialIndex={selectedVideoIndex}
          onClose={handleCloseVideoFeed}
          onLike={handleLike}
          onComment={handleComment}
          onShare={handleShare}
          onSave={handleSave}
          variant="videos"
        />
      )}

      {/* Comments Modal */}
      {selectedPostForComments && (
        <CommentsModal
          postId={selectedPostForComments}
          isOpen={!!selectedPostForComments}
          onClose={() => setSelectedPostForComments(null)}
          onCommentAdded={handleCommentAdded}
        />
      )}

      {/* Share Modal */}
      {selectedPostForShare && (
        <ShareModal
          postId={selectedPostForShare}
          isOpen={!!selectedPostForShare}
          onClose={() => setSelectedPostForShare(null)}
        />
      )}
    </div>
  )
}
