export interface CreatePostRequest {
  content: string
  file?: File
}

export interface PostResponse {
  id: string
  content: string
  mediaUrl: string | null
  mediaType: string | null
  createdAt: Date
  updatedAt?: Date
  authorId?: string
  author: {
    id: string
    email?: string
    name: string | null
    username: string | null
    image: string | null
  }
  _count: {
    likes: number
    comments: number
  }
  isAnonymous?: boolean
  postType?: 'post' | 'testimony' | 'prayer'
  privacy?: 'public' | 'anonymous'
  mediaUrls?: string[] | null
  isLiked?: boolean
  likesCount?: number
  commentsCount?: number
}

export interface PaginationInfo {
  page: number
  limit: number
  total: number
  totalPages: number
}

export interface PostsResponse {
  posts: PostResponse[]
  pagination: PaginationInfo
}











