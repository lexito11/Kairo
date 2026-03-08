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
  author: {
    id: string
    name: string | null
    username: string | null
    image: string | null
  }
  _count: {
    likes: number
    comments: number
  }
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











