import { Post } from '@/types'

export interface PaginationInfo {
  page: number
  limit: number
  total: number
  totalPages: number
}

export interface UsePostsReturn {
  posts: Post[]
  loading: boolean
  error: string | null
  pagination: PaginationInfo | null
  hasMore: boolean
  fetchPosts: (pageNum?: number, append?: boolean) => Promise<void>
  loadMore: () => void
  createPost: (content: string, file?: File) => Promise<Post>
  likePost: (postId: string) => Promise<void>
  refreshPost: (postId: string) => Promise<void>
}






