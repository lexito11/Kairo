interface SkeletonProps {
  className?: string
  variant?: 'text' | 'circular' | 'rectangular'
}

export function Skeleton({ className = '', variant = 'rectangular' }: SkeletonProps) {
  const baseStyles = 'animate-pulse bg-gray-200 dark:bg-dark-surface'
  
  const variants = {
    text: 'h-4 rounded',
    circular: 'rounded-full',
    rectangular: 'rounded',
  }

  return (
    <div className={`${baseStyles} ${variants[variant]} ${className}`} />
  )
}

