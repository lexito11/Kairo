import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { getPersonalizedVideoFeed } from '@/app/api/posts/utils'

/**
 * Videos recomendados con la misma lógica que el feed:
 * siguiendo + afinidad (likes, comentarios, tiempo de reproducción) + explorar.
 * Si no hay sesión, se usa mock para compatibilidad.
 */
export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const page = parseInt(searchParams.get('page') || '1')
    const limit = Math.min(parseInt(searchParams.get('limit') || '20'), 50)

    let currentUserId: string | null = null
    try {
      const session = await getServerSession(authOptions)
      currentUserId = session?.user?.id || null
    } catch {
      currentUserId = null
    }

    if (currentUserId) {
      const result = await getPersonalizedVideoFeed(page, limit, currentUserId)
      return NextResponse.json({
        page: result.pagination.page,
        limit: result.pagination.limit,
        total: result.pagination.total,
        totalPages: result.pagination.totalPages,
        videos: result.posts,
      })
    }

    const { mockPosts } = await import('@/hooks/usePosts/mockData')
    const now = Date.now()
    const offset = (page - 1) * limit

    const videos = mockPosts
      .filter((post) => {
        const mediaUrls = post.mediaUrls || (post.mediaUrl ? [post.mediaUrl] : [])
        return mediaUrls.some((url: string) => {
          const lower = url.toLowerCase()
          return lower.includes('.mp4') || lower.includes('.webm') || lower.includes('video') || lower.includes('gtv-videos-bucket')
        })
      })
      .map((post) => {
        const likes = post._count?.likes || 0
        const comments = post._count?.comments || 0
        const createdAt = new Date(post.createdAt).getTime()
        const hours = Math.max(1, (now - createdAt) / (1000 * 60 * 60))
        const score = (likes + comments * 2) / Math.pow(hours + 2, 0.8)
        return { ...post, _score: score }
      })
      .sort((a: any, b: any) => b._score - a._score)
      .slice(offset, offset + limit)
      .map(({ _score, ...p }: any) => p)

    return NextResponse.json({
      page,
      limit,
      total: mockPosts.length,
      totalPages: Math.ceil(mockPosts.length / limit),
      videos,
    })
  } catch (error) {
    console.error('Error fetching recommended videos:', error)
    return NextResponse.json(
      { error: 'Error al cargar videos recomendados' },
      { status: 500 }
    )
  }
}

