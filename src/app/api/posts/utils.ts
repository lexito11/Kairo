import { prisma } from '@/lib/prisma'
import { PostsResponse } from './types'

/** Tamaño del pool de posts para rankear (estilo Instagram: mezcla siguiendo + afinidad + explorar) */
const FEED_POOL_SIZE = 250

export const postSelect = {
  id: true,
  content: true,
  mediaUrl: true,
  mediaType: true,
  createdAt: true,
  updatedAt: true,
  authorId: true,
  author: {
    select: {
      id: true,
      email: true,
      name: true,
      username: true,
      image: true,
    },
  },
  _count: {
    select: {
      likes: true,
      comments: true,
    },
  },
}

// Función para transformar mediaUrl (puede ser JSON string) a mediaUrls array
function transformMediaUrls(mediaUrl: string | null): string[] | null {
  if (!mediaUrl) return null
  
  try {
    // Intentar parsear como JSON (array de URLs)
    const parsed = JSON.parse(mediaUrl)
    if (Array.isArray(parsed)) {
      return parsed
    }
  } catch {
    // Si no es JSON, retornar como array con un solo elemento
  }
  
  return [mediaUrl]
}

/** Detecta si un post tiene video según mediaType o mediaUrl */
function postHasVideo(post: { mediaType?: string | null; mediaUrl?: string | null }): boolean {
  if (post.mediaType === 'video' && post.mediaUrl) return true
  const url = typeof post.mediaUrl === 'string' ? post.mediaUrl.toLowerCase() : ''
  return (
    url.includes('.mp4') ||
    url.includes('.webm') ||
    url.includes('video') ||
    url.includes('gtv-videos-bucket')
  )
}

/**
 * Feed personalizado: la app muestra de todo (fotos, videos, testimonios, etc.)
 * pero PRIORIZA la lógica de gustos del usuario:
 * 1. Cuentas que sigue
 * 2. Autores con los que interactúa (likes, comentarios, tiempo de reproducción)
 * 3. Exploración: contenido nuevo y popular para descubrir
 * videoOnly = true para la sección "Solo videos" (misma prioridad de gustos).
 */
async function getPersonalizedFeedInternal(
  page: number,
  limit: number,
  currentUserId: string,
  videoOnly: boolean
): Promise<PostsResponse> {
  const selectWithLikes = {
    ...postSelect,
    likes: {
      where: { authorId: currentUserId },
      select: { id: true },
    },
  } as const

  const poolWhere = videoOnly
    ? {
        OR: [
          { mediaType: 'video' },
          { mediaUrl: { contains: 'video', mode: 'insensitive' as const } },
          { mediaUrl: { contains: 'mp4', mode: 'insensitive' as const } },
          { mediaUrl: { contains: 'gtv-videos-bucket', mode: 'insensitive' as const } },
        ],
      }
    : undefined

  const [followingRows, likedPostIds, commentedPostIds, postViewsWithPost, poolPosts] =
    await Promise.all([
      prisma.follow.findMany({
        where: { followerId: currentUserId },
        select: { followingId: true },
      }),
      prisma.like.findMany({
        where: { authorId: currentUserId },
        select: { postId: true },
      }),
      prisma.comment.findMany({
        where: { authorId: currentUserId },
        select: { postId: true },
      }),
      prisma.postView.findMany({
        where: { userId: currentUserId },
        select: { watchedSeconds: true, post: { select: { authorId: true } } },
      }),
      prisma.post.findMany({
        take: FEED_POOL_SIZE,
        orderBy: { createdAt: 'desc' },
        where: poolWhere,
        select: selectWithLikes,
      }),
    ])

  const followingIds = new Set(followingRows.map((r) => r.followingId))
  const authorIdsFromLikes = new Set<string>()
  const authorIdsFromComments = new Set<string>()

  if (likedPostIds.length > 0 || commentedPostIds.length > 0) {
    const [postsLiked, postsCommented] = await Promise.all([
      likedPostIds.length > 0
        ? prisma.post.findMany({
            where: { id: { in: likedPostIds.map((l) => l.postId) } },
            select: { authorId: true },
          })
        : [],
      commentedPostIds.length > 0
        ? prisma.post.findMany({
            where: { id: { in: commentedPostIds.map((c) => c.postId) } },
            select: { authorId: true },
          })
        : [],
    ])
    postsLiked.forEach((p) => authorIdsFromLikes.add(p.authorId))
    postsCommented.forEach((p) => authorIdsFromComments.add(p.authorId))
  }

  const engagedAuthorIds = new Set([...authorIdsFromLikes, ...authorIdsFromComments])
  engagedAuthorIds.delete(currentUserId)

  const authorWatchSeconds = new Map<string, number>()
  for (const v of postViewsWithPost) {
    const aid = v.post.authorId
    authorWatchSeconds.set(aid, (authorWatchSeconds.get(aid) || 0) + v.watchedSeconds)
  }

  const now = Date.now()
  let pool = poolPosts as any[]
  if (videoOnly) pool = pool.filter((p) => postHasVideo(p))

  // Prioridad de gustos (pesos altos) + exploración (pesos menores) para que se vea de todo
  const scored = pool.map((post: any) => {
    const likesCount = post._count?.likes ?? 0
    const commentsCount = post._count?.comments ?? 0
    const createdAt = new Date(post.createdAt).getTime()
    const hoursSinceCreation = (now - createdAt) / (1000 * 60 * 60)

    let score = 0

    // --- GUSTOS DEL USUARIO (prioridad) ---
    if (followingIds.has(post.authorId)) score += 1000
    if (engagedAuthorIds.has(post.authorId)) score += 350
    const watchSec = authorWatchSeconds.get(post.authorId) || 0
    score += Math.min((watchSec / 60) * 12, 400)

    // --- EXPLORACIÓN (recencia + popularidad para variedad) ---
    const recencyDecay = Math.exp(-hoursSinceCreation / 48)
    score += 80 * recencyDecay
    const engagement = likesCount * 1 + commentsCount * 2
    score += Math.min(engagement * 0.5, 120)

    const isVideo = postHasVideo(post)
    if (isVideo && !videoOnly) score *= 1.15

    return { post, score }
  })

  scored.sort((a, b) => b.score - a.score)

  const start = (page - 1) * limit
  const paginated = scored.slice(start, start + limit).map(({ post }) => post)
  const total = scored.length

  const transformedPosts = paginated.map((post: any) => {
    const { likes: _likes, ...rest } = post
    const mediaUrls = transformMediaUrls(post.mediaUrl)
    const isLiked = post.likes && post.likes.length > 0
    return {
      ...rest,
      mediaUrls,
      isLiked,
      likesCount: post._count?.likes || 0,
      commentsCount: post._count?.comments || 0,
    }
  })

  return {
    posts: transformedPosts,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  }
}

