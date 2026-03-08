import { Avatar } from '@/components/atoms/Avatar'
import { CommentItemProps } from './types'

export function CommentItem({
  content,
  author,
  createdAt,
}: CommentItemProps) {
  return (
    <div className="flex gap-3 py-3 border-b last:border-b-0">
      <Avatar
        src={author.image}
        alt={author.name || author.username || 'Usuario'}
        size="sm"
      />
      <div className="flex-1">
        <div className="flex items-center gap-2 mb-1">
          <span className="font-semibold text-sm text-gray-900">
            {author.name || author.username || 'Usuario'}
          </span>
          <span className="text-xs text-gray-500">
            {new Date(createdAt).toLocaleDateString('es-ES', {
              day: 'numeric',
              month: 'short',
            })}
          </span>
        </div>
        <p className="text-sm text-gray-700">{content}</p>
      </div>
    </div>
  )
}

