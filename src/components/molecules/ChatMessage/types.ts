export interface ChatMessageProps {
  id: string
  content: string
  senderId: string
  currentUserId: string
  sender: {
    name: string | null
    username: string | null
    image: string | null
  }
  mediaUrl?: string | null
  mediaType?: string | null
  createdAt: Date
  isRead: boolean
}











