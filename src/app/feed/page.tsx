'use client'

import { usePosts } from '@/hooks/usePosts'
import { PostCard } from '@/components/molecules/PostCard'
import { PostCardSkeleton } from '@/components/molecules/PostCard'
import { InfiniteScroll } from '@/components/organisms/InfiniteScroll'
import { BottomNavigation } from '@/components/templates/BottomNavigation'
import { VideoFeed } from '@/components/organisms/VideoFeed'
import { MediaFeed } from '@/components/organisms/MediaFeed'
import { CommentsModal } from '@/components/organisms/CommentsModal'
import { ShareModal } from '@/components/organisms/ShareModal'
import { StoriesSection } from '@/components/organisms/StoriesSection'
import { EventsTodaySection } from '@/components/organisms/EventsTodaySection'
import { EventsUpcomingSection } from '@/components/organisms/EventsUpcomingSection'
import { useSession } from 'next-auth/react'
import { useCallback, useState, useMemo, useEffect } from 'react'
import Link from 'next/link'
import { Post } from '@/types'

export default function FeedPage() {
  const { data: session } = useSession()
  const { posts, loading, error, hasMore, loadMore, likePost, refreshPost } = usePosts()
  const [selectedVideoIndex, setSelectedVideoIndex] = useState<number | null>(null)
  const [selectedMediaIndex, setSelectedMediaIndex] = useState<number | null>(null)
  const [videoToResumeOnClose, setVideoToResumeOnClose] = useState<string | null>(null)
  const [selectedPostForComments, setSelectedPostForComments] = useState<string | null>(null)
  const [selectedPostForShare, setSelectedPostForShare] = useState<string | null>(null)

  // Actualizar publicaciones a formato vertical automáticamente (solo una vez)
  useEffect(() => {
    const hasUpdated = localStorage.getItem('posts-updated-to-vertical')
    if (!hasUpdated && session?.user && !loading && posts.length >= 4) {
      fetch('/api/posts/update-to-vertical', {
        method: 'POST',
      })
        .then(() => {
          localStorage.setItem('posts-updated-to-vertical', 'true')
          window.location.reload()
        })
        .catch(() => {
          // Silenciar error
        })
    }
  }, [session, loading, posts.length])

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

  const handleSave = useCallback((postId: string) => {
    const saved = JSON.parse(localStorage.getItem('saved-posts') || '[]') as string[]
    const isAlreadySaved = saved.includes(postId)
    const next = isAlreadySaved ? saved.filter(id => id !== postId) : [...saved, postId]
    localStorage.setItem('saved-posts', JSON.stringify(next))
  }, [])

  const handleCommentAdded = useCallback(async () => {
    if (selectedPostForComments) {
      // Refrescar el post para actualizar el contador de comentarios
      await refreshPost(selectedPostForComments)
    }
  }, [selectedPostForComments, refreshPost])

  const handleMenuClick = useCallback((postId: string) => {
    // TODO: Implementar menú de opciones
    console.log('Menu for post:', postId)
  }, [])

  // Filtrar y ordenar posts con videos por popularidad (para el feed de videos tipo TikTok)
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

  // El orden del feed lo define la API (feed personalizado por siguiendo + afinidad + explorar).
  // No reordenamos en cliente para respetar el ranking del backend.
  const handleVideoClick = useCallback((postId: string) => {
    // Abrir el video en modal sobre el feed (estilo Instagram), sin salir del feed
    const index = videoPosts.findIndex(p => p.id === postId)
    if (index !== -1) setSelectedVideoIndex(index)
  }, [videoPosts])

  const handleCloseVideoFeed = useCallback((postId?: string) => {
    setSelectedVideoIndex(null)
    if (postId) setVideoToResumeOnClose(postId)
  }, [])

  // Limpiar videoToResumeOnClose después de que la tarjeta haya reanudado el video
  useEffect(() => {
    if (!videoToResumeOnClose) return
    const t = setTimeout(() => setVideoToResumeOnClose(null), 800)
    return () => clearTimeout(t)
  }, [videoToResumeOnClose])

  // Obtener todos los posts con medios (imágenes y videos) ordenados por popularidad
  const mediaPosts = useMemo(() => {
    return posts
      .filter(post => {
        // Incluir posts que tengan mediaUrl o mediaUrls
        return post.mediaUrl || (post.mediaUrls && post.mediaUrls.length > 0)
      })
      .sort((a, b) => {
        // Ordenar por popularidad (likes + comentarios)
        const scoreA = (a._count?.likes || 0) + (a._count?.comments || 0)
        const scoreB = (b._count?.likes || 0) + (b._count?.comments || 0)
        return scoreB - scoreA
      })
  }, [posts])

  const handleImageClick = useCallback((postId: string) => {
    // Encontrar el índice del post en la lista de medios ordenados
    const index = mediaPosts.findIndex(p => p.id === postId)
    if (index !== -1) {
      setSelectedMediaIndex(index)
    }
  }, [mediaPosts])

  const handleCloseMediaFeed = useCallback(() => {
    setSelectedMediaIndex(null)
  }, [])

  return (
    <div className="min-h-screen bg-gray-200 dark:bg-dark-bg pb-24">
      <div className="max-w-md mx-auto">
        {/* Header */}
        <header className="flex items-center justify-between px-4 py-2 bg-white/95 dark:bg-dark-bg/95 backdrop-blur-md sticky top-0 z-20 border-b border-gray-200 dark:border-dark-border">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-gradient-to-tr from-primary-500 to-purple-600 rounded-xl flex items-center justify-center text-white text-sm shadow-lg shadow-primary-500/30">
              <span>🙏</span>
            </div>
            <span className="font-bold text-lg bg-gradient-to-r from-primary-500 to-pink-500 bg-clip-text text-transparent">
              KAIRO
            </span>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() =>
                alert('Videos en vivo no disponibles hasta la proxima acttualizacio')
              }
              className="w-10 h-10 flex items-center justify-center rounded-full bg-blue-500 text-white hover:bg-blue-600 hover:scale-110 transition-all"
              aria-label="Videos en vivo"
              title="Videos en vivo"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                />
              </svg>
            </button>
            <button className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 dark:bg-dark-hover text-gray-700 dark:text-white hover:bg-gray-200 dark:hover:bg-dark-border hover:scale-110 transition-all">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
                />
              </svg>
            </button>
            <Link
              href="/events"
              className="w-10 h-10 flex items-center justify-center rounded-full bg-gray-100 dark:bg-dark-hover text-gray-700 dark:text-white hover:bg-gray-200 dark:hover:bg-dark-border hover:scale-110 transition-all"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
                />
              </svg>
            </Link>
          </div>
        </header>

        {/* Error Message */}
        {error && (
          <div className="mx-4 mt-4 bg-red-500/20 dark:bg-red-500/20 border border-red-500/50 dark:border-red-500/50 text-red-600 dark:text-red-400 px-4 py-3 rounded-lg">
            {error}
          </div>
        )}

        {/* Stories Section */}
        <StoriesSection />

        {/* Posts (feed principal priorizando videos y testimonios) */}
        <InfiniteScroll onLoadMore={loadMore} hasMore={hasMore} loading={loading}>
          {loading && posts.length === 0 ? (
            <>
              <PostCardSkeleton />
              <PostCardSkeleton />
              <PostCardSkeleton />
            </>
          ) : (
            posts.map((post, index) => (
              <div key={post.id}>
                <PostCard
                  id={post.id}
                  content={post.content}
                  author={post.author}
                  mediaUrl={post.mediaUrl}
                  mediaType={post.mediaType}
                  mediaUrls={post.mediaUrls}
                  createdAt={post.createdAt}
                  likesCount={post._count?.likes || 0}
                  commentsCount={post._count?.comments || 0}
                  isLiked={post.isLiked || false}
                  postType={(post as any).postType}
                  intercessionsCount={(post as any).intercessionsCount}
                  hasInterceded={(post as any).hasInterceded}
                  isAnswered={(post as any).isAnswered}
                  forcePlayVideo={post.id === videoToResumeOnClose}
                  onLike={handleLike}
                  onComment={handleComment}
                  onShare={handleShare}
                  onMenuClick={handleMenuClick}
                  onVideoClick={handleVideoClick}
                  onImageClick={handleImageClick}
                  onIntercede={(postId) => {
                    // Por ahora solo visual, sin backend
                    console.log('Intercediendo por petición:', postId)
                  }}
                />
                {/* Mostrar sección de eventos "Hoy" después de las dos primeras publicaciones */}
                {index === 1 && <EventsTodaySection />}
                {/* Mostrar sección de "Próximos eventos" después de la tercera publicación */}
                {index === 2 && <EventsUpcomingSection />}
              </div>
            ))
          )}
        </InfiniteScroll>
      </div>

      {/* Bottom Navigation */}
      <BottomNavigation />

      {/* Video Feed Modal */}
      {selectedVideoIndex !== null && videoPosts.length > 0 && (
        <VideoFeed
          posts={videoPosts}
          initialIndex={selectedVideoIndex}
          onClose={handleCloseVideoFeed}
          onLike={handleLike}
          onComment={handleComment}
          onShare={handleShare}
          onSave={handleSave}
          variant="feed"
        />
      )}

      {/* Media Feed Modal (imágenes y videos) */}
      {selectedMediaIndex !== null && mediaPosts.length > 0 && (
        <MediaFeed
          posts={mediaPosts}
          initialIndex={selectedMediaIndex}
          onClose={handleCloseMediaFeed}
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
