export interface LikePostResponse {
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











