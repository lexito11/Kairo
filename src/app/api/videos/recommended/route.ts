import { NextRequest, NextResponse } from 'next/server'

// IMPORTANTE:
// Para que puedas probar la sección "Solo Videos" sin tener aún
// PostgreSQL/DATABASE_URL configurado, usamos los mockPosts del frontend.
// Más adelante puedes cambiar esto a Prisma cuando tu BD esté lista.

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const page = parseInt(searchParams.get('page') || '1')
    const limit = Math.min(parseInt(searchParams.get('limit') || '15'), 50)
    const offset = (page - 1) * limit

    const { mockPosts } = await import('@/hooks/usePosts/mockData')

    const now = Date.now()

    // Filtrar solo posts que tengan al menos un video
    const videos = mockPosts
      .map((post) => {
        // Detectar URLs de media
        const mediaUrls = post.mediaUrls || (post.mediaUrl ? [post.mediaUrl] : [])

        const hasVideo = mediaUrls.some((url) => {
          const lowerUrl = url.toLowerCase()
          return (
            lowerUrl.includes('.mp4') ||
            lowerUrl.includes('.webm') ||
            lowerUrl.includes('video') ||
            lowerUrl.includes('gtv-videos-bucket')
          )
        })

        if (!hasVideo) return null

        const likes = post._count?.likes || 0
        const comments = post._count?.comments || 0

        const createdAt = new Date(post.createdAt).getTime()
        const hoursSinceCreation = Math.max(
          1,
          (now - createdAt) / (1000 * 60 * 60)
        )

        // Como aún no tenemos métricas reales de watch time / shares,
        // usamos un proxy sencillo:
        const retention = 0.8 // asumimos buena retención para los mocks
        const shares = Math.floor(likes * 0.1)
        const saves = Math.floor(likes * 0.05)
        const engagementLc = likes + comments

        const rawPoints =
          retention * 0.5 + shares * 0.3 + engagementLc * 0.2

        const gravityScore =
          rawPoints / Math.pow(hoursSinceCreation + 2.0, 0.8)

        return {
          ...post,
          mediaUrls,
          likesCount: likes,
          commentsCount: comments,
          retention,
          rawPoints,
          gravityScore,
        }
      })
      .filter((p): p is any => p !== null)

    videos.sort((a, b) => b.gravityScore - a.gravityScore)

    const paginated = videos.slice(offset, offset + limit)

    return NextResponse.json({
      page,
      limit,
      total: videos.length,
      totalPages: Math.ceil(videos.length / limit),
      videos: paginated,
    })
  } catch (error) {
    console.error('Error fetching recommended videos (mock):', error)
    return NextResponse.json(
      { error: 'Error al cargar videos recomendados' },
      { status: 500 }
    )
  }
}

