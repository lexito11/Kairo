import { Skeleton } from '@/components/atoms/Skeleton'

export function PostCardSkeleton() {
  return (
    <article className="bg-dark-card overflow-hidden mb-3">
      {/* Header */}
      <div className="p-3 flex items-center justify-between">
        <div className="flex items-center gap-3 flex-1">
          <Skeleton variant="circular" className="w-10 h-10" />
          <div className="flex-1">
            <Skeleton className="h-4 w-32 mb-2 bg-dark-surface" />
            <Skeleton className="h-3 w-24 bg-dark-surface" />
          </div>
        </div>
        <Skeleton className="w-6 h-6 rounded-full bg-dark-surface" />
      </div>

      {/* Content */}
      <div className="px-3 mb-2 space-y-2">
        <Skeleton className="h-4 w-full bg-dark-surface" />
        <Skeleton className="h-4 w-3/4 bg-dark-surface" />
      </div>

      {/* Media placeholder */}
      <div>
        <Skeleton className="w-full aspect-[5/6] bg-dark-surface" />
      </div>

      {/* Actions */}
      <div className="p-3 flex items-center justify-between border-t border-dark-border">
        <Skeleton className="h-5 w-16 bg-dark-surface" />
        <Skeleton className="h-5 w-16 bg-dark-surface" />
        <Skeleton className="h-5 w-16 bg-dark-surface ml-auto" />
      </div>
    </article>
  )
}

