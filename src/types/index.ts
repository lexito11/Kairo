export interface User {
  id: string
  email: string
  name: string | null
  username: string | null
  image: string | null
  bio: string | null
  createdAt: Date
  updatedAt: Date
  isOnline?: boolean
}

export interface Post {
  id: string
  content: string
  mediaUrl: string | null
  mediaType: string | null
  mediaUrls?: string[] // Para múltiples imágenes/videos
  createdAt: Date
  updatedAt?: Date
  authorId: string
  author: User
  _count?: {
    likes: number
    comments: number
  }
  likesCount?: number
  commentsCount?: number
  isLiked?: boolean
  // Campos para sistema de intercesión (solo visual por ahora)
  postType?: 'prayer' | 'testimony' | 'post'
  intercessionsCount?: number
  hasInterceded?: boolean
  isAnswered?: boolean
}

export interface Comment {
  id: string
  content: string
  createdAt: Date
  updatedAt: Date
  authorId: string
  postId: string
  author: User
}

export interface Message {
  id: string
  content: string
  mediaUrl: string | null
  mediaType: string | null
  createdAt: Date
  readAt: Date | null
  senderId: string
  receiverId: string
  sender: User
  receiver: User
}

export interface Follow {
  id: string
  createdAt: Date
  followerId: string
  followingId: string
  follower: User
  following: User
}

