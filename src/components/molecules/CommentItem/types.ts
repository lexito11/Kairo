export interface CommentItemProps {
  id: string
  content: string
  author: {
    id: string
    name: string | null
    username: string | null
    image: string | null
  }
  createdAt: Date
}











