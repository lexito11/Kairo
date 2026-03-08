import { Avatar } from '@/components/atoms/Avatar'
import Image from 'next/image'
import { ChatMessageProps } from './types'

export function ChatMessage({
  content,
  senderId,
  currentUserId,
  sender,
  mediaUrl,
  mediaType,
  createdAt,
  isRead,
}: ChatMessageProps) {
  const isOwn = senderId === currentUserId

  return (
    <div className={`flex gap-2 mb-4 ${isOwn ? 'flex-row-reverse' : ''}`}>
      {!isOwn && (
        <Avatar
          src={sender.image}
          alt={sender.name || sender.username || 'Usuario'}
          size="sm"
        />
      )}
      <div className={`flex flex-col ${isOwn ? 'items-end' : 'items-start'} max-w-[70%]`}>
        <div
          className={`rounded-lg px-4 py-2 ${
            isOwn
              ? 'bg-primary-600 text-white'
              : 'bg-gray-200 text-gray-900'
          }`}
        >
          {mediaUrl && (
            <div className="mb-2 rounded overflow-hidden">
              {mediaType === 'video' ? (
                <video
                  src={mediaUrl}
                  controls
                  className="max-w-full max-h-64 object-contain"
                />
              ) : (
                <Image
                  src={mediaUrl}
                  alt="Message media"
                  width={400}
                  height={300}
                  className="max-w-full h-auto object-contain"
                />
              )}
            </div>
          )}
          <p className="whitespace-pre-wrap">{content}</p>
        </div>
        <div className="flex items-center gap-1 mt-1">
          <span className="text-xs text-gray-500">
            {new Date(createdAt).toLocaleTimeString('es-ES', {
              hour: '2-digit',
              minute: '2-digit',
            })}
          </span>
          {isOwn && (
            <span className="text-xs">
              {isRead ? '✓✓' : '✓'}
            </span>
          )}
        </div>
      </div>
    </div>
  )
}

