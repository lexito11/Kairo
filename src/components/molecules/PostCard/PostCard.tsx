import { memo, useMemo, useState, useEffect } from 'react'
import { Avatar } from '@/components/atoms/Avatar'
import Image from 'next/image'
import { PostCardProps } from './types'
import { formatTimeAgo } from './utils'
import { ImageCarousel } from './ImageCarousel'
import { VideoPlayer } from './VideoPlayer'

function PostCardComponent({
  id,
  content,
  author,
  mediaUrl,
  mediaType,
  mediaUrls,
  createdAt,
  likesCount,
  commentsCount,
  sharesCount = 0,
  isLiked = false,
  privacy = 'public',
  postType,
  intercessionsCount = 0,
  hasInterceded = false,
  isAnswered = false,
  onLike,
  onComment,
  onShare,
  onMenuClick,
  onVideoClick,
  onImageClick,
  onIntercede,
  forcePlayVideo = false,
}: PostCardProps) {
  const [isExpanded, setIsExpanded] = useState(false)
  const [localIsLiked, setLocalIsLiked] = useState(isLiked)
  const [localLikesCount, setLocalLikesCount] = useState(likesCount)
  const [isAnimating, setIsAnimating] = useState(false)
  const [isCommented, setIsCommented] = useState(false)
  const [localHasInterceded, setLocalHasInterceded] = useState(hasInterceded)
  const [localIntercessionsCount, setLocalIntercessionsCount] = useState(intercessionsCount)
  const [isInterceding, setIsInterceding] = useState(false)
  
  // Sincronizar estado local con props cuando cambian
  useEffect(() => {
    setLocalIsLiked(isLiked)
    setLocalLikesCount(likesCount)
    setLocalHasInterceded(hasInterceded)
    setLocalIntercessionsCount(intercessionsCount)
  }, [isLiked, likesCount, hasInterceded, intercessionsCount])
  
  const timeAgo = useMemo(() => formatTimeAgo(new Date(createdAt)), [createdAt])
  const authorName = useMemo(
    () => author.name || author.username || 'Usuario',
    [author.name, author.username]
  )

  const handleLikeClick = () => {
    // Optimistic update
    const newLikedState = !localIsLiked
    setLocalIsLiked(newLikedState)
    setLocalLikesCount(prev => newLikedState ? prev + 1 : Math.max(0, prev - 1))
    setIsAnimating(true)
    
    // Llamar al callback
    onLike?.(id)
    
    // Resetear animación después de un tiempo
    setTimeout(() => setIsAnimating(false), 600)
  }

  const handleCommentClick = () => {
    setIsCommented(true)
    onComment?.(id)
    // Resetear estado después de un tiempo si es necesario
    setTimeout(() => setIsCommented(false), 2000)
  }

  const handleShareClick = () => {
    onShare?.(id)
  }

  const handleIntercedeClick = () => {
    if (localHasInterceded) return // Ya intercedió
    
    // Feedback visual optimista
    setIsInterceding(true)
    setLocalHasInterceded(true)
    setLocalIntercessionsCount(prev => prev + 1)
    
    // Llamar al callback (por ahora solo visual)
    onIntercede?.(id)
    
    // Animación
    setTimeout(() => setIsInterceding(false), 1000)
  }

  // Determinar si es una petición activa
  const isPrayer = postType === 'prayer' && !isAnswered
  const isTestimony = postType === 'testimony' || (postType === 'prayer' && isAnswered)

  // Preparar items de media (imágenes y videos) para el carrusel
  const mediaItems = useMemo(() => {
    const items: Array<{ url: string; type: 'image' | 'video' }> = []
    
    // Función para determinar si una URL es un video
    const isVideo = (url: string): boolean => {
      const videoExtensions = ['.mp4', '.webm', '.mov', '.avi', '.mkv']
      const videoKeywords = ['video', 'gtv-videos-bucket', 'mp4', 'webm']
      const lowerUrl = url.toLowerCase()
      return videoExtensions.some(ext => lowerUrl.includes(ext)) || 
             videoKeywords.some(keyword => lowerUrl.includes(keyword))
    }
    
    // Si hay mediaUrls (múltiples medios), procesarlos
    if (mediaUrls && mediaUrls.length > 0) {
      mediaUrls.forEach((url) => {
        items.push({ 
          url, 
          type: isVideo(url) ? 'video' : 'image' 
        })
      })
    } else if (mediaUrl) {
      // Si hay un solo medio, determinar su tipo
      items.push({ 
        url: mediaUrl, 
        type: mediaType === 'video' || isVideo(mediaUrl) ? 'video' : 'image' 
      })
    }
    
    return items
  }, [mediaUrl, mediaType, mediaUrls])
  
  // Determinar si hay media (imágenes o videos)
  const hasMedia = mediaItems.length > 0
  
  // Límite de caracteres: 150 si tiene media, 300 si solo es texto
  const charLimit = hasMedia ? 150 : 300
  
  // Verificar si el contenido excede el límite
  const shouldTruncate = content && content.length > charLimit
  const displayContent = shouldTruncate && !isExpanded 
    ? content.substring(0, charLimit) + '...'
    : content

  return (
    <article className="bg-white dark:bg-dark-card overflow-hidden mb-3 relative">
      {/* Badge de testimonio */}
      {isTestimony && (
        <div className="absolute top-3 left-3 z-20 flex items-center gap-2 bg-gradient-to-r from-green-500/90 to-emerald-500/90 backdrop-blur-md px-3 py-1.5 rounded-full shadow-lg">
          <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
            <path fillRule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
          </svg>
          <span className="text-xs font-semibold text-white">Testimonio</span>
        </div>
      )}
      {/* Media */}
      {mediaItems.length > 0 && (
        <div className="relative">
          {mediaItems.length > 1 ? (
            <ImageCarousel 
              items={mediaItems} 
              alt={`Medios de ${authorName}`}
              likesCount={localLikesCount}
              commentsCount={commentsCount}
              sharesCount={sharesCount}
              isLiked={localIsLiked}
              forcePlayVideo={forcePlayVideo}
              postId={id}
              onVideoClick={() => {
                // Encontrar el primer video en el carrusel
                const firstVideo = mediaItems.find(item => item.type === 'video')
                if (firstVideo) {
                  onVideoClick?.(id)
                }
              }}
              onImageClick={() => {
                // Encontrar el primer medio (imagen o video) en el carrusel
                const firstMedia = mediaItems[0]
                if (firstMedia) {
                  onImageClick?.(id)
                }
              }}
            />
          ) : mediaItems[0].type === 'video' ? (
            <div 
              className="relative w-full aspect-[4/5] bg-black cursor-pointer overflow-hidden rounded-[inherit]"
              onClick={() => onVideoClick?.(id)}
            >
              <VideoPlayer
                src={mediaItems[0].url}
                fit="contain"
                className=""
                forcePlayVideo={forcePlayVideo}
                postId={id}
              />
            </div>
          ) : (
            <div 
              className="relative w-full aspect-[4/5] bg-black cursor-pointer overflow-hidden rounded-[inherit]"
              onClick={() => onImageClick?.(id)}
            >
              <img
                src={mediaItems[0].url}
                alt={`Imagen de ${authorName}`}
                className="absolute inset-0 w-full h-full object-cover"
                loading="lazy"
              />
            </div>
          )}
          
          {/* Reacciones en la parte superior del media */}
          <div className="absolute top-3 right-3 flex items-center gap-2 z-10">
            <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
              <svg
                className={`w-4 h-4 ${localIsLiked ? 'text-white' : 'text-white'}`}
                fill={localIsLiked ? '#ef4444' : 'none'}
                stroke={localIsLiked ? 'none' : 'currentColor'}
                strokeWidth={localIsLiked ? 0 : 1.5}
                viewBox="0 0 24 24"
                style={{ border: 'none', outline: 'none' }}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
                />
              </svg>
              <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{localLikesCount.toLocaleString()}</span>
            </div>
            <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
              <svg
                className={`w-4 h-4 ${isCommented ? 'text-white' : 'text-white'}`}
                fill={isCommented ? '#3b82f6' : 'none'}
                stroke="currentColor"
                strokeWidth={1.5}
                viewBox="0 0 24 24"
                style={{ border: 'none', outline: 'none' }}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z"
                />
              </svg>
              <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{commentsCount.toLocaleString()}</span>
            </div>
            <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
              <svg
                className="w-4 h-4 text-white"
                fill="none"
                stroke="currentColor"
                strokeWidth={1.5}
                viewBox="0 0 24 24"
                style={{ border: 'none', outline: 'none' }}
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
                />
              </svg>
              <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{sharesCount.toLocaleString()}</span>
            </div>
          </div>
        </div>
      )}

      {/* Engagement Metrics */}
      <div className="px-3 pt-3 pb-2 grid grid-cols-3 items-center">
        <button
          onClick={handleLikeClick}
          className={`flex items-center gap-1 transition-all justify-start ${
            localIsLiked 
              ? 'text-red-500 dark:text-red-500' 
              : 'text-gray-900 dark:text-white'
          }`}
        >
          <svg
            className={`w-4 h-4 sm:w-5 sm:h-5 transition-transform ${
              isAnimating ? 'scale-150' : 'scale-100'
            }`}
            fill={localIsLiked ? '#ef4444' : 'none'}
            stroke={localIsLiked ? 'none' : 'currentColor'}
            strokeWidth={localIsLiked ? 0 : 1.5}
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <span className="text-[10px] sm:text-xs font-medium">{localLikesCount.toLocaleString()}</span>
          <span className="text-[10px] sm:text-xs font-medium">Amén</span>
        </button>

        <button
          onClick={handleCommentClick}
          className={`flex items-center gap-1 transition-all justify-center ${
            isCommented 
              ? 'text-blue-500 dark:text-blue-500' 
              : 'text-gray-900 dark:text-white'
          }`}
        >
          <svg
            className="w-4 h-4 sm:w-5 sm:h-5"
            fill={isCommented ? 'currentColor' : 'none'}
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
          <span className="text-[10px] sm:text-xs font-medium">{commentsCount.toLocaleString()}</span>
          <span className="text-[10px] sm:text-xs font-medium">Comentar</span>
        </button>

        <button
          onClick={handleShareClick}
          className="flex items-center gap-1 transition-all justify-end text-gray-900 dark:text-white"
        >
          <svg
            className="w-4 h-4 sm:w-5 sm:h-5"
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
          <span className="text-[10px] sm:text-xs font-medium">{sharesCount.toLocaleString()}</span>
          <span className="text-[10px] sm:text-xs font-medium">Compartir</span>
        </button>
      </div>

      {/* Header */}
      <div className="px-3 py-2 flex items-center justify-between">
        <div className="flex items-center gap-3 flex-1 min-w-0">
          <div className="relative">
            <Avatar src={author.image} alt={authorName} size="md" />
            {author.isOnline && (
              <div className="absolute -bottom-1 -right-1 w-4 h-4 bg-green-500 rounded-full border-2 border-white dark:border-dark-card" />
            )}
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <h3 className="font-semibold text-gray-900 dark:text-white text-sm truncate">
                {authorName}
              </h3>
            </div>
            <p className="text-xs text-gray-600 dark:text-gray-500">
              {timeAgo} · 🌍 {privacy === 'public' ? 'Público' : privacy}
            </p>
          </div>
        </div>
        <button
          onClick={() => onMenuClick?.(id)}
          className="p-1 hover:bg-gray-100 dark:hover:bg-dark-surface rounded-full transition-colors"
          aria-label="Menú de opciones"
        >
          <svg
            className="w-5 h-5 text-gray-900 dark:text-white"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"
            />
          </svg>
        </button>
      </div>

      {/* Content */}
      {content && (
        <div className="px-3 pt-2 pb-2">
          <p className="text-gray-900 dark:text-gray-200 leading-relaxed whitespace-pre-wrap text-sm">
            {displayContent}
          </p>
          {shouldTruncate && (
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="text-primary-500 hover:text-primary-400 text-sm font-medium mt-1 transition-colors"
            >
              {isExpanded ? 'Leer menos' : 'Leer más'}
            </button>
          )}
        </div>
      )}

    </article>
  )
}

export const PostCard = memo(PostCardComponent)
