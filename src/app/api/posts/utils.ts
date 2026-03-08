import { prisma } from '@/lib/prisma'
import { PostsResponse } from './types'

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
