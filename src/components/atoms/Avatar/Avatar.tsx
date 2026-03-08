import { memo } from 'react'
import Image from 'next/image'

interface AvatarProps {
  src?: string | null
  alt: string
  size?: 'sm' | 'md' | 'lg' | 'xl'
  className?: string
}

function AvatarComponent({ src, alt, size = 'md', className = '' }: AvatarProps) {
  const sizes = {
    sm: 'w-8 h-8',
    md: 'w-10 h-10',
    lg: 'w-16 h-16',
    xl: 'w-24 h-24',
  }

  const defaultAvatar = '/default-avatar.png'

  return (
    <div className={`${sizes[size]} rounded-full overflow-hidden bg-gray-200 flex items-center justify-center ${className}`}>
      {src ? (
        <Image
          src={src}
          alt={alt}
          width={parseInt(sizes[size].split('-')[1]) * 4}
          height={parseInt(sizes[size].split('-')[1]) * 4}
          className="w-full h-full object-cover"
        />
      ) : (
        <div className="w-full h-full bg-primary-500 flex items-center justify-center text-white font-semibold">
          {alt.charAt(0).toUpperCase()}
        </div>
      )}
    </div>
  )
}

export const Avatar = memo(AvatarComponent)

