'use client'

import { useEffect, useRef } from 'react'
import { InfiniteScrollProps } from './types'

export function InfiniteScroll({
  children,
  onLoadMore,
  hasMore,
  loading,
}: InfiniteScrollProps) {
  const observerTarget = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && hasMore && !loading) {
          onLoadMore()
        }
      },
      { threshold: 0.1 }
    )

    const currentTarget = observerTarget.current
    if (currentTarget) {
      observer.observe(currentTarget)
    }

    return () => {
      if (currentTarget) {
        observer.unobserve(currentTarget)
      }
    }
  }, [hasMore, loading, onLoadMore])

  return (
    <>
      {children}
      {hasMore && (
        <div ref={observerTarget} className="h-10 flex items-center justify-center">
          {loading && <div className="text-gray-500">Cargando más...</div>}
        </div>
      )}
    </>
  )
}

