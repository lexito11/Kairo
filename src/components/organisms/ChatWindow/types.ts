export interface ChatWindowProps {
  userId: string
  otherUser: {
    id: string
    name: string | null
    username: string | null
    image: string | null
  }
  messages: Array<{
    id: string
    content: string
    senderId: string
    mediaUrl?: string | null
    mediaType?: string | null
    createdAt: Date
    isRead: boolean
  }>
  onSendMessage: (content: string, file?: File) => Promise<void>
  onMarkAsRead?: (messageId: string) => void
}











