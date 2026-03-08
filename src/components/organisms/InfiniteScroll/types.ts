import { ReactNode } from 'react'

export interface InfiniteScrollProps {
  children: ReactNode
  onLoadMore: () => void
  hasMore: boolean
  loading: boolean
}











