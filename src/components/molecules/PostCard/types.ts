export interface PostCardProps {
  id: string
  content: string
  author: {
    id: string
    name: string | null
    username: string | null
    image: string | null
    isOnline?: boolean
  }
  mediaUrl?: string | null
  mediaType?: string | null
  mediaUrls?: string[] // Para carrusel de múltiples imágenes
  createdAt: Date
  likesCount: number
  commentsCount: number
  sharesCount?: number
  isLiked?: boolean
  privacy?: 'public' | 'friends' | 'private'
  // Props para sistema de intercesión (solo visual por ahora)
  postType?: 'prayer' | 'testimony' | 'post'
  intercessionsCount?: number
  hasInterceded?: boolean
  isAnswered?: boolean
  onLike?: (postId: string) => void
  onComment?: (postId: string) => void
  onShare?: (postId: string) => void
  onMenuClick?: (postId: string) => void
  onVideoClick?: (postId: string) => void
  onImageClick?: (postId: string) => void
  onIntercede?: (postId: string) => void // Callback visual (sin backend por ahora)
  /** Cuando true, el video de la tarjeta debe reproducirse (p. ej. al cerrar el modal) */
  forcePlayVideo?: boolean
}

