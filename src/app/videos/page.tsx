'use client'

import { usePosts } from '@/hooks/usePosts'
import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { VideoFeed } from '@/components/organisms/VideoFeed'
import { CommentsModal } from '@/components/organisms/CommentsModal'
import { ShareModal } from '@/components/organisms/ShareModal'
import { useSession } from 'next-auth/react'
import { useCallback, useState, useMemo, useEffect } from 'react'
import { useSearchParams } from 'next/navigation'
import { Post } from '@/types'

export default function VideosPage() {
  const { data: session } = useSession()
  const searchParams = useSearchParams()
  const { posts, loading, error, likePost, refreshPost } = usePosts()
  const [selectedVideoIndex, setSelectedVideoIndex] = useState<number | null>(null)
  const [selectedPostForComments, setSelectedPostForComments] = useState<string | null>(null)
  const [selectedPostForShare, setSelectedPostForShare] = useState<string | null>(null)

  const handleLike = useCallback(
    (postId: string) => {
      likePost(postId)
    },
    [likePost]
  )

  const handleComment = useCallback((postId: string) => {
    setSelectedPostForComments(postId)
  }, [])

  const handleShare = useCallback((postId: string) => {
    setSelectedPostForShare(postId)
  }, [])

  const handleCommentAdded = useCallback(async () => {
    if (selectedPostForComments) {
      await refreshPost(selectedPostForComments)
    }
  }, [selectedPostForComments, refreshPost])

  // Filtrar posts con videos y ordenarlos por popularidad
  const videoPosts = useMemo(() => {
    return posts
      .map((post, index) => {
        // Verificar si el post tiene video
        let hasVideo = false
        if (post.mediaType === 'video' && post.mediaUrl) {
          hasVideo = true
        } else if (post.mediaUrls && post.mediaUrls.length > 0) {
          hasVideo = post.mediaUrls.some(url => {
            const lowerUrl = url.toLowerCase()
            return lowerUrl.includes('.mp4') || 
                   lowerUrl.includes('.webm') || 
                   lowerUrl.includes('video') ||
                   lowerUrl.includes('gtv-videos-bucket')
          })
        }
        return hasVideo ? { post, originalIndex: index } : null
      })
      .filter((item): item is { post: Post; originalIndex: number } => item !== null)
      .sort((a, b) => {
        // Ordenar por popularidad (likes + comentarios)
        const scoreA = (a.post._count?.likes || 0) + (a.post._count?.comments || 0)
        const scoreB = (b.post._count?.likes || 0) + (b.post._count?.comments || 0)
        return scoreB - scoreA
      })
      .map(item => item.post)
  }, [posts])

  // Abrir automáticamente el VideoFeed cuando se carga la página
  useEffect(() => {
    if (!loading && videoPosts.length > 0) {
      // Si hay un postId en la URL, buscar ese video específico
      const postIdFromUrl = searchParams.get('postId')
      if (postIdFromUrl) {
        const index = videoPosts.findIndex(p => p.id === postIdFromUrl)
        if (index !== -1) {
          setSelectedVideoIndex(index)
          return
        }
      }
      // Si no hay postId o no se encontró, abrir el primer video (más popular)
      setSelectedVideoIndex(0)
    }
  }, [loading, videoPosts.length, videoPosts, searchParams])

  const handleCloseVideoFeed = useCallback(() => {
    setSelectedVideoIndex(null)
  }, [])

  return (
    <div className="h-screen bg-gray-200 dark:bg-dark-bg flex flex-col overflow-hidden">
      {/* Mostrar mensaje de carga o error solo si no hay VideoFeed abierto y no hay videos */}
      {selectedVideoIndex === null && (loading || videoPosts.length === 0) && (
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

      {/* Bottom Navigation - Solo mostrar si no hay VideoFeed abierto */}
      {selectedVideoIndex === null && <BottomNavigation />}

      {/* Video Feed Modal */}
      {selectedVideoIndex !== null && videoPosts.length > 0 && (
        <VideoFeed
          posts={videoPosts}
          initialIndex={selectedVideoIndex}
          onClose={handleCloseVideoFeed}
          onLike={handleLike}
          onComment={handleComment}
          onShare={handleShare}
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