/**
 * Feed principal: muestra de todo y prioriza gustos (siguiendo, afinidad, tiempo visto)
 * y luego exploración para variedad.
 */
export async function getPersonalizedFeed(
  page: number,
  limit: number,
  currentUserId: string
): Promise<PostsResponse> {
  return getPersonalizedFeedInternal(page, limit, currentUserId, false)
}

/**
 * Feed "Solo videos": misma prioridad de gustos que el feed principal, solo posts con video.
 */
export async function getPersonalizedVideoFeed(
  page: number,
  limit: number,
  currentUserId: string
): Promise<PostsResponse> {
  return getPersonalizedFeedInternal(page, limit, currentUserId, true)
}

export async function getPostsWithPagination(
  page: number,
  limit: number,
  currentUserId: string | null
): Promise<PostsResponse> {
  const skip = (page - 1) * limit

  const [posts, total] = await Promise.all([
    prisma.post.findMany({
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
      select: currentUserId
        ? {
            ...postSelect,
            likes: {
              where: {
                authorId: currentUserId,
              },
              select: {
                id: true,
              },
            },
          }
        : postSelect,
    }),
    prisma.post.count(),
  ])

  // Transformar posts para incluir mediaUrls y isLiked
  const transformedPosts = posts.map((post: any) => {
    const mediaUrls = transformMediaUrls(post.mediaUrl)
    const isLiked = currentUserId
      ? post.likes && post.likes.length > 0
      : false

    return {
      ...post,
      mediaUrls,
      isLiked,
      likesCount: post._count?.likes || 0,
      commentsCount: post._count?.comments || 0,
    }
  })

  return {
    posts: transformedPosts,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  }
}

/** Obtener posts por lista de IDs (para sección Guardados del perfil) */
export async function getPostsByIds(
  ids: string[],
  currentUserId: string | null
): Promise<PostsResponse['posts']> {
  if (ids.length === 0) return []
  const uniq = [...new Set(ids)]
  const selectWithLikes = currentUserId
    ? { ...postSelect, likes: { where: { authorId: currentUserId }, select: { id: true } } }
    : postSelect
  const posts = await prisma.post.findMany({
    where: { id: { in: uniq } },
    select: selectWithLikes,
  })
  const orderMap = new Map(uniq.map((id, i) => [id, i]))
  posts.sort((a, b) => (orderMap.get(a.id) ?? 0) - (orderMap.get(b.id) ?? 0))
  return posts.map((post: any) => {
    const { likes: _likes, ...rest } = post
    const mediaUrls = transformMediaUrls(post.mediaUrl)
    const isLiked = currentUserId && post.likes && post.likes.length > 0
    return {
      ...rest,
      mediaUrls,
      isLiked,
      likesCount: post._count?.likes || 0,
      commentsCount: post._count?.comments || 0,
    }
  })
}
