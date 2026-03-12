'use client'

import { useRef, useEffect, useState } from 'react'
import { VideoPlayer } from './VideoPlayer'

interface MediaItem {
  url: string
  type: 'image' | 'video'
}

interface ImageCarouselProps {
  items: MediaItem[]
  alt?: string
  likesCount?: number
  commentsCount?: number
  sharesCount?: number
  isLiked?: boolean
  onVideoClick?: () => void
  onImageClick?: () => void
}

export function ImageCarousel({ items, alt = 'Post media', likesCount = 0, commentsCount = 0, sharesCount = 0, isLiked = false, onVideoClick, onImageClick }: ImageCarouselProps) {
  const scrollContainerRef = useRef<HTMLDivElement>(null)
  const [currentIndex, setCurrentIndex] = useState(0)

  useEffect(() => {
    const container = scrollContainerRef.current
    if (!container) return

    const handleScroll = () => {
      const scrollLeft = container.scrollLeft
      const itemWidth = container.clientWidth
      const index = Math.round(scrollLeft / itemWidth)
      setCurrentIndex(index)
    }

    container.addEventListener('scroll', handleScroll)
    return () => container.removeEventListener('scroll', handleScroll)
  }, [])

  const scrollToIndex = (index: number) => {
    const container = scrollContainerRef.current
    if (!container) return
    
    const itemWidth = container.clientWidth
    container.scrollTo({
      left: index * itemWidth,
      behavior: 'smooth',
    })
  }

  if (items.length === 0) return null

  return (
    <div className="relative w-full aspect-[4/5] overflow-hidden rounded-[inherit] bg-dark-surface group">
      {/* Scroll Container */}
      <div
        ref={scrollContainerRef}
        className="w-full h-full overflow-x-scroll overflow-y-visible snap-x snap-mandatory scrollbar-hide"
        style={{
          WebkitOverflowScrolling: 'touch',
        }}
      >
        <div className="flex h-full">
          {items.map((item, index) => (
            <div
              key={index}
              className="relative w-full h-full flex-shrink-0 snap-start bg-black"
            >
              {item.type === 'video' ? (
                <div 
                  className="w-full h-full cursor-pointer bg-black"
                  onClick={onVideoClick}
                >
                  <VideoPlayer
                    src={item.url}
                    fit="contain"
                    className=""
                  />
                </div>
              ) : (
                <div 
                  className="relative w-full h-full cursor-pointer bg-black"
                  onClick={onImageClick}
                >
                  <img
                    src={item.url}
                    alt={`${alt} ${index + 1}`}
                    className="absolute inset-0 w-full h-full object-cover"
                    loading={index === 0 ? 'eager' : 'lazy'}
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Media Counter */}
      {items.length > 1 && (
        <div className="absolute top-3 left-3 bg-black/50 backdrop-blur-sm text-white text-xs px-2 py-1 rounded-full z-10">
          {currentIndex + 1}/{items.length}
        </div>
      )}

      {/* Reacciones en la parte superior */}
      <div className="absolute top-3 right-3 flex items-center gap-2 z-10">
        <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
          <svg
            className="w-4 h-4 text-white"
            fill={isLiked ? '#ef4444' : 'none'}
            stroke={isLiked ? 'none' : 'currentColor'}
            strokeWidth={isLiked ? 0 : 1.5}
            viewBox="0 0 24 24"
            style={{ border: 'none', outline: 'none' }}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z"
            />
          </svg>
          <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{likesCount.toLocaleString()}</span>
        </div>
        <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
          <svg
            className="w-4 h-4 text-white"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            viewBox="0 0 24 24"
            style={{ border: 'none', outline: 'none' }}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M12 20.25c4.97 0 9-3.694 9-8.25s-4.03-8.25-9-8.25S3 7.444 3 12c0 2.104.859 4.023 2.273 5.488.348.332.697.638 1.05.94l-1.35 3.75 3.75-1.35c.302.353.608.702.94 1.05C7.977 19.141 9.896 20 12 20.25z"
            />
          </svg>
          <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{commentsCount.toLocaleString()}</span>
        </div>
        <div className="flex items-center gap-1 bg-black/50 rounded-full px-2 py-1" style={{ border: 'none', outline: 'none' }}>
          <svg
            className="w-4 h-4 text-white"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.5}
            viewBox="0 0 24 24"
            style={{ border: 'none', outline: 'none' }}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
            />
          </svg>
          <span className="text-xs font-medium text-white" style={{ border: 'none', outline: 'none' }}>{sharesCount.toLocaleString()}</span>
        </div>
      </div>

      {/* Dots Indicator */}
      {items.length > 1 && (
        <div className="absolute bottom-10 left-1/2 -translate-x-1/2 flex gap-2 z-10 items-center">
          {items.map((_, index) => (
            <button
              key={index}
              onClick={() => scrollToIndex(index)}
              className={`rounded-full transition-all ${
                index === currentIndex
                  ? 'bg-primary-500 w-2.5 h-2.5'
                  : 'bg-white/40 hover:bg-white/60 w-2 h-2'
              }`}
              aria-label={`Ir a ${index + 1}`}
            />
          ))}
        </div>
      )}

    </div>
  )
}

